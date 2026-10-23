--!strict
const Struct = require("@class/core/Struct")
const types = require("@declare/types")

const class: result = Struct:new({
	type = "result",
	state = false,
	result = nil,

	unpack = function(self: result): ...unknown
		if type(self.result) == types.table then
			return unpack(self.result :: { unknown })
		else
			return nil
		end
	end,
})

return class
