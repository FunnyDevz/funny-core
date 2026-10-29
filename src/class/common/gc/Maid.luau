--!strict
const Connection = require("@class/common/signal/Connection")
const Disposable = require("@class/core/Disposable")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

const private = {}
const class: maid = Disposable:new({
	type = "maid",

	add_object = ftype:write(function(self: maid, that: any, strong: boolean?): () -- #12
		if strong then
			table.insert(private.s_objects[self], that)
		else
			table.insert(private.objects[self], that)
		end
	end, mtypes.never, "maid", mtypes.anyt, ftype:opt(types.boolean)),

	add_key = ftype:write(function<T>(self: maid, of: { [T]: unknown }, key: T): ()
		if not private.pairs[self][of] then
			private.pairs[self][of] = {}
		end

		table.insert(private.pairs[self][of], key)
	end, mtypes.never, "maid", types.table, mtypes.anyt),

	remove_object = ftype:write(function(self: maid, that: any): () -- #12
		do
			const pos: number? = table.find(private.objects[self], that)

			if pos then
				table.remove(private.objects[self], pos)
			end
		end

		do
			const pos: number? = table.find(private.s_objects[self], that)

			if pos then
				table.remove(private.s_objects[self], pos)
			end
		end
	end, mtypes.never, "maid", mtypes.anyt),

	remove_key = ftype:write(function<T>(self: maid, of: { [T]: unknown }, key: T): ()
		if not private.pairs[self][of] then
			return
		end

		const pos: number? = table.find(private.pairs[self][of], key)
		if pos then
			table.remove(private.pairs[self][of], pos)
		end
	end, mtypes.never, "maid", types.table, mtypes.anyt),

	is_supported = ftype:write(function(self: maid, that: unknown): boolean
		for _, v in private.supported do
			if self:that(that, v) then
				return true
			else
				if typeof(that) == v then
					return true
				end
			end
		end

		return false
	end, types.boolean, "maid", mtypes.anyt),
})

class:host(function(new)
	const new = new:as <<maid>> (class.type)

	private.objects[new] = setmetatable({}, private.meta)
	private.s_objects[new] = {}
	private.pairs[new] = setmetatable({}, private.meta)

	new:watch(
		function()
			private.cycle(private.objects[new], private.s_objects[new])
		end,
		function()
			for k, v in private.pairs[new] do
				for _, j in v do
					k[j] = nil
				end
			end

			table.clear(private.pairs[new])
		end
	)
end)

do
	private.meta = table.freeze({ __mode = "ks" })
	private.objects = setmetatable({} :: { [maid]: { unknown } }, private.meta)
	private.s_objects = setmetatable({} :: { [maid]: { unknown } }, private.meta)
	private.pairs = setmetatable({} :: { [maid]: { [{ [unknown]: unknown }]: { unknown } } }, private.meta)

	private.supported = table.freeze({
		Connection.type,
		Disposable.type,
		rbxtypes.RBXScriptConnection,
		rbxtypes.Instance,
	})

	private.cycle = function(t: { unknown })
		for _, v in t do
			if class:that(v, "connection") then
				const connection = v :: connection
				connection:disconnect()
			elseif class:that(v, "disposable") then
				const disposable = v :: disposable
				disposable:free()
			elseif class:that(v, "reference") then
				const reference = v :: reference
				reference:set_instance(nil)
			elseif typeof(v) == rbxtypes.RBXScriptConnection then
				const connection = v :: RBXScriptConnection
				connection:Disconnect()
			elseif type(v) == types["function"] then
				const func = v :: (...any) -> () | any
				func()
			elseif typeof(v) == rbxtypes.Instance then
				const instance = v :: Instance
				instance:Destroy()
			end
		end
	end
end

return class
