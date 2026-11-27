require "./loop"
require "../../util/expression"

# While, Expression (same: `while (expression)`)
class Cmd::ControlFlow::While < Cmd::ControlFlow::Loop
	def self.min_args; 1 end
	def self.max_args; 1 end
	@started = false
	def run(thread, args)
		if ! @started
			@started = true
			thread.loop_stack << self
		end
		@index += 1
		cond = Util::Expression.truthy?(Util::Expression.eval(args[0], thread))
		finish(thread) if ! cond
		cond
	end
	def finish(thread)
		@started = false
		@index = 0
		thread.loop_stack.pop
	end
end
