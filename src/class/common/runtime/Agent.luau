const Debris = game:GetService("Debris")
const Maybe = require("@class/common/gc/Maybe")
const Signal = require("@class/common/runtime/Signal")
const Event = require("@class/common/signal/Event")
const Disposable = require("@class/core/Disposable")
const tables = require("@declare/tables")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const State = require("@enums/state/State")
const stdout = require("@extension/stdout")
const datamodel = require("@platform/roblox/datamodel")
const engine = require("@platform/roblox/engine")
const instance = require("@platform/roblox/instance")

--[[    --[==[
        Возвращает источник, из которого был загружен агент. Это может быть модуль или скрипт.
    ]==]
    read get_agent_source: (self: agent) -> string?,

    --[==[
        Устанавливает строку на источник
    ]==]
    read set_agent_source: (self: agent, to: string?) -> (),

    --[==[
        Включает этого агента, всегда создавая полностью с нуля новую среду с новым агентом и 
        его загрузкой. Это позволяет перезапускать модули или запускать скрипты без любой проблемы.
    ]==]
    read start: (self: agent) -> (),

    --[==[
        Выключает этого агента, путем полного его удаления, включая внутреннего исполнителя.
    ]==]
    read shutdown: (self: agent) -> (),

    --[==[
        Возвращает основную шину, через которую с агентом можно общаться.
    ]==]
    read get_agent_message_bus: (self: agent) -> event<enumitem<any>>,

    --[==[
        Возвращает текущий статус агента в системе
    ]==]
    read get_agent_status: (self: agent) -> enumitem_state,

    --[==[
        Возвращает ивент, сообщающий об изменениях состояния агента.
    ]==]
    read get_agent_status_changed_event: (self: agent) -> event<enumitem_state>]]

const private = {type = "agent"}
const class : agent = Disposable:new {
    type = private.type,

    get_agent_source = function (self: agent) : string?
        return self:get(private.source) :: string?
    end,

    set_agent_source = function (self: agent, to: string?) : ()
        self:set(private.source, to)
    end,

    start = function (self: agent) : ()
        const status = self:get_agent_status()

        --#if DEBUG
        if status == State.Failure then
            stdout:oute("agent still have Fail status, you should reset it. Use agent:shutdown()")
        end
        --#endif

        if status == State.Nothing or status == State.Successful then
            const actor = private.do_deploy(self)
            const needle = datamodel.find_by_absolute_path(self:get_agent_source() or "")

            if needle == nil then
                --#if DEBUG
                stdout:outm("agent source is nil, nothing happened")
                --#endif
                return self:shutdown()
            elseif needle:IsA("ModuleScript") then
                --#if DEBUG
                stdout:outw("ModuleScript isn't supported, you should use Script with context 'Client'")
                --#endif
                return self:shutdown()
            elseif needle:IsA("LocalScript") then
                --#if DEBUG
                stdout:outw("LocalScript is unsupported, you should use Script with context 'Client'")
                --#endif
                return self:shutdown()
            elseif not needle:IsA("Script") then
                --#if DEBUG
                stdout:outw("received roblox Instance isn't a Script")
                --#endif
            end

            private.status[self] = State.Loading

            const copy = needle:Clone() :: Script
            copy.Enabled = true
            copy.Parent = actor

            if private.changed:exist(self) then
                const event = private.changed:extract(self, Event)

            end
        end
    end,

    shutdown = function (self: agent) : ()
        if self:get_agent_status() == State.Nothing then
            return
        end

        const previous = private.get_deployed(self)
        if previous then
            Debris:AddItem(previous, 1)
        end

        private.status[self] = State.Successful
    end,

    get_agent_message_bus = function (self: agent) : event<enumitem<any>>
        return private.bus:enactment(self, Event)
    end,

    get_agent_status = function (self: agent) : enumitem_state
        return private.status[self] or State.Nothing
    end,

    get_agent_status_changed_event = function (self: agent) : event<enumitem_state>
        return private.changed:enactment(self, Event)
    end,

    get_agent_of = function (self: agent, that: Script|Actor) : agent?
        const actor = instance.object.get_invariant <<Actor>>(that, "Actor")
        if not actor then return nil end
        if not actor:HasTag(private.agent_mark) then return nil end

        return private.agents[actor:GetAttribute(private.agent_attribute) :: string]
    end,

    reboot = function (self: agent) : ()
        self:shutdown()
        self:start()
    end,

    is_agent = function (self: agent, that: Script|Actor) : boolean
        const actor = instance.object.get_invariant <<Actor>>(that, "Actor")
        if not actor then return false end
        if not actor:HasTag(private.agent_mark) then return false end
        return true
    end
}

class:host(function(new: luaobject)
    --#if DEBUG
    const new = new:as <<agent>> (class.type)
    --#endif

    private.agents[new:iden()] = new
    new:set(private.deploy, {})
end)

do
    private.source = newproxy()
    private.status = setmetatable({} :: {[agent]: enumitem_state?}, tables.__mode_ks)
    private.changed = Maybe:new() :: maybe<event, agent>
    private.bus = Maybe:new() :: maybe<event, agent>
    private.deploy = newproxy()
    private.agent_mark = `@{private.type}_mark`
    private.agents = setmetatable({} :: {[string]: agent}, tables.__mode_vs)
    private.agent_attribute = `@{private.type} :: agent_identity`

    private.get_deployed = function (of: agent)
        return of:get(private.deploy) :: Actor?
    end

    private.bus:subscribe(OperationVariant.New, ConnectionVariant.Ever, function (agent: agent, event: event)

    end)

    private.do_deploy = function (to: agent)
        const new = Instance.new "Actor"
        new.Name = tostring(to:iden())
        new:AddTag(private.agent_mark)
        new:SetAttribute(private.agent_attribute, to:iden())
        
        new.Parent = script
        to:set(private.deploy, new)
        return new
    end

    private.agency_watch = Signal:new() :: signal<string, string, BaseScript>
    private.agency_watch:apply_as_source(engine.on_script_error)
    private.agency_watch_list = setmetatable({}, tables.__mode_ks)

    private.agency_watch:get_signal_event():connect(DefaultVariant.Any, function(message, stack, script)
        const actor = script:GetActor()
        if not actor then return end

        if script:IsA("Script") then
            if class:is_agent(actor) then
                const agent = class:get_agent_of(script)
                if agent then
                    --#if DEBUG
                    stdout:outw("agent down")
                    --#endif
                    private.status[agent] = State.Failure
                end
            end
        end
    end)
end

return class