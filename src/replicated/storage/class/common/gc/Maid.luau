--!strict
const Disposable = require("@game/ReplicatedStorage/class/core/Disposable")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: maid = Disposable:new({
	type = "maid",

	add_object = ftype:write(function(self: maid, that: any, strong: boolean?): () -- #12
		if strong then
			table.insert(private.s_objects[self], that)
		else
			table.insert(private.objects[self], that)
		end
	end, declare["nil"], "maid", declare.anyt, ftype:opt(declare.boolean)),

	add_key = ftype:write(function<T>(self: maid, of: { [T]: unknown }, key: T): ()
		if not private.pairs[self][of] then
			private.pairs[self][of] = {}
		end

		table.insert(private.pairs[self][of], key)
	end, declare["nil"], "maid", declare.table, declare.anyt),

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
	end, declare["nil"], "maid", declare.anyt),

	remove_key = ftype:write(function<T>(self: maid, of: { [T]: unknown }, key: T): ()
		if not private.pairs[self][of] then
			return
		end

		const pos: number? = table.find(private.pairs[self][of], key)
		if pos then
			table.remove(private.pairs[self][of], pos)
		end
	end, declare["nil"], "maid", declare.table, declare.anyt),

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
	end, declare.boolean, "maid", declare.anyt),
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
		end,
		if project.debug and project.debug.show_maids_releasing
			then function()
				project.console_out("maid ", new:iden(), " is released")
			end
			else nil :: never
	)
end)

do
	private.meta = table.freeze({ __mode = "ks" })
	private.objects = setmetatable({} :: { [maid]: { unknown } }, private.meta)
	private.s_objects = setmetatable({} :: { [maid]: { unknown } }, private.meta)
	private.pairs = setmetatable({} :: { [maid]: { [{ [unknown]: unknown }]: { unknown } } }, private.meta)

	private.supported = table.freeze({
		"connection",
		"disposable",
		declare.roblox.RBXScriptConnection,
		declare.roblox.Instance,
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
				reference:clear()
			elseif typeof(v) == declare.roblox.RBXScriptConnection then
				const connection = v :: RBXScriptConnection
				connection:Disconnect()
			elseif type(v) == declare["function"] then
				const func = v :: (...any) -> () | any
				if project.debug then
					func()
				else
					pcall(func)
				end
			elseif typeof(v) == declare.roblox.Instance then
				const instance = v :: Instance
				instance:Destroy()
			else
				project.console_out("unknown LuaObject, skip")
			end
		end
	end
end

return class
