require "../../util/expression"

# ObjAssign, Target, Operator, Expression
# Used for `a[1] := x`, `obj.name += 2`, `a.b[c] .= "x"` etc.
class Cmd::Math::ObjAssign < Cmd::Base
	def self.min_args; 3 end
	def self.max_args; 3 end
	def run(thread, args)
		Util::Expression.assign(args[0], args[1], args[2], thread)
	end
end
