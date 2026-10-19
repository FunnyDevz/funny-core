--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")

const private = {}
const class = LuaObject:new({
	type = "disposable",

	free = ftype:write(function(self: disposable, deffered: boolean?): ()
		if deffered then
			task.defer(private.free, self)
		else
			private.free(self)
		end
	end, declare["nil"], "disposable", ftype:opt(declare.boolean)),

	released = ftype:write(function(self: disposable): boolean
		return private.objects[self:iden()] == nil
	end, declare.boolean, "disposable"),

	watch = ftype:write(function(self: disposable, ...: (self: disposable) -> ())
		const list = { ... }
		const dest = private.watch[self]
		table.move(list, 1, #list, #dest + 1, dest)
	end, declare["nil"], "disposable", declare["function"]),

	get = function<Y>(self: disposable, label: unknown): Y
		return private.shadow_space[self][label]
	end,

	set = function<Y>(self: disposable, label: unknown, to: Y): ()
		private.shadow_space[self][label] = to
	end,
})

class:host(function(new: disposable)
	const new = new:as <<disposable>> (class.type)
	
	private.shadow_space[new] = {}
	private.objects[new:iden()] = new
	private.watch[new] = {}
end)

do
	private.meta = declare.tables.__mode_ks
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
