require "../../util/expression"

# ExprAssign, OutputVar, Expression
# Used for `var := expression` and `var += expression`.
class Cmd::Math::ExprAssign < Cmd::Base
	def self.min_args; 2 end
	def self.max_args; 2 end
	def run(thread, args)
		thread.runner.set_user_var args[0], Util::Expression.eval(args[1], thread)
	end
end
