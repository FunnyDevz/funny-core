--!strict

--[==[
    Тэги, применяемые к классам для быстрого опознавания кто или что это за класс
]==]
export type ctags = {

    --[==[
        Данные этого класса хранятся в SharedTable, а сам класс доступен из любой виртуальной машины
    ]==]
    read shared_parallel: "shared_parallel",

    --[==[
        Класс поддерживает RPC операции или был специально разработан для этого
    ]==]
    read rpc_compatible: "rpc_compatible",

    --[==[
        Класс работает только как часть роблокс-экосистемы и не может стабильно функционировать вне
        нее. Например, это могут быть IK системы или реализаторы эффектов.
    ]==]
    read required_roblox: "required_roblox",
}

const class_tags: ctags = {
    shared_parallel = "shared_parallel",
    rpc_compatible = "rpc_compatible",
    required_roblox = "required_roblox"
}

table.freeze(class_tags)
return class_tags