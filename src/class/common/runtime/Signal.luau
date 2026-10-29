--!strict
const Maybe = require("@class/common/gc/Maybe")
const Event = require("@class/common/signal/Event")
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const stdrun = require("@extension/stdrun")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

const private = {type = "signal"}
const class: signal = LuaObject:new {
    type = private.type,
    use_parallel_signals = false,

    get_signal_event = ftype:write(function (self: signal) : event<enumitem_default_variant, ...any>
        return private.maybe:enactment(self, Event)
    end, Event.type, private.type),

    get_signal_source = ftype:write(function (self: signal) : (() -> ())?
        return private.store[self]
    end, ftype:opt(types["function"]), private.type),

    set_signal_source = ftype:write(function (self: signal, to: (() -> ())?) : ()
        private.store[self] = to
    end, mtypes.never, private.type, ftype:opt(types["function"])),

    apply_as_source = ftype:write(function (self: signal, ...: RBXScriptSignal) : ()
    	const list = { ... }
        if #list == 0 then return end

        const lambda = function (...)
            if stdrun:is_parallel() then
                if not self.use_parallel_signals then
                    return
                end
            end

            const event = self:get_signal_event()
            event:invoke(DefaultVariant.Any, ...)
            event:invoke(DefaultVariant.Unknown, ...)
        end

        for _, v in list do
            v:Connect(lambda)
        end

        if stdrun.is_parallelable then
            for _, v in list do
                v:ConnectParallel(lambda)
            end
        end

    end, mtypes.never, private.type, ftype:var(rbxtypes.RBXScriptSignal))
}

do
    private.store = setmetatable({} :: {[signal]: (() -> ())?}, tables.__mode_ks)
    private.maybe = Maybe:new() :: maybe<event<enumitem_default_variant>, signal>
end

return class