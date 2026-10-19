--!strict
const Reference = require("@game/ReplicatedStorage/class/common/Reference")
const Maybe = require("@game/ReplicatedStorage/class/common/gc/Maybe")
const Event = require("@game/ReplicatedStorage/class/common/signal/Event")
const ConnectionVariant = require("@game/ReplicatedStorage/enums/descriptor/ConnectionVariant")
const ReferenceNotification = require("@game/ReplicatedStorage/enums/notification/ReferenceNotification")
const TickNotification = require("@game/ReplicatedStorage/enums/notification/TickNotification")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class : signal = Reference:new {
    type = "signal",

    get_signal_event = ftype:write(function (self: signal) : event<enumitem_tick_notification, ...unknown>
        return private.maybe:enactment(self, Event) :: event<any>
    end, "event", "signal")
}

class:host(function(new)
    const new = new:as <<signal>> (class.type)
    new:subscribe({ReferenceNotification.ChangedInstance, ReferenceNotification.NewInstance}, ConnectionVariant.Ever, function ()
        const con = private.con[new]
        if con then
            con:Disconnect()
        end

        if project.debug.show_signal_internal then
            project.console_out "changed signal instance"
        end

        private.con[new] = new:get_instance():Connect(function(...: unknown)
            if private.maybe:exist(new) then
                if project.debug.show_signal_internal then
                    project.console_out "signal emitted"
                end

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

        if project.debug.show_signal_internal then
            project.console_out "signal nullified"
        end
    end)
end)

do
    private.maybe = Maybe:new()
    private.con = setmetatable({} :: {[signal]: RBXScriptConnection?}, table.freeze {__mode = "ks"})
end

return class