# Arrays, Maps and plain objects. Everything else in this interpreter is a string, so objects live
# in a global table and are passed around as opaque "handle" strings (`"\u0001obj:12"`).
# There is no garbage collection: an object lives until the script exits.
module Util
	class AhkObject
		enum Kind
			Array
			Map
			Object
		end
		getter kind : Kind
		getter items = [] of ::String                 # Array
		getter map = {} of ::String => ::String       # Map (keys as-is) and Object (keys lowercased)
		def initialize(@kind)
		end
		def size
			@kind.array? ? @items.size : @map.size
		end
		# {key, value} pairs for `for` loops and cloning
		def pairs : Array({::String, ::String})
			if @kind.array?
				@items.map_with_index { |v, i| {(i + 1).to_s, v} }
			else
				@map.to_a
			end
		end
	end

	module ObjectStore
		class ObjError < Exception end

		PREFIX = "\u0001obj:"
		@@objects = {} of Int64 => AhkObject
		@@next_id = 0_i64

		def self.create(kind : AhkObject::Kind) : ::String
			@@next_id += 1
			@@objects[@@next_id] = AhkObject.new(kind)
			"#{PREFIX}#{@@next_id}"
		end

		def self.lookup(handle : ::String) : AhkObject?
			return nil if ! handle.starts_with?(PREFIX)
			@@objects[handle[PREFIX.size..].to_i64?]?
		end

		def self.get!(handle : ::String, what = "value") : AhkObject
			lookup(handle) || raise ObjError.new "The #{what} '#{handle.empty? ? "(empty)" : handle}' is not an object (Array, Map or Object)"
		end

		def self.object?(s : ::String) : Bool
			! lookup(s).nil?
		end

		private def self.int_key(o : AhkObject, key : ::String) : Int32
			i = key.to_i?
			raise ObjError.new "Array index '#{key}' is not a number" if ! i
			i += o.items.size + 1 if i < 0
			raise ObjError.new "Array index #{key} is out of range (valid: 1 to #{o.items.size})" if i < 1 || i > o.items.size
			i
		end

		def self.index_get(handle : ::String, key : ::String) : ::String
			o = get!(handle)
			case o.kind
			when .array? then o.items[int_key(o, key) - 1]
			when .map?
				o.map[key]? || raise ObjError.new "Map has no item with key '#{key}'"
			else o.map[key.downcase]? || ""
			end
		end

		def self.index_set(handle : ::String, key : ::String, value : ::String)
			o = get!(handle)
			case o.kind
			when .array? then o.items[int_key(o, key) - 1] = value
			when .map? then o.map[key] = value
			else o.map[key.downcase] = value
			end
		end

		def self.prop_get(handle : ::String, name : ::String) : ::String
			o = get!(handle)
			n = name.downcase
			if o.kind.array? && n == "length"
				o.items.size.to_s
			elsif o.kind.map? && n == "count"
				o.map.size.to_s
			elsif o.kind.object?
				o.map[n]? || ""
			else
				raise ObjError.new "This #{o.kind.to_s} has no property '#{name}'"
			end
		end

		def self.prop_set(handle : ::String, name : ::String, value : ::String)
			o = get!(handle)
			raise ObjError.new "Cannot set property '#{name}' on a #{o.kind.to_s}" if ! o.kind.object?
			o.map[name.downcase] = value
		end

		def self.clone(o : AhkObject) : ::String
			h = create(o.kind)
			n = lookup(h).not_nil!
			n.items.concat o.items
			o.map.each { |k, v| n.map[k] = v }
			h
		end

		def self.array_of(values : Array(::String)) : ::String
			h = create(AhkObject::Kind::Array)
			lookup(h).not_nil!.items.concat values
			h
		end

		def self.call_method(handle : ::String, name : ::String, args : Array(::String)) : ::String
			o = get!(handle)
			m = name.downcase
			a = ->(i : Int32) { args[i]? || "" }
			case o.kind
			when .array?
				case m
				when "push"
					o.items.concat(args)
					o.items.size.to_s
				when "pop"
					raise ObjError.new "Array.Pop(): the array is empty" if o.items.empty?
					o.items.pop
				when "insertat"
					i = a.call(0).to_i? || raise ObjError.new("InsertAt(): index must be a number")
					raise ObjError.new "InsertAt(): index #{i} is out of range" if i < 1 || i > o.items.size + 1
					(args[1..]? || [] of ::String).each_with_index { |v, j| o.items.insert(i - 1 + j, v) }
					""
				when "removeat"
					i = int_key(o, a.call(0))
					n = (args[1]?.try(&.to_i?) || 1)
					removed = o.items[i - 1]
					n.times { o.items.delete_at(i - 1) if i - 1 < o.items.size }
					removed
				when "has"
					i = a.call(0).to_i?
					(i && i >= 1 && i <= o.items.size) ? "1" : "0"
				when "indexof"
					idx = o.items.index(a.call(0))
					idx ? (idx + 1).to_s : "0"
				when "join" then o.items.join(args.empty? ? "," : a.call(0))
				when "clone" then clone(o)
				when "length" then o.items.size.to_s
				else raise ObjError.new "Array has no method '#{name}'"
				end
			when .map?
				case m
				when "set"
					raise ObjError.new "Map.Set(): parameters must come in key/value pairs" if args.size.odd?
					args.each_slice(2) { |p| o.map[p[0]] = p[1] }
					""
				when "get"
					o.map[a.call(0)]? || (args.size > 1 ? a.call(1) : raise(ObjError.new "Map has no item with key '#{a.call(0)}'"))
				when "has" then o.map.has_key?(a.call(0)) ? "1" : "0"
				when "delete" then o.map.delete(a.call(0)) || raise(ObjError.new "Map has no item with key '#{a.call(0)}'")
				when "clear"
					o.map.clear
					""
				when "clone" then clone(o)
				when "keys" then array_of(o.map.keys)
				when "values" then array_of(o.map.values)
				when "count" then o.map.size.to_s
				else raise ObjError.new "Map has no method '#{name}'"
				end
			else
				case m
				when "hasownprop" then o.map.has_key?(a.call(0).downcase) ? "1" : "0"
				when "clone" then clone(o)
				when "deleteprop" then o.map.delete(a.call(0).downcase) || ""
				else raise ObjError.new "Object has no method '#{name}'"
				end
			end
		end
	end
end
