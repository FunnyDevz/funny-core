# AGENTS.md

## 1. Общая картина

Проект — это **ядро игрового рантайма на Luau/Roblox**, реализующее собственную объектную модель поверх `luaobject`-типов, объявленных в `src/core.d.luau`. Всё, что пишется в `src/class/**`, обязано реализовывать типы из `core.d.luau`, а не придумывать новый контракт. Файл `src/core.d.luau` — **источник истины** по интерфейсам и RTTI-механике.

Ключевой принцип — **наследование через интерсекцию типов**, а не через цепочки метатаблиц в духе обычного ООП. Базовый тип — `luaobject`, а расширение — `extend<extension, base>`. Всё остальное (сервисы, структуры, енамы, контроллеры, ивенты) собирается из этих двух кирпичей.

```luau
export type extend<extension = {}, base = luaobject> = extension & base
```

Любое отклонение от этого принципа (ручные метатаблицы, «нормальные» классы, копирование поведения других языков) считается нарушением архитектуры. В дальнейшем смотрите по фактическому состоянию проекта, эта инструкция может быть устаревшей в реализации. В стилистике она гарантированно не устареет.

---

## 2. Базовые концепции, которые агент обязан знать

### 2.1. `luaobject`

Базовый объект проекта — не класс, а **семантический прототип**: и класс, и экземпляр являются `luaobject`. Конструирование идёт через `:new()`, инициализация — через `:host(f)`, финализация — через `:finally(f)`. `luaobject` несёт в себе RTTI: `type`, `it`, `is`, `as`, `same`, `eq`, `base`, `iden`, `ttype`.

Если агенту нужно написать что-то, «что является объектом проекта», он **не должен** писать `{ ... }` руками. Он должен объявить тип в `core.d.luau` и унаследовать от `luaobject` (напрямую или через один из базовых интерфейсов).

### 2.2. Struct

`struct` — **неизменяемый носитель данных**, без скрытого состояния. Изменения — только через `:clone(change)` и `:new()`. Все «информационные» классы (`*Info`, `NetPack`, `Result`, геометрия, `Basis` и т.п.) реализуются как `struct`. Итерация по значениям — через `:each(type, f)`.

Если агенту нужно изменить `struct` — нельзя писать мутирующий сеттер. Нужно либо объявить новое поле и создавать через `clone`, либо оставить как есть.

### 2.3. Enums

Енамы устроены как объекты: `enumobject` (контейнер, содержит `enumitem`-ы) и `enumitem` (конкретное значение). Они не используют Roblox `Enum`, а являются «своими». Реализации енамов лежат в `src/enums/{descriptor,mode,notification,state}/*.luau`, а их типы — в `core.d.luau` рядом с соответствующими `enumitem_*`/`enum_*`.

Правило: **любой новый енам** добавляется и в `src/enums/**`, и в `core.d.luau` (типы `enumitem_*` и `enum_*`).

### 2.4.  Observer

`observer` — типизированный наблюдатель. На его основе строятся `event`, `connection`, `signal`, `value`, `timer`, `binder`, `reference`, `quant`, `statemachine`, `maid`, `maybe`, `profile` и т.д. Поведение подписок описывается через `enumitem_connection_variant` (`Ever`, `Once`, `Skip`, `Next`).

Если агенту нужен «свой ивент» — не изобретать новый механизм, использовать `event`/`observer`.

### 2.5. Сервисы

`service` — синглтон-объект с `name`, `enabled`. Сервисы лежат в `src/class/service/` (`DataClient`, `DataServer`, `SharedNet`). Публичные API сервисов должны иметь типы в `core.d.luau`.

### 2.6. Платформенный слой

Роблоксовые обёртки (Instance, Players, RBXScriptSignal, worldspace, network, datamodel, engine) — в `src/platform/roblox/`. **Игровая логика и ядро не должны напрямую зависеть от Roblox**, если для этого есть обёртка. Прямое обращение к `game`, `workspace`, `Enum`, `CFrame` допустимо, но только в `platform/` или там, где это заявлено контрактом. Если по другому невозможно, то так уж и быть это может быть пропущено. Смотря по контексту ситуации.

### 2.7. Метаданные типов

`src/static/` — это **собственный слой типизации**, который:
- описывает допустимые типы (`mtargument`, `mtypes`, `utypes`);
- валидирует аргументы и типы (`ftype`, `ctype`);
- содержит «мета-информацию» о полях и их происхождении (`mtinfo`);
- предоставляет декларации (`declare/`) для всех остальных слоёв.

Если агент добавляет новый тип/поле/контракт — соответствующая запись должна появиться в `src/static/**` (в частности в `src/static/mtargument` и `src/static/declare/mtypes`, где хранятся мета-типы), иначе валидация не увидит нововведение. По крайней мере это касается только если стандартными средствами не удалось ничего описать.

### 2.8. Scheduler vs task

В проекте есть собственный `scheduler`, который **конфликтует** с `task`. По умолчанию новый код должен использовать `scheduler`, если он уже присутствует в контракте класса. Смешивать их в одном модуле разрешено только с рантайм проверкой чей это конкретно код? Для этого используй `scheduler:whose()` и ветки.

---

## 3. Структура каталогов и что в них живёт

```
src/
├── core.d.luau              # типы и контракты (источник истины)
├── class/                   # реализации объектов
│   ├── common/              # универсальные: Binder, Reference, Stack,
│   │                        # StateMachine, Value, Signal, Timer, Quant,
│   │                        # Controller, Maybe, Maid, Event, Connection
│   ├── core/                # ядро RTTI: LuaObject, EnumItem, EnumObject,
│   │                        # Disposable, Observer, Path, Pointer,
│   │                        # Scheduler, Service, Struct, Variable
│   ├── game/                # игровые сущности: Ability, Character,
│   │                        # Faction, Round, inventory/, character/ik/r6/
│   ├── service/             # сервисы: DataClient, DataServer, SharedNet
│   └── struct/              # структуры данных
│       ├── common/          # NetPack, Result
│       ├── game/            # AbilityInfo, CharacterInfo, ik/*
│       └── geometry/        # AABBVolume, Basis, CubeVolume, Directions,
│                            # GeoVolume, OBBVolume, Quad, Triangle
├── enums/                   # свои EnumObject/EnumItem
│   ├── descriptor/          # «варианты» (DirectionVariant, NetSource, ...)
│   ├── mode/                # режимы (IKLimbMode)
│   ├── notification/        # типы уведомлений
│   └── state/               # состояния (ControllerState, RoundState, ...)
├── extension/               # std и ttable — расширения языка
├── platform/roblox/         # обёртки Roblox API
├── settings/                # префы (DataServerPref, SharedNetPref)
├── static/                  # слой метаданных/типизации
├── temp/                    # отладочные инструменты (не для продакшена)
└── templates/               # шаблоны class/script/struct
```

**Правило соответствия слоёв:** `class/**` реализует `core.d.luau`; `enums/**` реализует собственные `enumobject`; `static/**` валидирует и описывает их; `platform/**` прячет Roblox.

---

## 4. Стиль типов и именование

1. **Один публичный тип = одно объявление в `core.d.luau`.** Реализации не «изобретают» поля, а следуют объявленному контракту.
2. **Интерфейсы** объявляются как `export type <name> = { read <field>: ... }`. Методы объекта — это `read`-функции, свойства — `read`-поля. Только данные не ссылочного типа могут быть изменяемыми. При этом классам запрещено иметь в публичном поле видимости ссылочные типы кроме функций: это касается свойств/полей таблиц. Мутации для `struct` запрещены.
3. **Поля-свойства объекта** называются в `snake_case` (например, `hit_position`, `up_direction`, `current_basis`).
4. **Методы объекта** начинаются с глагола (`get_*`, `set_*`, `is_*`, `has_*`, `from_*`, `apply_*`, `add_*`, `rem_*`, `rebuild_*`, `invoke_*`).
5. **Имена интерфейсов-миксинов** начинаются с префикса (`list_checks`, `list_operations`, `math_operations`, `geometry_*`, `vector_operations`, `I_targetable`, `positioned`, `rotateable`, `centerable`, `stateable`, `informable`, `initiable`, `switchable`, `instanceable`, `referenceable`, `controllable`, `modifier`, `iterations`, `loopable`, `reloadable`, `private_storage`, `invokeable`, `asyncable`).
6. **Енамы:** `enum_<name>` — контейнер, `enumitem_<name>` — конкретный енам. Имена `enumitem`-ов — PascalCase (`DataLoaded`, `ProfileLoading`, `TickNotification`).
7. **События и уведомления:** `enumitem_<x>_notification` и `enum_<x>_notification`.
8. **Структуры-информации:** `*info` (`abilityinfo`, `characterinfo`, `ikr6leginfo`), не «data» или «config».

---

## 5. Правила изменений

### 5.1. Изменение контракта

Любое изменение `core.d.luau` (новое поле, новый тип, новый интерфейс) требует:
1. Обновления `src/static/**` — если тип участвует в валидации.
2. Обновления `src/enums/**` — если вводится новый енам.
3. Реализации в соответствующем `src/class/**` — если контракт декларативный, реализация всё равно должна быть приведена в соответствие.
4. Проверки, что существующие реализации не нарушают новых требований.

### 5.2. Разделяй слои

- `core.d.luau` — только типы.
- `src/class/**` — только реализации контрактов.
- `src/enums/**` — только объекты енамов.
- `src/static/**` — только мета-описание.
- `src/platform/**` — только обёртки над Roblox.
- `src/settings/**` — только префы.
- `src/temp/**` — временное, удаляемо, не для продакшена.

Смешивать слои нельзя. Если появляется соблазн «положить утилиту рядом» — она кладётся в `src/extension/` или в соответствующий слой.

### 5.3. Не ломай RTTI

`luaobject`-механика (`new`, `host`, `finally`, `base`, `ttype`, `it`, `is`, `as`, `same`, `eq`) — обязательна. Новый класс **не должен** подменять её своими метатаблицами. Наследование — только через `extend`.

### 5.4. Enum-объекты, а не Roblox Enum

Новый енам оформляется как `enumobject`, а не как `Enum.<X>`. В `core.d.luau` должны появиться `enum_<name>` и `enumitem_<name>`.

### 5.5. Валидация

Если тип участвует в `ftype:validate` / `ctype:validate` — его мета-описание обязано быть в `src/static/**`. Без этого валидация «не увидит» объект или поле.

### 5.6. Scheduling

Новый код по умолчанию использует `scheduler`, а не `task`. Если класс уже реализует `scheduler` — не подмешивать `task`, они конфликтуют.

---

## 6. Области проекта, требующие согласования

В репозитории есть `/.github/CODEOWNERS` — он определяет, какие участки кода кому принадлежат и кто должен ревьюить изменения. Перед изменением участков, не относящихся к зоне ответственности агента/контрибьютора, нужно **согласовать изменение с владельцем участка** — код нельзя менять «в обход» без явного запроса.

Практическое правило: если агент собирается править файл, который не является «своим» по `CODEOWNERS`, он должен явно обозначить это в PR/сообщении и дождаться ответа владельца. Молчаливые правки чужих участков недопустимы.

---

## 7. Области, помеченные как требующие внимания (в общем виде)

В проекте есть участки, которые либо не завершены, либо помечены как «в разработке»/«требует доработки», либо зависят от внешних согласований. Их правки не запрещены, но требуют **отдельного анализа и явного запроса** — менять их «по пути» или «заодно» нельзя.

Если агент видит в `core.d.luau` TODO-комментарии, `*_TODO_*`-типы, незаполненные ветки (например, закомментированные геометрические объёмы), либо сталкивается с нереализованным классом, который ещё не имеет имплементации в `src/class/**`, — это сигнал, что:

1. Правки такого участка нужно **сначала обсудить**, а не реализовывать одним движением.
2. Если правка затрагивает чужой участок по `CODEOWNERS` — согласовать с владельцем.
3. Реализация «как получится» не приветствуется: либо полная имплементация по контракту, либо оставление участка как есть.

Правило: **не додумывать поведение за автора контракта**. Если контракт неоднозначен — уточнять, а не реализовывать наугад.

---

## 8. Быстрый чек-лист для агента

- [ ] Тип объявлен в `core.d.luau`?
- [ ] Реализация соответствует объявленному типу (все `read`-поля/методы присутствуют)?
- [ ] Наследование идёт через `extend`, а не через самодельные метатаблицы?
- [ ] Для `struct` — нет мутирующих сеттеров, изменения только через `clone`?
- [ ] Для нового енама — есть и `src/enums/**`, и типы в `core.d.luau`?
- [ ] Для нового поля — есть мета-описание в `src/static/**`?
- [ ] Нет прямых зависимостей ядра от Roblox (только через `src/platform/roblox`)?
- [ ] Не добавлен `task`, если класс уже реализует `scheduler`?
- [ ] Не изменён чужой участок без согласования по `CODEOWNERS`?
- [ ] Не реализован «TODO-участок» без явного запроса?
- [ ] Не смешаны слои (`class`/`struct`/`enum`/`static`/`platform`)?

Если хоть один пункт не выполнен — изменение не готово.

# 9. Построение класса

Раздел описывает **как именно строится класс** в проекте, на примере `Observer.luau`. Все классы обязаны следовать этой структуре; отклонения допустимы только если они продиктованы контрактом из `core.d.luau` и согласованы с владельцем участка. Это не прям строгая инструкция как нужно делать РАНТАЙМ класса, потому что это инструкция как АРХИТЕКТУРНО строить класс в единой стилистике с проектом.

## 9.1. Скелет файла

Любой файл класса имеет фиксированный скелет:

```luau
--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

-- 1. Импорты
const LuaObject = require("@class/core/LuaObject")
...

-- 2. Локальные type-алиасы
type observer_on<T = enumitem> = ...
type observer_var<T = unknown> = ...

-- 3. Приватное пространство
const private = { type = "observer" }

-- 4. Создание класса
const class: observer = LuaObject:new({ ... })

-- 5. Инициализатор
class:host(function(new) ... end)

-- 6. Приватный блок
do ... end

-- 7. Возврат
return class
```

Агент **не должен** менять этот порядок. Все 7 частей присутствуют всегда; если какая-то часть не нужна (например, `do`-блок), она либо пустая, либо отсутствует, но не переезжает в другое место.

## 9.2. Заголовок модуля и импорты

- `--!strict` — обязателен.
- `--#include` — обязательны, порядок фиксирован: `project.gpp` → `build.gpp` → `fflag_core.gpp` → `fflag.gpp`.
- Импорты идут через алиасы путей `@class/*`, `@enums/*`, `@declare/*`, `@extension/*`, `@project/*`, `@static/*`. Прямые относительные пути (`./`, `../`) — не используются.
- После импортов идёт **группировка по слоям**: сначала ядро (`LuaObject`, `EnumItem`, `EnumObject`, `Pointer`), потом енамы, потом `declare`, потом `extension`/`static`/`project`. Это не формальное правило, но согласованный порядок; сорвать его — плохая практика.

## 9.3. Локальные type-алиасы

Локальные алиасы (`observer_on`, `observer_var`) объявляются **до** `private` и **до** `class`. Они нужны, чтобы:
- упростить сигнатуры `ftype:write`;
- дать имя «фактическому» типу, который используется только внутри модуля.

Это **не** экспортируемые типы. Экспортируемые — только в `core.d.luau`.

## 9.4. Приватное пространство `private`

`const private = { type = "<type>" }` — это **не** обычная таблица. В неё складывается всё, что не должно утечь наружу: константы типа, `newproxy()`-сентинелы, `metatable`-ы, вспомогательные функции, `shadow_space`, `dummies`, `relevant_actions` и т.п.

Ключевые правила:

1. **`private.type`** — строковый идентификатор класса. Он совпадает с тем, что передаётся в `:new({ type = ... })`, и с тем, что используется в `:as<<observer>>(class.type)`, `:that(x, class.type)`, `ftype:write(..., private.type, ...)`.
2. **`private.shadow_space`** — таблица со слабыми ключами (`tables.__mode_ks`), куда складывается per-object состояние, доступное через `self:get`/`self:set`.
3. **`private.pointers`, `private.items`** — `newproxy()`-сентинелы. Их нельзя заменить на строки или таблицы, потому что через них `private_storage` (`:get`/`:set`) отделяет приватные поля одного класса от полей другого.
4. **Вспомогательные функции** кладутся в `private` и становятся доступны только внутри модуля.
5. **Публичные поля класса** (`deferred_call`, `deferred_mode`, `allow_new_connections`) объявляются прямо в `:new({...})` и являются `read`-полями контракта.

## 9.5. Создание класса через `LuaObject:new`

```luau
const class: observer = LuaObject:new({
    type = private.type,
    ...
    subscribe = ftype:write(...),
    ...
})
```

- Класс — это **результат** `LuaObject:new({...})`, а не отдельная конструкция.
- Все публичные поля и методы перечисляются в одном литерале.
- Поля-данные — просто значения (`deferred_call = true`).
- Методы — обёрнуты в `ftype:write`. **Без обёртки метод не считается публичным контрактом**, потому что `ftype` проверяет аргументы и типы на входе и выходе.

## 9.6. Обёртка методов `ftype:write`

Сигнатура:

```luau
ftype:write(fn, <return_type?>, <self_type>, <arg1_type>, <arg2_type>, ...)
```

Правила:

1. **Первый аргумент** — `fn`. Обычно это `function(self, ...) ... end`.
2. **Второй аргумент** — тип возврата. Если функция ничего не возвращает — `mtypes.never`. Если возвращает `Y` — `ftype:opt(mtypes.anyt)` (для `Y?`) или `ftype:var(...)` (для `...`). Тип возврата **обязателен**, даже если это `mtypes.never`.
3. **Третий аргумент** — `private.type` (тип `self`). Для статических методов — тип класса.
4. **Далее** — типы аргументов **по порядку** после `self`. Для variadic-аргумента — `ftype:var(<type>)`.
5. **Логические альтернативы** — через `ftype:uor(...)`.
6. **Конкретные типы** — через `ftype:var(<TypeName>)` или `EnumItem.type`/`EnumObject.type`.
7. **`mtypes.anyt`** — «любой тип», используется когда типизировать не нужно.

Если сигнатура в `ftype:write` не совпадает с реальной сигнатурой функции — это ошибка, которую валидатор должен поймать. Агент **не должен** подгонять типы в `ftype:write` под «что реально приходит», он должен отражать **контракт**.

## 9.7. Инициализатор `:host`

```luau
class:host(function(new)
    const new = new:as <<observer>> (class.type)
    private.shadow_space[new] = {}
    new:set(private.pointers, setmetatable({}, private.meta))
    new:set(private.items, {})
end)
```

- `:host(f)` — замена конструктору. Он вызывается при создании каждого экземпляра (включая сам `class`, если включён `CORE_CLASS_USEABLE`).
- Внутри обязательно:
  1. **Каст `new`** в целевой тип через `new:as<<observer>>(class.type)`. Это даёт корректный `self`-тип дальше.
  2. **Инициализация `shadow_space`** для `new` (если класс использует приватные поля).
  3. **Инициализация `:set(<sentinel>, ...)`** для каждого `newproxy()`-сентинела, чтобы `:get(...)` возвращал валидное значение, а не `nil`.
- `:host` может быть **один**. Перезапись `:host` на уже существующем классе — это «toggle» (см. контракт `luaobject.host`), а не добавление второго инициализатора. Если нужно несколько шагов — они укладываются в одну лямбду.
- `:host` **не** должен вызывать `:finally` или другие хуки жизненного цикла сам — это делает RTTI.

## 9.8. Приватный блок `do ... end`

Всё, что не является частью класса и не должно попасть в публичный контракт, живёт в `do ... end` после `:host`:

1. **Локальные типы** (`type flatted = ...`, `type pointer_internal = ...`) — только для приватных функций.
2. **Инициализация `private.*`**: `private.meta = tables.__mode_ks`, `private.shadow_space = setmetatable({}, private.meta)`, `private.pointers = newproxy()`, `private.items = newproxy()`.
3. **`--#if CORE_CLASS_USEABLE`** — блок инициализации для `class` как экземпляра. Симметричен тому, что делает `:host`, но выполняется один раз при загрузке модуля. **Обязателен**, если класс может быть использован как объект.
4. **Приватные функции** (`private.create_flatted_on`, `private.get_pointers`, `private.call`, ...) — обычные локальные функции, привязанные к `private`.
5. **Диспетчер-таблицы** (`private.relevant_actions`, `private.relevant_pointer_setting`) — `table.freeze({...})` с `enumitem`-ключами.

Правило: **публичные имена — только в `:new`**. Всё остальное — `private` + `do`-блок.

## 9.9. Приватное хранилище

Per-object состояние хранится **не в полях объекта**, а через `self:get(sentinel)` / `self:set(sentinel, value)`. Сентинелы — это `newproxy()`, объявленные один раз на класс.

Паттерн доступа:

```luau
private.get_pointers = function(of: observer): pointers
    return (of:get(private.pointers) or private.dummy) :: any
end
```

- `private.dummy = dummies.table` — общая «пустышка» для случаев, когда `:get` вернул `nil`.
- Каст `:: any` нужен, потому что `:get<Y>` возвращает `Y`, а `Y` зависит от контекста.

**Никогда** не храните приватные данные в `shadow_space` напрямую, если можно обойтись `:get`/`:set` с сентинелом. `shadow_space` — для случаев, когда сентинел-подхода недостаточно (например, для произвольного `label: unknown`).

## 9.10. Диспетчеризация через `relevant_*`

Ключевой паттерн: вместо `if mode == ConnectionVariant.Ever then ... elseif ...` используется **таблица стратегий** с `enumitem`-ключами:

```luau
private.relevant_actions = table.freeze({
    [ConnectionVariant.Ever] = function(related, ...) ... end,
    [ConnectionVariant.Once] = function(related, ...) ... end,
    [ConnectionVariant.Next] = function(related, ...) ... end,
    [ConnectionVariant.Skip] = function(related, ...) ... end,
})
```

Правила:

1. **`table.freeze`** — обязательно. Стратегии не должны меняться в рантайме.
2. **Все ветки покрыты** для всех возможных `enumitem` из контракта. Если появляется новая ветка — она добавляется в **все** релевантные `relevant_*` таблицы, иначе валидатор/контракт разъедется.
3. **`private.relevant_actions[mode]`** вызывается без `self`, потому что стратегия уже знает, с чем работает (через `related`-контекст). Если нужен `self` — передаётся в `related` или аргументах.
4. Аналогично для `private.relevant_pointer_setting` — диспетчер по `enumitem_connection_variant` для смены режима существующих подписок.

Если агенту нужно добавить новое поведение, зависящее от `enumitem`, он **добавляет ветку в существующую `relevant_*`-таблицу**, а не пишет `if/elseif` в основном методе.

## 9.11. Условная компиляция

`--#if <FLAG>` / `--#endif` — директивы препроцессора:

- `CORE_CLASS_USEABLE` — блок инициализации класса как экземпляра.
- `DEBUG` — диагностические ветки (`std:oute(...)`, дополнительные проверки).

Правила:

1. **Директивы не влияют на логику без флага**; если код «работает только с флагом» — это баг.
2. `--#if DEBUG` не должен содержать функционально значимый код; только диагностику.
3. Вложенные `--#if` не приветствуются.
4. Без `--#endif` файл не должен собираться.

## 9.12. Особенности стиля

1. **`const` вместо `local`** — везде, где значение не переприсваивается.
2. **`type(x) == types.function`** — используйте константы из `@declare/types`, а не строковые литералы.
3. **Проверка luaobject-типов** — через `class:that(x, SomeType.type)` или `LuaObject:that(x, SomeType.type)`, **не** через `x.type == "..."` или `typeof(x)`.
4. **`self:as<<T>>(class.type)`** — каст перед использованием типизированного `self`.
5. **`std:check`, `std:assert`, `std:oute`** — стандартные утилиты; не пишите свои `assert`/`error`/`print`, если есть эти.
6. **`table.freeze`** — для всех неизменяемых таблиц-стратегий и констант.
7. **`pcall`** — вокруг любых пользовательских функций (`observer_var`, `ftype`-каллбэков), с `std:assert`/`std:oute` по результату.
8. **`coroutine.isyieldable()`** — перед `scheduler:wait()`/`task.wait()`.
9. **`Scheduler:whose()`** — перед `scheduler:last()`/`scheduler:wait()`; fallback на `task.wait()` только если `scheduler` не найден.
10. **Variadic в `for ... in`** — через `for _, v in { ... } do` (создаёт копию), а не через `for i = 1, select("#", ...)`.
11. **`table.clone`, `table.move`, `table.clear`, `table.find`** — предпочтительны ручным циклам.
12. **`return class`** — единственное, что возвращает модуль. Экспорт типов — только в `core.d.luau`.

## 9.13. Чек-лист построения класса

- [ ] `--!strict` и 4 обязательных `--#include` на месте?
- [ ] Импорты через `@`-алиасы, сгруппированы по слоям?
- [ ] Локальные `type`-алиасы объявлены до `private`?
- [ ] `private.type` совпадает с `:new({ type = ... })`?
- [ ] Все публичные методы обёрнуты в `ftype:write` с **полной** сигнатурой?
- [ ] Типы возврата указаны (включая `mtypes.never`)?
- [ ] `:host` кастует `new:as<<T>>(class.type)` и инициализирует все сентинелы?
- [ ] `private` инициализирован в `do`-блоке до первого использования?
- [ ] `--#if CORE_CLASS_USEABLE` присутствует, если класс может быть использован как экземпляр?
- [ ] Все `relevant_*`-таблицы — `table.freeze` и покрывают все `enumitem` контракта?
- [ ] `pcall` вокруг пользовательских каллбэков?
- [ ] `Scheduler:whose()` + `coroutine.isyieldable()` перед `wait`?
- [ ] `return class` в конце?
- [ ] Нет публичных имён вне `:new`?
- [ ] Нет `if/elseif` по `enumitem` в основных методах, только `relevant_*`?

## 9.14 Пример Enum

```luau
    --!strict

    --#include <project.gpp>
    --#include <build.gpp>
    --#include <fflag_core.gpp>
    --#include <fflag.gpp>

    const EnumItem = require("@class/core/EnumItem")
    const EnumObject = require("@class/core/EnumObject")

    const class: enum_data_notification = EnumObject:new({
        name = script.Name,

        DataStateChanged = EnumItem:new() :: enumitem<any>, -- Тип специально занижен до `enumitem<any>` чтобы избегать ошибок типизации, это не баг, а фича. Тип `enum_*` все равно подстроит что нужно, ему главное чтобы были по структуре `[k]: item`
        DataLoaded = EnumItem:new() :: enumitem<any>,
        DataReleased = EnumItem:new() :: enumitem<any>,
        DataChanged = EnumItem:new() :: enumitem<any>,
        DataMessage = EnumItem:new() :: enumitem<any>,
    })

    return class
```

## 9.15 Пример Struct

```luau
    --!strict
    --!native
    --!optimize 2

    --#include <project.gpp>
    --#include <build.gpp>
    --#include <fflag_core.gpp>
    --#include <fflag.gpp>

    const EnumItem = require("@class/core/EnumItem")
    const Basis = require("@class/struct/geometry/Basis")
    const Directions = require("@class/struct/geometry/Directions")
    const GeoVolume = require("@class/struct/geometry/GeoVolume")
    const Quad = require("@class/struct/geometry/Quad")
    const Triangle = require("@class/struct/geometry/Triangle")
    const types = require("@declare/types")
    const DirectionVariant = require("@enums/descriptor/DirectionVariant")
    const std = require("@extension/std")
    const ftype = require("@static/ftype")

    const tname = "cubevolume"
    const class: cubevolume = (GeoVolume :: geovolume<cubevolume>):new({
        type = tname,

        up = vector.zero,
        bottom = vector.zero,
        left = vector.zero,
        right = vector.zero,
        front = vector.zero,
        back = vector.zero,

        get_corners = ftype:write(function(self: cubevolume): { vector }
            const center: vector = self:get_center()

            return {
                self.right + self.up + self.front - center * 2,
                self.right + self.up + self.back - center * 2,
                self.right + self.bottom + self.front - center * 2,
                self.right + self.bottom + self.back - center * 2,

                self.left + self.up + self.front - center * 2,
                self.left + self.up + self.back - center * 2,
                self.left + self.bottom + self.front - center * 2,
                self.left + self.bottom + self.back - center * 2,
            }
        end, types.table, tname),

        get_direction = ftype:write(function(self: cubevolume, direction: enumitem): vector
            if direction == DirectionVariant.Right then
                return self.right
            elseif direction == DirectionVariant.Left then
                return self.left
            elseif direction == DirectionVariant.Up then
                return self.up
            elseif direction == DirectionVariant.Bottom then
                return self.bottom
            elseif direction == DirectionVariant.Front then
                return self.front
            elseif direction == DirectionVariant.Back then
                return self.back
            end

            

            return --[[#if DEBUG]] std:oute("unsupported DirectionVariant item") or --[[#endif]] vector.zero
        end, types.vector, tname, EnumItem.type),

        get_axises = ftype:write(function(self: cubevolume): directions
            return Directions:new({
                right = self:get_direction(DirectionVariant.Right),
                up = self:get_direction(DirectionVariant.Up),
                front = self:get_direction(DirectionVariant.Front),
            })
        end, Directions.type, tname),

        get_sat_axises = ftype:write(function(self: cubevolume): { vector }
            const axises = self:get_axises()
            const center = self:get_center()
            const result = {}

            result[1] = vector.normalize(axises.right - center)
            result[2] = vector.normalize(axises.up - center)
            result[3] = vector.normalize(axises.front - center)

            return result
        end, types.table, tname),

        get_quad = ftype:write(function(self: cubevolume, direction: enumitem): quad
            if direction == DirectionVariant.Right then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.right + self.up + self.front,
                        self.right + self.up + self.back,
                        self.right + self.bottom + self.front
                    ),
                    left = Triangle:from_vector(
                        self.right + self.up + self.back,
                        self.right + self.bottom + self.back,
                        self.right + self.bottom + self.front
                    ),
                })
            elseif direction == DirectionVariant.Left then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.left + self.up + self.front,
                        self.left + self.bottom + self.front,
                        self.left + self.up + self.back
                    ),
                    left = Triangle:from_vector(
                        self.left + self.up + self.back,
                        self.left + self.bottom + self.front,
                        self.left + self.bottom + self.back
                    ),
                })
            elseif direction == DirectionVariant.Up then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.up + self.right + self.front,
                        self.up + self.front + self.left,
                        self.up + self.right + self.back
                    ),
                    left = Triangle:from_vector(
                        self.up + self.right + self.back,
                        self.up + self.front + self.left,
                        self.up + self.left + self.back
                    ),
                })
            elseif direction == DirectionVariant.Bottom then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.bottom + self.right + self.front,
                        self.bottom + self.right + self.back,
                        self.bottom + self.left + self.front
                    ),
                    left = Triangle:from_vector(
                        self.bottom + self.right + self.back,
                        self.bottom + self.left + self.back,
                        self.bottom + self.left + self.front
                    ),
                })
            elseif direction == DirectionVariant.Front then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.front + self.right + self.up,
                        self.front + self.left + self.up,
                        self.front + self.right + self.bottom
                    ),
                    left = Triangle:from_vector(
                        self.front + self.left + self.up,
                        self.front + self.left + self.bottom,
                        self.front + self.right + self.bottom
                    ),
                })
            elseif direction == DirectionVariant.Back then
                return Quad:new({
                    right = Triangle:from_vector(
                        self.back + self.right + self.up,
                        self.back + self.right + self.bottom,
                        self.back + self.left + self.up
                    ),
                    left = Triangle:from_vector(
                        self.back + self.left + self.up,
                        self.back + self.right + self.bottom,
                        self.back + self.left + self.bottom
                    ),
                })
            end

            return --[[#if DEBUG]] std:oute "unsupported DirectionVariant item" or --[[#endif]] Quad
        end, Quad.type, tname, EnumItem.type),

        to_vector = ftype:write(function(self: cubevolume): vector
            return vector.create(vector.magnitude(self.right), vector.magnitude(self.up), vector.magnitude(self.front))
        end, types.vector, tname),

        to_basis = ftype:write(function(self: cubevolume): basis
            return Basis:new({
                position = self:get_center(),
                rotation = self:get_axises(),
            })
        end, types.vector, tname),

        get_center = ftype:write(function(self: cubevolume): vector
            return (self.up + self.bottom + self.left + self.right + self.front + self.back) / 6
        end, types.vector, tname),
    })

    return class
```

```luau
    --!strict

    --#include <project.gpp>
    --#include <build.gpp>
    --#include <fflag_core.gpp>
    --#include <fflag.gpp>

    const Struct = require("@class/core/Struct")

    const class: abilityinfo = Struct:new({
        type = "abilityinfo",
        has_cooldown = false,
        has_stun = false,
        has_kickback = false,
        has_recoil = false,
        has_slow = false,
        has_self_slow = false,

        cooldown = 0,
        stun = 0,
        recoil = 0,
        kickback = 0,
        slow = 0,

        can_move_on_prepare_time = false,
        can_move_on_action_time = false,
        can_move_on_post_action_time = false,

        prepare_action_time = 0,
        work_action_time = 0,
        post_action_time = 0,
    })


    return class
```

# 10. Что использовать и в каких ситуациях

Раздел описывает, **какой примитив из `core.d.luau` брать в какой задаче**, и почему. Правило общее: если для задачи уже есть тип в `core.d.luau` — используйте его, а не изобретайте своё. Если тип отсутствует — сначала предложите расширение контракта, а не пишите ad-hoc-решение.

## 10.1. Выбор базового типа

| Ситуация | Что брать | Почему |
|---|---|---|
| Нужен любой объект проекта | `luaobject` | Единственный базовый тип, даёт RTTI (`type`, `it`, `is`, `as`, `same`, `eq`, `base`, `iden`, `ttype`) |
| Нужны **данные**, а не поведение | `struct` | Неизменяем, `:clone`/`:each`, без скрытого состояния — предсказуемо |
| Нужен идентификатор (роль, состояние, режим, уведомление) | `enumobject` + `enumitem` | Стабильный `hashlink`, не строка, не Roblox `Enum`; работает с `observer`/`event`/`statemachine` |
| Нужен синглтон-сервис с `name`/`enabled` | `service` | Контракт `nameable & switchable`; сервисы регистрируются и управляются единообразно |
| Нужен ресурс с освобождением | `disposable` | `:free()`, `:released()`, `:watch()` — единый lifecycle |

**Не** наследуйте напрямую от `{...}`, если объект участвует в RTTI, сериализуется, реплицируется или ревьюится. Такие вещи всегда `luaobject` (напрямую или через `struct`/`service`/`disposable`).

## 10.2. Хранение значений и состояние

| Ситуация | Что брать | Почему |
|---|---|---|
| Хранить мутабельное значение и отдавать его наружу по ссылке | `variable<T>` | Ссылочный тип: `:get_value()`/`:set_value()` меняют значение, все видят изменение |
| Хранить значение с подпиской на изменения, но без ссылки | `value<T>` | Уведомляет через `observer<enumitem_operation_variant>`; `:get_value()`/`:set_value()` с `default` |
| LIFO-коллекция с ограничением | `stack<T>` | `:pick()`/`:put()`/`:count()`, `max` — встроен |
| Несколько экземпляров одного класса с параллельным доступом | `quant<T>` | `:get_quantized_class()`/`:set_quantized_class()`, `list_*` операции, уведомления |
| Ленивое кэширование | `maybe<T, U>` | `:extract()`, `:enactment()`, `:erase()`, `:exist()` — не изобретайте `cache[key] = f()` |
| Реестр активных состояний | `statemachine<T>` | `:get_state()`/`:set_state()`/`:blacklist()`, уведомления через `enumitem_statemachine_notification` |

**Не** используйте `value` там, где нужна ссылка (нужен `variable`), и **не** используйте `variable` там, где нужны уведомления (нужен `value` или `observer`). Разница семантическая: `variable` — это «ячейка», `value` — это «источник события + значение».

## 10.3. Индирекция и ссылки

| Ситуация | Что брать | Почему |
|---|---|---|
| Слабая ссылка на «что-то» с управлением | `pointer<T>` | `:get_pointed()`, `:set_point()`, `:is_pointed_exists()`, `:is_pointed_hard()` — используется в `observer` для `unsubscribe` |
| Обёртка над Roblox `Instance` с событиями | `reference<T>` | `:call_function()`, `:call_methode()`, `:read_field()`, `:write_field()`, `:has_field()` + `observer<enumitem_reference_notification>` |
| Путь к `Instance`, когда прямая ссылка нежелательна | `path` | `:get_by_absolute_path()`, `:get_by_relative_path()`, `:get_by_path_or_nil()`, `spoof`-режимы |

**Не** держите `Instance` напрямую, если он может исчезнуть — берите `reference`. **Не** делайте ручной `FindFirstChild`-обход — берите `path`. **Не** заменяйте `pointer` обычной таблицей-контейнером: `pointer` умеет `is_pointed_exists`, `pointer` — weak-совместим.

## 10.4. Уведомления и подписки

| Ситуация | Что брать | Почему |
|---|---|---|
| Внутренняя шина с тонким контролем | `observer<T>` | Базовый `:subscribe()`/`:unsubscribe()`/`:notificate()`; `deferred_call`, `deferred_mode`, `allow_new_connections` |
| Пользовательский «ивент» с `connect`/`once`/`wait`/`invoke` | `event<T, U...>` | Удобный API поверх `observer`, `:wait()` — блокирующий, `:invoke()`/`:invoke_deferred()` |
| Handle подписки, отписка вручную | `connection<T, U...>` | `:disconnect()`, `:set_mode()`, `:is_connected()`, `:get_mode()` |
| Обёртка над Roblox `RBXScriptSignal` | `signal<T...>` | `:get_signal_event()`, `:set_signal_source()`, `:apply_as_source()`, `use_parallel_signals` |
| Автопривязка классов к `Instance` по тегу | `binder<T>` | `:start()`/`:stop()`, `ancestors`, `maker`; уведомления `BinderNotification.Bound`/`Unbound` |

**Не** пишите свой `signal`-подобный механизм: `observer`/`event` уже покрывают 95% случаев. **Не** подписывайтесь напрямую на `RBXScriptSignal` в ядре — оборачивайте в `signal`.

## 10.5. Жизненный цикл, время, планирование

| Ситуация | Что брать | Почему |
|---|---|---|
| Один освобождаемый ресурс | `disposable` | `:free()`, `:released()`, `:watch()` — единая точка освобождения |
| Набор освобождаемых ресурсов | `maid` | `:add_object()`, `:add_key()`, `:remove_object()`, `:remove_key()`, `:is_supported()`; сам `maid` — `disposable` |
| Управление «запуском» | `controller` | `:continue()`, `:pause()`, `:reset()` + `enumitem_controller_state` |
| Таймер с шагом | `timer` | `:get_elapsed()`, `:get_remaining()`, `:set_duration()`, `:set_step()` + `enumitem_tick_notification` |
| Запланированная корутина | `scheduler` | `:plan()`, `:cancel()`, `:wait()`, `:hold()`, `:last()`, `:next()`, `:process()` |

**Не** используйте `task.wait`/`task.spawn`, если класс уже реализует `scheduler` — они конфликтуют. **Не** держите ссылку на ресурс без `disposable`/`maid`, если ресурс требует освобождения.

## 10.6. Сеть

| Ситуация | Что брать | Почему |
|---|---|---|
| Транспорт клиент↔сервер | `sharednet` + `netpack` | `:get_event()`, `:emit_event()`; `netpack:pack()`, `:payload()`, `:get_flat()`, `:get_players()`, `:get_source()`, `:is_me_sender()` |
| Данные игрока (сервер) | `dataserver` | `:start()`, `:get_data()`, `:wait_data()`, `:get_value()`, `:set_value()`, `:update_value()`, `:reset()`, `:send_message()`, `:get_data_event()` |
| Данные игрока (клиент) | `dataclient` | `:start()`, `:get_state()`, `:get_value()`, `:wait_loaded()`, `:get_data_event()` |
| RPC на другую машину | `remotecall` | Единая точка удалённого вызова |

**Не** шлите пакеты вручную через `RemoteEvent` — используйте `sharednet`. **Не** пишите с клиента в `dataserver` — только `dataclient` (read-only). **Не** используйте `dataserver:set_value` для реплицируемых ключей в обход `update_value` — иначе репликация разъедется.

## 10.7. Геометрия

| Ситуация | Что брать | Почему |
|---|---|---|
| Ориентация + позиция в пространстве | `basis` | `:basis_to_world/local`, `:point_to_world/local`, `:slerp`, `:inverse_basis`, `:get_components`/`:from_components` |
| Axis-aligned box | `aabbvolume` | `min`/`max`, `half`, `:is_inside`, `:is_intersection`, `:look_at` |
| Ориентированный box | `obbvolume` | То же + `:rotate_radian`, `:get_rotation_radian` |
| Кубическая область | `cubevolume` | `:up/:bottom/:left/:right/:front/:back`, `:get_corners`, `:get_axises`, `:get_quad`, `:get_sat_axises` |
| Полигон / фейс | `triangle`, `quad` | `:from_vector`, `:get_normal_geometric`, `:get_normal_interpolated` |
| Упорядоченные оси | `directions` | `axisable` + `vector_operations` |

**Не** считайте ориентацию руками через `CFrame` — берите `basis`. **Не** пишите ручные SAT-проверки — берите `geometry_check` из соответствующего объёма. Новые объёмы (`spherevolume`, `capsulevolume`, `conevolume`, `tetavolume`) пока закомментированы в `core.d.luau` — **не** реализуйте их без явного запроса и обновления контракта.

## 10.8. Игровые сущности

| Ситуация | Что брать | Почему |
|---|---|---|
| Домен игры: раунд, фракции | `round`, `faction` | `:get_members()`, `:add_member()`, `:rem_member()`, `:is_member()`; `round` — `timer` + `stateable` |
| Логическая сущность «персонаж» | `character` | `:get_token()`, `:get_parameter()`, `:has_parameter()`, `:get_abilities()`, `:get_inventory()`, `:get_model_reference()`; `informable<characterinfo>` |
| Способность | `ability` + `abilityinfo` | `:activate()`, `:cooldown()`; `abilityinfo` — пакет баланса (`has_*`, `cooldown`, `stun`, `recoil`, `kickback`, `slow`, `*_time`) |
| Инвентарь | `inventory` + `itemstack` + `itemobject` | `inventory` — `max` + `list_*` + `:get_stacks()`; `itemstack`/`itemobject` — варианты «стак» и «уникальный» |
| Описание предмета | `item` | Синглтон: `max`, `count`, `description`, `behavior`, `:get_stack()` |
| Поведение предмета | `itembehavior` + `itemcontext` | `:on_equip`, `:on_unequip`, `:on_take`, `:on_drop`, `:action` |
| Профиль игрока | `profile<T>` | `:get_player()`, `:get_joined_at()`, `:get_last_seen_at()`, `:get_permissions()`, `:get_restrictions()`, `:has_platform()`, `:is_banned()`, `:is_kicked()` |

**Не** заменяйте `character` прямым `Humanoid` в игровой логике — `character` не зависит от способа управления. **Не** храните предметы прямо в `inventory`: только `itemstack`/`itemobject`. **Не** пишите поведения предметов вне `itembehavior` — иначе `:action` не увидит `itemcontext`.

## 10.9. IK

| Ситуация | Что брать | Почему |
|---|---|---|
| Решатель R6 | `ikr6legs`, `ikr6arms`, `ikr6heads` | Автоматизированные решатели; каждый `initiable` и управляет своими `ikr6limb` |
| Одна конечность | `ikr6limb`, `ikr6foot`, `ikr6arm`, `ikr6head` | `:get_fake()`, `:get_limb_target()`, `:get_limb_pole()`, `:get_limb_facing()`, `:is_moving_finished()` |
| Конфигурация решателя | `ikr6info`, `ikr6leginfo`, `ikr6arminfo`, `ikr6limbinfo` | Пакеты настройки; используются через `informable` |

**Не** пишите свой IK — берите `ikr6*`. **Не** храните настройки решателя в полях — используйте `*info` через `informable`. IK-классы помечены как «поддержка не гарантируется» (R6) — правки требуют согласования.

## 10.10. Возврат значений

| Ситуация | Что брать | Почему |
|---|---|---|
| Функция возвращает «успех/результат» | `result<T, U...>` | `:state`, `:result`, `:unpack` — вместо `(boolean, T?)` |
| Сетевой пакет на проводе | `netpack` / `netpack_flat` | `netpack:get_flat()` — wire-формат, `netpack_flat` — плоская таблица |

**Не** возвращайте `(boolean, string | nil)` из публичных API — берите `result`. **Не** сериализуйте `netpack` вручную — используйте `:get_flat()`/`:from_flat()`.

## 10.11. Интерфейсы-миксины

Использовать по назначению, не «на всякий случай»:

| Интерфейс | Когда |
|---|---|
| `nameable` | Объект имеет имя (сервис, фракция, предмет) |
| `switchable` | Объект можно вкл/выкл (`enabled`) |
| `operatable` | Нужны `continue`/`pause`/`reset` |
| `controllable` | У объекта есть `controller` (`:get_control()`) |
| `instanceable` | Объект связан с одним Roblox `Instance` |
| `referenceable` | Объект связан с `reference` (`:get_reference()`) |
| `disposable` | Объект освобождает ресурсы |
| `private_storage` | Нужны `:get`/`:set` по `label` |
| `invokeable` | Объект вызываем (`:invoke`) |
| `asyncable` | Объект делает сетевые/асинхронные попытки (`time_to_hold`, `time_to_response`, `attempts`) |
| `stateable<T, U>` | Объект имеет автомат состояний (`:get_states()`) |
| `informable<T, U>` | Объект имеет пакет `*info` (`:get_info()`/`:set_info()`) |
| `initiable` | Объект имеет фазу инициализации (`:is_initiated()`) |
| `loopable` | Объект имеет цикл (`:get_loop()`) |
| `reloadable` | Объект можно перезарядить (`:reload()`) |
| `modifier<T>` | Объект имеет модификатор |
| `iterations<T>` | Объект итерируется |
| `list_checks` | Объект — коллекция; нужны `is_full`/`is_empty`/`is_half` |
| `list_operations<T, U...>` | Объект — коллекция; нужны `clear`/`count`/`length`/`adjust`/`insert`/`remove`/`collect`/`find` |
| `math_operations` | Объект — число-подобный (`multiple`, `divide`, `lerp`, `fuzzy_eq`, ...) |
| `vector_operations` | Объект конвертируется в `basis`/`vector` |
| `positioned`, `rotateable`, `centerable`, `normal`, `normals`, `axisable` | Геометрические гарантии |
| `geometry_check`, `geometry_control`, `geometry_rotatable`, `geometry_convertation`, `geometry_half` | Геометрические операции |
| `I_targetable<T, U>` | У объекта есть цель (`:set_target()`/`:get_target()`) |
| `expected_calltype<T>` | Подписка знает свой ожидаемый тип |
| `loopable`/`iterations`/`modifier`/`reloadable` | Только если контракт реально нужен, не «чтобы было» |

**Не** подмешивайте интерфейсы «для полноты»: каждый добавляет поля/методы, которые придётся реализовывать и ревьюить. Берите ровно тот набор, который описывает поведение объекта.

## 10.12. Уведомления `enum_*_notification`

Выбор уведомления = выбор того, на что объект реагирует. Используйте существующие:

- `enum_setup_notification` — фазы установки/подключения (`Install`, `Installed`, `Require`, `Disconnected`).
- `enum_tick_notification` — жизненный цикл таймера (`Started`, `Stepped`, `Paused`, `Resumed`, `Finished`).
- `enum_operation_variant` — `New`/`Change`/`Remove`.
- `enum_reference_notification` — `NewInstance`/`ChangedInstance`/`DestroyedInstance`/`NullifiedInstance`.
- `enum_binder_notification` — `Bound`/`Unbound`.
- `enum_net_notification` — `Received`.
- `enum_data_notification` — `DataStateChanged`/`DataLoaded`/`DataReleased`/`DataChanged`/`DataMessage`.
- `enum_shared_net_variant` — `Unsafe`/`Safe`/`Internal`.
- `enum_net_source` — `FromServer`/`FromMe`/`FromClient`.
- `enum_controller_state`, `enum_round_state`, `enum_state`, `enum_data_state`, `enum_iklegs_state` — состояния.
- `enum_item_context` — `Primary`/`Secondary`/`Cycle`/`Special` (для `itemcontext`).
- `enum_character_parameter_variant` — параметры персонажа.
- `enum_action_map_variant` — действия для будущего `InputMap`.
- `enum_statemachine_notification` — `ChangedState`/`NewState`/`BlacklistAdded`/`BlacklistRemoved`.
- `enum_disposable_notification` — `OnRelease`/`Released`.
- `enum_faction_notification` — `MemberJoined`/`MemberRemoved`.
- `enum_ability_notification` — фазы способности.
- `enum_user_notification` — события профиля (`ServerJoin`/`ServerExit`/`ServerBan`/`ServerKick`/`ServerDataRequest`).
- `enum_direction_variant`, `enum_collision_variant`, `enum_asset_type_variant`, `enum_physx_mode_variant`, `enum_internal_channel_variant` — доменные варианты.

**Не** вводите новое уведомление, если существующего достаточно. Если новое действительно нужно — оно добавляется в `src/enums/notification/**` и в `core.d.luau`, иначе валидатор его не увидит.

## 10.13. Сводное правило выбора

1. **Сначала ищите готовый тип** в `core.d.luau`. 90% задач уже покрыто.
2. **Если тип есть, но не подходит по семантике** — рассмотрите соседний (`variable` vs `value`, `pointer` vs `reference`, `event` vs `signal`, `aabb` vs `obb`).
3. **Если типа нет** — сначала предложите расширение `core.d.luau` (плюс `src/static/**` и, если надо, `src/enums/**`), затем реализацию.
4. **Не смешивайте слои:** `struct` для данных, `service` для синглтонов, `disposable` для ресурсов, `observer` для уведомлений.
5. **Не дублируйте:** если в проекте уже есть `scheduler`, `signal`, `maid`, `pointer`, `observer`, `sharednet`, `dataserver` — используйте их, даже если «своё» кажется проще.
6. **Согласуйте**, если задача требует тронуть чужой участок по `CODEOWNERS`, реализовать закомментированный в контракте тип или изменить публичный API.