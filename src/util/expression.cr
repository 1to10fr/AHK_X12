# Evaluator for AutoHotkey v1.1/v2-style expressions, such as `StrLen(x) > 3 && !done`.
# All values are strings, like everywhere else in this interpreter; numbers are
# detected when an operator needs them.
class Util::Expression
	class ExprError < Exception end

	alias Num = Int64 | Float64

	NUMBER_RE = /\A\s*[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?\s*\z/
	@@regex_cache = {} of String => Regex

	def self.eval(src : String, thread : Run::Thread) : String
		ex = new(src, thread)
		result = ex.parse_ternary
		ex.skip_ws
		raise ExprError.new "Unexpected '#{src[ex.pos..]}' in expression '#{src}'" if ! ex.at_end?
		result
	end

	def self.truthy?(v : String) : Bool
		return false if v.empty?
		n = num(v)
		return n != 0 if n
		true
	end

	def self.num(s : String) : Num?
		t = s.strip
		return nil if t.empty?
		if (i = t.to_i64?(prefix: true))
			i
		elsif t =~ NUMBER_RE
			t.to_f?
		end
	end

	def self.fmt(n : Num) : String
		if n.is_a?(Float64) && n.finite? && n == n.floor && n.abs < 1e15
			n.to_i64.to_s
		else
			n.to_s
		end
	end

	def self.bool(b : Bool) : String
		b ? "1" : "0"
	end

	# Converts an AHK regex (optional `imsxU)` option prefix, `$1` is not handled here)
	# to a Crystal one.
	def self.regex(src : String) : Regex
		@@regex_cache[src] ||= begin
			pattern = src
			flags = ""
			if (m = src.match(/\A([a-zA-Z`\s]*)\)/))
				m[1].each_char do |c|
					flags += c if "imsxU".includes?(c)
				end
				pattern = src[m[0].size..]
			end
			pattern = "(?#{flags})#{pattern}" if ! flags.empty?
			Regex.new(pattern)
		end
	end

	getter pos = 0

	def initialize(@src : String, @thread : Run::Thread)
	end

	def at_end?
		@pos >= @src.size
	end

	def skip_ws
		while @pos < @src.size && @src[@pos].whitespace?
			@pos += 1
		end
	end

	private def peek(str : String) : Bool
		@src[@pos..].starts_with?(str)
	end

	private def match_op(*ops : String) : String?
		ops.find { |o| peek(o) }
	end

	private def peek_word(word : String) : Bool
		return false if ! @src[@pos..].downcase.starts_with?(word)
		nxt = @src[@pos + word.size]?
		nxt.nil? || ! (nxt.alphanumeric? || nxt == '_')
	end

	def parse_ternary : String
		cond = parse_or
		skip_ws
		if @src[@pos]? == '?'
			@pos += 1
			a = parse_ternary
			skip_ws
			raise ExprError.new "Expected ':' in ternary expression '#{@src}'" if @src[@pos]? != ':'
			@pos += 1
			b = parse_ternary
			return Expression.truthy?(cond) ? a : b
		end
		cond
	end

	private def parse_or : String
		left = parse_and
		loop do
			skip_ws
			if peek("||")
				@pos += 2
			elsif peek_word("or")
				@pos += 2
			else
				break
			end
			right = parse_and
			left = Expression.bool(Expression.truthy?(left) || Expression.truthy?(right))
		end
		left
	end

	private def parse_and : String
		left = parse_not
		loop do
			skip_ws
			if peek("&&")
				@pos += 2
			elsif peek_word("and")
				@pos += 3
			else
				break
			end
			right = parse_not
			left = Expression.bool(Expression.truthy?(left) && Expression.truthy?(right))
		end
		left
	end

	private def parse_not : String
		skip_ws
		if peek_word("not")
			@pos += 3
			return Expression.bool(! Expression.truthy?(parse_not))
		end
		parse_equality
	end

	private def parse_equality : String
		left = parse_relational
		loop do
			skip_ws
			op = match_op("==", "!=", "<>", "=")
			break if ! op
			@pos += op.size
			right = parse_relational
			a, b = Expression.num(left), Expression.num(right)
			same = if a && b
				a == b
			elsif op == "=="
				left == right
			else
				left.downcase == right.downcase
			end
			left = Expression.bool(op == "=" || op == "==" ? same : ! same)
		end
		left
	end

	private def parse_relational : String
		left = parse_concat
		loop do
			skip_ws
			op = peek("<>") ? nil : match_op("<=", ">=", "<", ">")
			break if ! op
			@pos += op.size
			right = parse_concat
			a, b = Expression.num(left), Expression.num(right)
			cmp = a && b ? (a <=> b) : (left.downcase <=> right.downcase)
			cmp ||= 0
			left = Expression.bool(case op
				when "<" then cmp < 0
				when ">" then cmp > 0
				when "<=" then cmp <= 0
				else cmp >= 0
				end)
		end
		left
	end

	private def parse_concat : String
		left = parse_add
		loop do
			skip_ws
			# `.` is a concat operator only when surrounded by whitespace (so it doesn't clash with decimals)
			break if @src[@pos]? != '.' || @src[@pos + 1]? == '=' || ! (@src[@pos - 1]?.try(&.whitespace?) || @src[@pos + 1]?.try(&.whitespace?))
			@pos += 1
			left += parse_add
		end
		left
	end

	private def parse_add : String
		left = parse_mul
		loop do
			skip_ws
			c = @src[@pos]?
			break if c != '+' && c != '-'
			@pos += 1
			left = arith(c.to_s, left, parse_mul)
		end
		left
	end

	private def parse_mul : String
		left = parse_unary
		loop do
			skip_ws
			op = peek("**") ? nil : match_op("//", "*", "/")
			break if ! op
			@pos += op.size
			left = arith(op, left, parse_unary)
		end
		left
	end

	private def parse_unary : String
		skip_ws
		c = @src[@pos]?
		if c == '!'
			@pos += 1
			return Expression.bool(! Expression.truthy?(parse_unary))
		elsif c == '-'
			@pos += 1
			return arith("-", "0", parse_unary)
		elsif c == '+'
			@pos += 1
			return parse_unary
		end
		parse_power
	end

	private def parse_power : String
		base = parse_primary
		skip_ws
		if peek("**")
			@pos += 2
			return arith("**", base, parse_unary)
		end
		base
	end

	private def arith(op : String, a : String, b : String) : String
		x, y = Expression.num(a), Expression.num(b)
		raise ExprError.new "Non-numeric value '#{x ? b : a}' used with operator '#{op}'" if ! x || ! y
		if x.is_a?(Int64) && y.is_a?(Int64)
			case op
			when "+" then return Expression.fmt(x + y)
			when "-" then return Expression.fmt(x - y)
			when "*" then return Expression.fmt(x * y)
			when "//"
				raise ExprError.new "Division by zero" if y == 0
				return Expression.fmt(x.tdiv(y))
			when "/"
				raise ExprError.new "Division by zero" if y == 0
				return Expression.fmt(x % y == 0 ? x // y : x.to_f / y)
			when "**" then return Expression.fmt(y >= 0 ? (x.to_f ** y).to_i64 : x.to_f ** y)
			end
		end
		xf, yf = x.to_f, y.to_f
		case op
		when "+" then Expression.fmt(xf + yf)
		when "-" then Expression.fmt(xf - yf)
		when "*" then Expression.fmt(xf * yf)
		when "//"
			raise ExprError.new "Division by zero" if yf == 0
			Expression.fmt((xf / yf).trunc)
		when "/"
			raise ExprError.new "Division by zero" if yf == 0
			Expression.fmt(xf / yf)
		when "**" then Expression.fmt(xf ** yf)
		else raise ExprError.new "Unknown operator '#{op}'"
		end
	end

	private def parse_primary : String
		skip_ws
		c = @src[@pos]?
		raise ExprError.new "Unexpected end of expression '#{@src}'" if ! c
		if c == '('
			@pos += 1
			v = parse_ternary
			skip_ws
			raise ExprError.new "Missing ')' in expression '#{@src}'" if @src[@pos]? != ')'
			@pos += 1
			return v
		elsif c == '"'
			return parse_string
		elsif c.ascii_number? || (c == '.' && @src[@pos + 1]?.try &.ascii_number?)
			start = @pos
			if c == '0' && (@src[@pos + 1]? == 'x' || @src[@pos + 1]? == 'X')
				@pos += 2
				while @pos < @src.size && @src[@pos].hex?
					@pos += 1
				end
			else
				while @pos < @src.size && (@src[@pos].ascii_number? || @src[@pos] == '.')
					@pos += 1
				end
				if (@src[@pos]? == 'e' || @src[@pos]? == 'E') && (@src[@pos + 1]?.try { |d| d.ascii_number? || d == '-' || d == '+' })
					@pos += 2
					while @pos < @src.size && @src[@pos].ascii_number?
						@pos += 1
					end
				end
			end
			lit = @src[start...@pos]
			n = Expression.num(lit)
			raise ExprError.new "Invalid number '#{lit}'" if ! n
			return Expression.fmt(n)
		elsif c.letter? || c == '_'
			start = @pos
			while @pos < @src.size && (@src[@pos].alphanumeric? || @src[@pos] == '_')
				@pos += 1
			end
			name = @src[start...@pos]
			if @src[@pos]? == '('
				@pos += 1
				return call(name)
			end
			case name.downcase
			when "true" then return "1"
			when "false" then return "0"
			end
			return @thread.get_var(name)
		end
		raise ExprError.new "Unexpected '#{c}' in expression '#{@src}'"
	end

	private def parse_string : String
		@pos += 1 # opening quote
		str = String::Builder.new
		loop do
			c = @src[@pos]?
			raise ExprError.new "Missing closing quote in expression '#{@src}'" if ! c
			@pos += 1
			if c == '"'
				if @src[@pos]? == '"' # "" is an escaped quote
					str << '"'
					@pos += 1
				else
					break
				end
			else
				str << c
			end
		end
		str.to_s
	end

	# Parses the arguments of a function call (opening paren already consumed) and runs it.
	private def call(name : String) : String
		args = [] of String
		names = [] of String? # set when an argument is a bare variable name (needed for output vars)
		skip_ws
		if @src[@pos]? == ')'
			@pos += 1
		else
			loop do
				skip_ws
				if @src[@pos]? == ',' || @src[@pos]? == ')'
					args << ""
					names << nil
				else
					start = @pos
					args << parse_ternary
					bare = @src[start...@pos].strip
					names << (bare =~ /\A[A-Za-z_]\w*\z/ ? bare : nil)
				end
				skip_ws
				c = @src[@pos]?
				@pos += 1
				break if c == ')'
				raise ExprError.new "Expected ',' or ')' in call to '#{name}' in '#{@src}'" if c != ','
			end
		end
		Expression.run_function(@thread, name, args, names)
	end

	def self.run_function(thread : Run::Thread, name : String, args : Array(String), names : Array(String?)) : String
		a = ->(i : Int32) { args[i]? || "" }
		have = ->(i : Int32) { ! (args[i]?.nil? || args[i].empty?) }
		int = ->(i : Int32, default : Int64) {
			v = args[i]?
			(v && ! v.empty? ? num(v) : nil).try(&.to_i64) || default
		}
		f = ->(i : Int32) {
			n = num(args[i]? || "")
			raise ExprError.new "#{name}(): parameter #{i + 1} must be a number" if ! n
			n.to_f
		}
		case name.downcase
		when "strlen" then a.call(0).size.to_s
		when "substr"
			s = a.call(0)
			st = int.call(1, 1_i64)
			st += s.size if st <= 0
			st = 1_i64 if st < 1
			return "" if st > s.size
			avail = s.size - st + 1
			l = avail
			if have.call(2)
				l = int.call(2, avail)
				l += avail if l < 0
				l = 0_i64 if l < 0
				l = avail if l > avail
			end
			s[st - 1, l]
		when "instr"
			h, n = a.call(0), a.call(1)
			cs = Expression.truthy?(a.call(2))
			start = int.call(3, 1_i64)
			occ = int.call(4, 1_i64)
			start = 1_i64 if start < 1
			return start.to_s if n.empty?
			hay = cs ? h : h.downcase
			ned = cs ? n : n.downcase
			idx = start - 1
			found = 0_i64
			loop do
				i = hay.index(ned, idx)
				return "0" if ! i
				found += 1
				return (i + 1).to_s if found >= occ
				idx = i + 1
			end
		when "trim" then a.call(0).strip(have.call(1) ? a.call(1) : " \t")
		when "ltrim" then a.call(0).lstrip(have.call(1) ? a.call(1) : " \t")
		when "rtrim" then a.call(0).rstrip(have.call(1) ? a.call(1) : " \t")
		when "strupper" then a.call(0).upcase
		when "strlower" then a.call(0).downcase
		when "strreplace"
			search = a.call(1)
			return a.call(0) if search.empty?
			rx = Regex.new(Regex.escape(search), Regex::Options::IGNORE_CASE)
			limit = int.call(4, -1_i64)
			count = 0_i64
			res = a.call(0).gsub(rx) do |m|
				if limit < 0 || count < limit
					count += 1
					a.call(2)
				else
					m
				end
			end
			thread.runner.set_user_var(names[3].not_nil!, count.to_s) if names[3]?
			res
		when "regexreplace"
			rx = regex(a.call(1))
			repl = a.call(2)
			limit = int.call(4, -1_i64)
			count = 0_i64
			res = a.call(0).gsub(rx) do |m, md|
				if limit < 0 || count < limit
					count += 1
					# `$1` / `$0` back references
					repl.gsub(/\$(\d+)/) { md[$1.to_i]? || "" }
				else
					m
				end
			end
			thread.runner.set_user_var(names[3].not_nil!, count.to_s) if names[3]?
			res
		when "regexmatch"
			rx = regex(a.call(1))
			start = int.call(3, 1_i64)
			start = 1_i64 if start < 1
			out_name = names[2]?
			md = start - 1 <= a.call(0).size ? rx.match(a.call(0), (start - 1).to_i32) : nil
			if out_name
				thread.runner.set_user_var(out_name, md ? md[0] : "")
				if md
					(1...md.size).each do |i|
						thread.runner.set_user_var("#{out_name}#{i}", md[i]? || "")
					end
				end
			end
			md ? (md.begin(0) + 1).to_s : "0"
		when "abs" then fmt(f.call(0).abs)
		when "floor" then fmt(f.call(0).floor.to_i64)
		when "ceil" then fmt(f.call(0).ceil.to_i64)
		when "int" then fmt(f.call(0).trunc.to_i64)
		when "sqrt" then fmt(Math.sqrt(f.call(0)))
		when "round"
			digits = int.call(1, 0_i64)
			digits == 0 ? fmt(f.call(0).round.to_i64) : fmt(f.call(0).round(digits.to_i32))
		when "mod"
			x, y = f.call(0), f.call(1)
			raise ExprError.new "Mod(): division by zero" if y == 0
			r = x - y * (x / y).trunc
			fmt(r)
		when "min", "max"
			vals = args.map { |v| num(v) || raise ExprError.new("#{name}(): '#{v}' is not a number") }
			raise ExprError.new "#{name}() needs at least one parameter" if vals.empty?
			pick = name.downcase == "min" ? vals.min_by(&.to_f) : vals.max_by(&.to_f)
			fmt(pick)
		when "chr" then int.call(0, 0_i64).to_i32.chr.to_s
		when "asc" then (a.call(0)[0]?.try(&.ord) || 0).to_s
		else
			raise ExprError.new "Function '#{name}' not found. (Calling your own functions inside an expression is not supported yet: call them as a separate statement.)"
		end
	end
end
