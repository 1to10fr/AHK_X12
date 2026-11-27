# Global [, Var1, Var2, ...]
# All variables are global in this interpreter already, so declarations inside functions do nothing.
class Cmd::Misc::Global < Cmd::Base
	def self.min_args; 0 end
	def self.max_args; 1 end
	def run(thread, args)
	end
end
# Local / Static: accepted for compatibility, no effect (see Global).
class Cmd::Misc::Local < Cmd::Misc::Global
end
class Cmd::Misc::Static < Cmd::Misc::Global
end
