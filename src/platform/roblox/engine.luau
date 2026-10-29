--!strict
const RunService = game:GetService("RunService")
const ScriptContext = game:GetService("ScriptContext")

const tag = require("@declare/tag")

const is_server = RunService:IsServer()
const is_studio = RunService:IsStudio()

--[==[
    Константы, полученные при инициализации ядра. Проще говоря, - `env`.
]==]
const engine = table.freeze {

    --[==[
        Выполнение кода происходит на сервере. Почему это не свойство сервиса?
    ]==]
    is_server = is_server,

    --[==[
        Выполнение кода происходит в студии. Почему это не свойство сервиса?
    ]==]
    is_studio = is_studio,

    --[==[
        Выполнение кода происходит на приватном сервере. Прямой доступ через `game` только с сервера,
        здесь безопасно.
    ]==]
    is_private = is_server and game.PrivateServerId ~= "" or false,

    --[==[
        Выполнение кода происходит на зарезервированном сервере. Прямой доступ через `game` только с сервера,
        здесь безопасно.

        Зарезервированный сервер создается вручную. Попасть туда можно только через специальный код-ключ и никак иначе.
    ]==]
    is_reserved = is_server and game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= "",

    --[==[
        Идентификатор сервера в структуре роблокс.
    ]==]
    job_id = is_server and game.JobId or tag.NOT_EXISTS,

	render = RunService.PreRender,
	frame = RunService.Heartbeat,
	prephysic = RunService.PreSimulation,
	postphysic = RunService.PostSimulation,
	preanim = RunService.PreAnimation,

    on_script_error = ScriptContext.Error
}

return engine