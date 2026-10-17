--!nolint
--gpp!

const declare = require("@game/ReplicatedStorage/static/declare")
const project = {}

warn = warn or print

do --data
	--[=[
    	Используется как ключ доступа в сервисах управления сервером

        Старые api могут иметь отличия от нового, поэтому перемещение меж серверами с 1 версии на другую пока недоступно
        В будущем я займусь этим вопросом, так как это выглядит *очень притягательно*
    ]=]
	project.version = "unreleased"

	--[=[
        Общий ключ, по которому совместимые версии могут соединяться друг с другом
    ]=]
	project.unique = "Aftersky-chan" :: string

	--[[
        Дескриптор, сообщающий о возможной параллельности внутри этого контекта
        выполнения. Проще говоря, если это свойство имеет состояние `true`, то
        значит можно вызывать параллельные методы типа `ConnectParallel` или
        `task.synchronize()`, `task.desynchronize()`

        Поскольку `require()` всегда доступен только в синхронном контексте, это
        значит что никакой поток не потеряется, то есть его текущий контекст не
        изменится, поэтому эта информация полностью безопасна
    ]]
	project.parallel = pcall(function(): ()
		if type(task) ~= declare.table then error "project.parallel unsupported env" return end
		if type(task.desynchronize) ~= declare["function"] then error "project.parallel unsupported env" return end
		if type(task.synchronize) ~= declare["function"] then error "project.parallel unsupported env" return end

		task.desynchronize()
		task.synchronize()
	end)
end

do -- debug
	project.debug = {}

	--[==[
		Включить специальный debug mode в рантайм

		Это позволяет некоторым частям кода выполнять более сложные и дорогие операции
		для поиска ошибок, более строгих проверок и для работы тяжелых циклов
	]==]
	project.debug.state = true

	--#if DEBUG

	--[==[
		Для обычных `project.console.out()` будет трассировка стэка
	]==]
	project.debug.trace_messages = true

	project.debug.show_created_objects = if not project.debug.state then false else false
	project.debug.show_notifications_path = if not project.debug.state then false else false
	project.debug.show_channel_send_actions = if not project.debug.state then false else false
	project.debug.show_maids_releasing = if not project.debug.state then false else false
	project.debug.show_channel_internal = if not project.debug.state then false else false
	project.debug.show_pickup_internal = if not project.debug.state then false else false
	project.debug.show_signal_internal = if not project.debug.state then false else false
	project.debug.show_ikr6legs_solver_path = if not project.debug.state then false else false
	project.debug.show_reference_internal = if not project.debug.state then false else false

	--#endif
end

do -- object

	project.object = {}

	--[==[
		Объекты будут получать метаметод `__index` и будут ссылаться на родителя, даже
		если у них специально занулено требуемое поле

		Включает "Прототипное ООП" вместо обычного "ООП"
	]==]
	project.object.prototypes = false

	--[==[
		Объекты класса `struct` и его наследники будут создаваться всегда замороженными,
		вне зависимости от того что с ними было. Только `struct:host()` функции и переданый
		в `struct:new(arg)` `arg` будут способны менять эти объекты, прежде чем они зафиксируются
	]==]
	project.object.struct_freeze = true
end

do -- enums
	project.enums = {}

	--[==[
		Объекты `enumobject` будут замораживаться после создания и не смогут быть изменены позже

		С настройкой `project.enums.enumitem_freeze` пересоздаст `enumitem`, чтобы корректно установить его имя
	]==]
	project.enums.enumobject_freeze = true

	--[==[
		Объекты `enumitem` будут замораживаться после создания и не смогут быть изменены позже
	]==]
	project.enums.enumitem_freeze = false
end

do -- geometry
	project.geometry = {}

	--[==[
		Граница, за которой геометрические объекты будут считать метод `self:fuzzy_eq()`
		без `epsilon` значения как `false`, если разница между участками `A` и `B` >= чем
		это значение
	]==]
	project.geometry.fuzzy_eq_diff = 0.01
end

do --game

	project.game = {}

	--[==[
		"Первородные объекты", то бишь классы, то бишь объекты из которых потом создаются
		множества других объектов поменьше, - будут обрабатываться также как и их дети, то есть
		будут зарегистрированы в рабочих обработчиках
	]==]
	project.game.smalltalk_like = false
end

type console_out_type = never

--[=[
	Выводит сообщение об ошибке в консоль

	В разработке появление таких сообщений недопустимо
]=]
function project.console_out_error(...: unknown): console_out_type
	if project.debug.state then
		warn("error :", ...)
		error("emergency closure")
	else
		warn("error :", debug.traceback())
	end

	return nil :: console_out_type
end

function project.assert <T> (var: T, out: string?, error: boolean?) : (T, boolean)
	if error then
		if not var then
			project.console_out_error(out or "project assert failure")
			return var, false
		end
	else
		if not var then
			project.console_out(out or "project soft-assert failure")
			return var, false
		end
	end

	return var, true
end

--[=[
	Выводит сообщение в консоль

	В разработке появление сообщений такого рода нежелательно, хотя и не критично
]=]
function project.console_out (...): console_out_type
	if project.debug.state then
		print(...)

		if project.debug.trace_messages then
			warn(debug.traceback())
		end
	end

	return nil :: console_out_type
end

do
	if project.debug.state then
		_G.fg_debug = {}
	end
end

return project