--!strict
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class: disposable = LuaObject:new({
	type = "disposable",

	free = ftype:write(function(self: disposable, deffered: boolean?): ()
		if deffered then
			task.defer(private.free, self)
		else
			private.free(self)
		end
	end, mtypes.never, "disposable", ftype:opt(types.boolean)),

	released = ftype:write(function(self: disposable): boolean
		return private.objects[self:iden()] == nil
	end, types.boolean, "disposable"),

	watch = ftype:write(function(self: disposable, ...: (self: disposable) -> ())
		const list = { ... }
		const dest = private.watch[self]
		table.move(list, 1, #list, #dest + 1, dest)
	end, mtypes.never, "disposable", types["function"]),

	get = function<Y>(self: disposable, label: unknown): Y
		return private.shadow_space[self][label]
	end,

	set = function<Y>(self: disposable, label: unknown, to: Y): ()
		private.shadow_space[self][label] = to
	end,
})

class:host(function(new)
	const new = new:as <<disposable>> (class.type)
	
	private.shadow_space[new] = {}
	private.objects[new:iden()] = new
	private.watch[new] = {}
end)

do
	private.meta = tables.__mode_ks
	private.shadow_space = setmetatable({} :: { [disposable]: { [any]: any } }, private.meta)
	private.objects = {} :: { [unknown]: disposable }
	private.watch = setmetatable({} :: { [disposable]: { (disposable) -> () } }, private.meta)
	private.free = function(that: disposable)
		private.objects[that:iden()] = nil

		for _, v in table.clone(private.watch[that]) do
			pcall(v, that)
		end

		table.clear(private.watch[that])
		private.watch[that] = nil
	end
end

ctype:read(class):write_tag(ctags.core)

return class
