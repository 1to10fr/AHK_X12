module Build
	record FuncParam, name : String, default : String?, byref : Bool
	# `locals` are the lowercased names that get saved and restored around every call.
	record FuncInfo, params : Array(FuncParam), locals : Array(String)
end
