--!nolint
--#include <project.gpp>
const types = require("@declare/types")

export type core_supported_platforms = "Roblox"|"UNKNOWN_PLATFORM"
export type core_global_info = {
    --[==[
        Версия ядра. Это отображаемая версия, она не аргумент при проверке версий.
    ]==]
    read version: string,
    
    --[==[
        Платформа под которую предназначено ядро. Выбирается на этапе билдинга исходников.
    ]==]
    read platform: core_supported_platforms?,
        
    --[==[
        Уникальный ключ версии. Если кратко, то это номер последнего коммита, то бишь номер того коммита,
        который будет забилжен. Если билд проходит не на CI платформе, то подставляется фейковый коммит
        в качестве идентификатора - `NON_PRODUCTION_BUILD`
    ]==]
    read unique: string | "UNKNOWN_BUILD",

    --[==[
        Метка, сообщающая что билд был специально залит с `debug` проверками.
    ]==]
    read debug: boolean?,
    
    --[==[
        Метка, сообщающая что билд использует экспериментальные функции и код, которые могут работать
        некорректно.
    ]==]
    read experimental: boolean?,

    --[==[
        Это довольно опасное поведение, которое позволяет `Null` не взрывать весь прод. Если оно будет `false`,
        то только `debug` сможет убрать подрыв.

        Существует специальный `Null` синглтон, который используется в разработке или при самом крайнем случае.
        Он доступен через декларационную часть.

        Требует `global.debug == true` как зависимость.
    ]==]
    read nullable: boolean,
}

--[[
    Статические константы ядра, которые определяются до момента билда и будут учитываться функционирующей структурой
]]
const global: core_global_info = table.freeze {

    version = "unreleased",

    platform = --[[#PLATFORM]] --[[#lua_OR]] "UNKNOWN_PLATFORM" :: "UNKNOWN_PLATFORM";
    unique = --[[#UNIQUE]] --[[#lua_OR]] "UNKNOWN_BUILD";

    --#if DEBUG
    debug = true,
    --#endif

    --#if EXPERIMENTAL
    experimental = true,
    --#endif

    nullable = --[[#if !DEBUG]] not --[[#endif]] true,
}

return global
