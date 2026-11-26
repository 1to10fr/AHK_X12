require "../../util/expression"

# IfExpr, Expression (same: `if (expression)`)
class Cmd::ControlFlow::IfExpr < Cmd::Base
	def self.min_args; 1 end
	def self.max_args; 1 end
	def self.conditional; true end
	def run(thread, args)
		Util::Expression.truthy?(Util::Expression.eval(args[0], thread))
	end
end
