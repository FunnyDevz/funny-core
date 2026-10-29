const types = require("@declare/types")
const extension = require("@project/extension")
const global = require("@project/global")

--[==[
    Специальная обертка над выводом в консоль
]==]
export type stdout = {
    --[==[
        Выводит сообщение об ошибке.
    ]==]
    read oute: (self: stdout, ...any) -> never,
    --[==[
        Выводит сообщение об ошибке для разработчиков. В проде не будет.
    ]==]
    read outm: (self: stdout, ...any) -> never,
    --[==[
        Выводит сообщение.
    ]==]
    read out: (self: stdout, ...any) -> (),
    --[==[
        Выводит предупреждение.
    ]==]
    read outw: (self: stdout, ...any) -> ()
}

const stdout: stdout = {
    out = function (self, ...) : ()
        print(`{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
    end,
    
    outw = function (self, ...) : ()
        const warn = warn :: any

        if (type(warn) == types["function"]) then
            warn (`warn::{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
        else
            self:out(`warn::{...}{if extension.stdout.traceback then "\n" .. debug.traceback() else ""}`)
        end
    end,

    outm = function (self, ...) : never
        if (global.debug) then
            return error(`mistake::{...}`, 2)
        else
            return self:outw(`mistake::{...}{if not extension.stdout.traceback then "\n" .. debug.traceback() else ""}`) :: never
        end
    end,

    oute = function (self, ...) : never
        if (not global.debug) then
            return error(`err::{...}`, 2)
        else
            return self:outw(`err::{...}{if not extension.stdout.traceback then "\n" .. debug.traceback() else ""}`) :: never
        end
    end
}

table.freeze(stdout)
return stdout