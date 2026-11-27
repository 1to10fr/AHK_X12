require "./loop"
require "../../util/expression"
require "../../util/object-store"

# For, Variables, Expression
# `for v in obj` / `for k, v in obj`. Arrays give index and value, Maps and Objects key and value.
# With a single variable, Arrays give the value, Maps and Objects the key.
class Cmd::ControlFlow::For < Cmd::ControlFlow::Loop
	def self.min_args; 2 end
	def self.max_args; 2 end
	# Stacks, so that the same loop can be entered again while it is running (recursion)
	@iterations = [] of {Array({::String, ::String}), Bool}
	@positions = [] of Int32
	def run(thread, args)
		if thread.loop_stack.last? != self
			obj = Util::ObjectStore.get!(Util::Expression.eval(args[1], thread), "value after 'in'")
			@iterations << {obj.pairs, obj.kind.array?}
			@positions << 0
			thread.loop_stack << self
		end
		pairs, is_array = @iterations.last
		pos = @positions.last
		if pos >= pairs.size
			finish(thread)
			return false
		end
		@positions[@positions.size - 1] = pos + 1
		@index = pos + 1
		key, value = pairs[pos]
		names = args[0].split(',')
		if names.size == 2
			thread.runner.set_user_var names[0].strip, key
			thread.runner.set_user_var names[1].strip, value
		else
			thread.runner.set_user_var names[0].strip, is_array ? value : key
		end
		true
	end
	def finish(thread)
		@iterations.pop?
		@positions.pop?
		@index = 0
		thread.loop_stack.pop
	end
end
