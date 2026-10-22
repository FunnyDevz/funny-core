--!nolint
--#include <project.gpp>

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
		if type(task) ~= declare.table then
			error("project.parallel unsupported env")
			return
		end
		if type(task.desynchronize) ~= declare["function"] then
			error("project.parallel unsupported env")
			return
		end
		if type(task.synchronize) ~= declare["function"] then
			error("project.parallel unsupported env")
			return
		end

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
	project.debug.state = --#if !DEBUG not --#endif
		true

	--#if DEBUG

	--[==[
		Для обычных `project.console.out()` будет трассировка
	]==]
	project.debug.trace_messages = true

	--[==[
		На `Object` вешается host функция, которая выводит информацию об этом объекте
	]==]
	project.debug.show_created_objects = false

	--[==[
		На `Observer` функция поиска пути будет трассировать весь путь 
	]==]
	project.debug.show_notifications_path = false
	project.debug.show_channel_send_actions = false
	project.debug.show_maids_releasing = false
	project.debug.show_channel_internal = false
	project.debug.show_pickup_internal = false
	project.debug.show_signal_internal = false
	project.debug.show_ikr6legs_solver_path = false
	project.debug.show_reference_internal = false

	--#endif
end

do -- LuaObject
	project.LuaObject = {}

	--[==[
		Объекты будут получать метаметод `__index` и будут ссылаться на родителя, даже
		если у них специально занулено требуемое поле

		Включает "Прототипное ООП" вместо обычного "ООП"
	]==]
	project.LuaObject.prototypes = false

	--[==[
		Объекты класса `struct` и его наследники будут создаваться всегда замороженными,
		вне зависимости от того что с ними было. Только `struct:host()` функции и переданый
		в `struct:new(arg)` `arg` будут способны менять эти объекты, прежде чем они зафиксируются
	]==]
	project.LuaObject.struct_freeze = true
	project.max_send_packet = 64
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
		project.console_out("error :", ...)
		error("emergency closure", 1)
	else
		print("error :", debug.traceback())
	end

	return nil :: console_out_type
end

type function neg_of_nil () return types.negationof(types.singleton(nil)) end

--[==[
	Обыкновенный `assert()`, который использует проектные способы вывода ошибок и сообщений.

	В мягкой ветке поведения он не прекращает выполнение кода, поэтому требуется дополнительно правильно
	обрабатывать поведение при провале проверки.
]==]
function project.assert<T>(var: T, out: string?, error: boolean?): (T & neg_of_nil<>, boolean)
	if error then
		if not var then
			project.console_out_error(out or "project assert failure")
			return var :: T, false
		end
	else
		if not var then
			project.console_out(out or "project soft-assert failure")
			return var :: T, false
		end
	end

	return var, true
end

--[=[
	Выводит сообщение в консоль

	В разработке появление сообщений такого рода нежелательно, хотя и не критично
]=]
function project.console_out(...): console_out_type
	if project.debug.state then
		print(...)

		if project.debug.trace_messages then
			print("traceback :: ", debug.traceback())
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
