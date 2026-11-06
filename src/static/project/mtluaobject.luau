const types = require("@declare/types")
--[==[
    Мета-информация о сборке `LuaObject` и его наследников.

    Задается мейнтейнерами ядра и изменяется вручную от сборки к сборке. Автоматизации нету. В теории
    изменения внутренней составляющей могут сломать чужой код вне ядра, если он захардкожен.
]==]
export type metaluaobject = {
    --[==[
        Текущий тип `LuaObject` через `type()`. Он зависит от сборки.
    ]==]
    read luaobject_type: string,

    --[==[
        Что на текущий момент будет возвращать `getmetatable()` функция
    ]==]
    read luaobject_getmetatable_type: string,

    --[==[
        Можно ли узнать настоящий тип `LuaObject` через `tostring()` функцию?

        Функция будет возвращать `luaobject.type`.
    ]==]
    read luaobject_can_get_type_by_tostring_func: boolean,

    --[==[
        Используй `luaobject:that(element, type)`
    ]==]
    read luaobject_can_check_without_types_is_it_a_luaobject: boolean
}

const metaluaobject: metaluaobject = {
    luaobject_type = types.table,
    luaobject_getmetatable_type = types.table,
    luaobject_can_get_type_by_tostring_func = false,
    luaobject_can_check_without_types_is_it_a_luaobject = true
}

return metaluaobject