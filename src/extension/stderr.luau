const dummies = require("@declare/dummies")
const stdout = require("@extension/stdout")
const global = require("@project/global")

--[==[
    Адаптер с дополнительной метаинформацией.
]==]
export type stderr = {

    --[==[
        Аналогичен `assert()`, работает в экосистеме ядра
    ]==]
    read assert: <T> (self: stderr, condition: T, msg: string?) -> T & neg<nil> & neg<false>,

    --[==[
        Аналогичен `assert()`, но падает только в дебаге. В проде не упадет, если только `dummies.nullf()` разрешен.
        Иначе вернет провалившийся `condition`.
    ]==]
    read option: <T> (self: stderr, condition: T, msg: string?) -> T & neg<nil> & neg<false>,

    --[==[
        Безопасная проверка на falsy.
    ]==]
    read check: <T> (self: stderr, condition: T, msg: string?) -> (boolean, T & neg<nil> & neg<false>)
}

const stderr : stderr = {
    assert = function (self, condition, msg)
        if (not condition) then
            return stdout:oute(msg or "stderr::assert")
        else
            return condition :: any
        end
    end,

    option = function (self, condition, msg)
        if not condition then
            stdout:outm(msg or "stderr::optional")
            return (global.nullable and dummies.nullf() or condition) :: any
        else
            return condition :: any
        end
    end,

    check = function (self, condition, msg)
        if (not condition) then
            stdout:outw(msg or "stderr::check")
            return false, (global.nullable and dummies.nullf() or condition) :: any
        else
            return true, condition :: any
        end
    end
}

table.freeze(stderr)
return stderr