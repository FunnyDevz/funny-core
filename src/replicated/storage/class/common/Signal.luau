--!strict
const Reference = require("@class/common/Reference")
const Maybe = require("@class/common/gc/Maybe")
const Event = require("@class/common/signal/Event")
const tables = require("@declare/tables")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")
const TickNotification = require("@enums/notification/TickNotification")
const ftype = require("@static/ftype")

const private = {}
const class : signal = (Reference :: reference<RBXScriptSignal>):new {
    type = "signal",

    get_signal_event = ftype:write(function (self: signal) : event<enumitem_tick_notification, ...unknown>
        return private.maybe:enactment(self, Event) :: event<any>
    end, Event.type, "signal")
}

class:host(function(new)
    const new = new:as <<signal>> (class.type)
    new:subscribe({ReferenceNotification.ChangedInstance, ReferenceNotification.NewInstance}, ConnectionVariant.Ever, function ()
        const con = private.con[new]
        if con then
            con:Disconnect()
        end

        private.con[new] = new:get_instance():Connect(function(...: unknown)
            if private.maybe:exist(new) then

                new:get_signal_event():invoke(TickNotification.Stepped, ...)
            end
        end)
    end)
    new:subscribe(ReferenceNotification.NullifiedInstance, ConnectionVariant.Ever, function ()
        const con = private.con[new]
        if con then
            private.con[new] = nil
            con:Disconnect()
        end
    end)
end)

do
    private.maybe = Maybe:new()
    private.con = setmetatable({} :: {[signal]: RBXScriptConnection?}, tables.__mode_ks)
end

return class