--!strict
--!nolint

-- luau 0.743

--[==[
    setmetatable<T & U, luaobject>, теряет информацию об описаниях данных для полей, свойств и функций, причем
    теряется информация как header, так и внутренностей - она просто пропадает из поля зрения LLS. Для интерсекций
    и юнионов теряется только header информация, если они не обернуты в метатаблицу

    Для заметки та же информация о luaobject остается полностью, потому что он не обернут ни в какой тип и не является
    ничьим & и |

    Для T & U без метатаблицы потери информации нет, описания разворачиваются корректно.

    С этим, однако есть тоже проблема, потому что alias `extend` также заставляет потерять тип информацию об
    его header описании. То бишь, описание самого типа может потеряться
]==]

--[==[
    hello
]==]
type s = setmetatable<{}, {r: thread}>

local s : s

local a : luaobject
local a0000 : disposable
local a0001 : observer
local a0002 : struct
local a0003 : service
local a0004 : enumitem
local a0005 : enumobject
local a0006 : variable
local a0007 : scheduler
local a0008 : pointer

a0007.plan(self, t)

local c0000 : connection
local c0001 : event
local c0002 : binder

local e0000 : enum_connection_variant
local e0000_0 : enumitem_connection_variant