--#include <build.gpp>

const types = require("@declare/types")
const Cryptography = require("@import/Cryptography")
const extension = require("@project/extension")
const global = require("@project/global")

--[==[
    Общая сборка полезных функций
]==]
export type std = {
	--[==[
        Если это `false`, то код выполняется в `main` потоке и не может быть параллельным. Иначе наоборот.
    ]==]
	read is_parallelable: boolean,

	--[==[
        Уникальная метка текущей виртуальной машины Luau.

        Позволяет определять чей именно тот или иной экземпляр. Например, 
    ]==]
	read luau_virtual_machine_mark: string,

	--[==[
        Общее наименование аттрибута, которое используется для проверки принадлежности к той или иной LVM.

        Используется потому что есть соглашение. Чисто технически можно использовать и через `Tag`
    ]==]
	read luau_virtual_machine_attribute_name: "@LUAU_VM_MARKER",

	--[==[
        Делает конкатенацию с `std.luau_virtual_machine_mark`
    ]==]
	read get_luau_universal_name: (self: std, with: string) -> string,

	--[==[
        Проверяет в каком сейчас режиме выполнения находится эта коррутина.

        Известно, что часть функций роблокса кидает ошибки при попытке доступа из паралелльного режима,
        поэтому ядро пользуется этим фактом.
    ]==]
	read is_parallel: (self: std) -> boolean,

	--[==[
        Аналогичен `assert()`, работает в экосистеме ядра
    ]==]
	read assert: <T>(self: std, condition: T, msg: string?) -> T & exist & truthful,

	--[==[
        Аналогичен `assert()`, но падает только в дебаге. В проде не упадет, если только `dummies.nullf()` разрешен.
        Иначе вернет провалившийся `condition`.
    ]==]
	read option: <T>(self: std, condition: T, msg: string?) -> T & exist & truthful,

	--[==[
        Безопасная проверка на falsy.
    ]==]
	read check: <T>(self: std, condition: T, msg: string?) -> (boolean, T & exist & truthful),

	--[==[
        Выводит сообщение об ошибке.
    ]==]
	read oute: (self: std, ...any) -> never,

	--[==[
        Выводит сообщение об ошибке для разработчиков. В проде не будет.
    ]==]
	read outm: (self: std, ...any) -> never?,

	--[==[
        Выводит сообщение.
    ]==]
	read out: (self: std, ...any) -> (),

	--[==[
        Выводит предупреждение.
    ]==]
	read outw: (self: std, ...any) -> (),
}

const std: std = table.freeze({
	luau_virtual_machine_mark = Cryptography.Hashing.Blake3.Digest(
		buffer.fromstring((tostring(tick() + math.random(1, 10000)))),
		8
	),
	luau_virtual_machine_attribute_name = "@LUAU_VM_MARKER" :: "@LUAU_VM_MARKER",

	is_parallel = function()
		const r, _ = pcall(function(...)
			const t = Instance.new("BoolValue")
			t.Parent = workspace
			t:Destroy()
		end)

		return r
	end,

	-- btw if we executing in non-roblox env then we got is_parallelable as false
	is_parallelable = pcall(function(...)
		task.desynchronize()
		task.synchronize()
	end),

	get_luau_universal_name = function(self: std, name: string): string
		return `{self.luau_virtual_machine_mark} :: @{name}`
	end,

	assert = function(self: std, condition, msg)
		if not condition then
			return self:oute(msg or "std::assert")
		else
			return condition :: any
		end
	end,

	option = function(self: std, condition, msg)
		if not condition then
			self:outm(msg or "std::optional")
			return condition :: any
		else
			return condition :: any
		end
	end,

	check = function(self: std, condition: any, msg: any): (boolean, any)
		if not condition then
			self:outw(msg or "std::check")
			return false, condition :: any
		else
			return true, condition :: any
		end
	end,

	out = function(self: std, ...): ()
		print(`{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
	end,

	outw = function(self: std, ...): ()
		const warn = warn :: any

		if type(warn) == types["function"] then
			warn(`warn::{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
		else
			self:out(`warn::{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
		end
	end,

	outm = function(self: std, ...): never
		if global.debug then
			return error(`mistake::{...}`, 2)
		else
			return self:outw(
					`mistake::{...}{if not extension.stdout.traceback then "\n" .. debug.traceback() else ""}`
				) :: never
		end
	end,

	oute = function(self: std, ...): never
		if not global.debug then
			return error(`err::{...}`, 2)
		else
			return self:outw(
					`err::{...}{if not extension.stdout.traceback then "\n" .. debug.traceback() else ""}`
				) :: never
		end
	end,
})

return std
