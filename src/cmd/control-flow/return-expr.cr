require "../../util/expression"

# ReturnExpr, Expression
# `return expression` inside a function: sets the call's return value, then returns.
class Cmd::ControlFlow::ReturnExpr < Cmd::Base
	def self.min_args; 1 end
	def self.max_args; 1 end
	def run(thread, args)
		thread.return_value = Util::Expression.eval(args[0], thread)
		thread.return
	end
end
