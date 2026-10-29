# Платформенно-независимый типизационный слой

Этот документ описывает `src/core.independent.d.luau` — копию `src/core.d.luau`, в которой
типизационный слой больше не зависит от Roblox. Оригинал не изменялся.

## 1. Что было не так

`core.d.luau` использовал глобальные типы Roblox прямо в публичных контрактах:

| Было | Где | Стало |
| --- | --- | --- |
| `Humanoid` | `ikr6solver:get_humanoid` | `host_humanoid` (generic-параметр `THumanoid`) |
| `BasePart` | `ikr6solver:get_torso`, `ikr6limb:get_fake`, `referenceable` | `host_part` (generic-параметр `TPart`) |
| `Model`, `BasePart`, `PVInstance` | `geometry_supported` | `host_model`, `host_part`, `host_pvinstance` (generic-параметры) |
| `shell` (несуществующий тип) | методы `reference<T>` | `reference<T>` |

Проверка `luau-analyze` на оригинале даёт 12 ошибок `Unknown type`; на копии — 0.

Кроме типов, в комментариях были жёсткие привязки к Roblox (`ReplicatedStorage`, `RemoteEvent`,
`ProfileStore`, `workspace`, «роблоксовский экземпляр»). Они заменены на платформенно-нейтральные
описания. Упоминания Roblox остались только там, где это примеры в документации самого контракта.

## 2. Слои

```
┌─────────────────────────────────────────────────────────────┐
│  Игровой код                                                │
│  знает свои доменные типы и, при необходимости, профиль хоста│
└───────────────────────────┬─────────────────────────────────┘
                            │ требует зависимости / типы
┌───────────────────────────▼─────────────────────────────────┐
│  core.independent.d.luau                                    │
│  luaobject, scheduler, observer, event, provider, container  │
│  host_* — абстрактные роли платформы, без имён движка        │
└───────────────────────────┬─────────────────────────────────┘
                            │ реализует
┌───────────────────────────▼─────────────────────────────────┐
│  providers/bin/<platform>/                                  │
│  provider.luau — композиционный корень                      │
│  host.luau     — профиль типов платформы                    │
│  engine/instance/network/... — нативные адаптеры             │
└─────────────────────────────────────────────────────────────┘
```

Ключевое правило: **платформа упоминается только в `providers/bin/<platform>/` и в
`providers/platform.luau`**, который выбирает бинарь на этапе сборки. Ядро и игровые объекты
не должны делать `require("@platform/roblox/...")`.

## 3. Типовой уровень: как подставляются типы платформы

### 3.1. Абстрактные роли

В начале `core.independent.d.luau` объявлены роли:

```luau
export type native_host_object = unknown
export type host_object = native_host_object
export type host_instance = any
export type host_player = any
export type host_humanoid = any
export type host_part = any
export type host_model = any
export type host_pvinstance = any
export type host_geometry = never
```

Почему дефолты именно такие:

* `any` для `host_instance`/`host_player`/`host_humanoid`/`host_part`/`host_model` — ядро не знает
  природу нативного объекта. При этом `reference<T>` инвариантен по `T` из-за `set_instance(to: T)`,
  поэтому `reference<unknown>` несовместим с `reference<Humanoid>`, а `reference<any>` — совместим.
  Это сохраняет работоспособность неспециализированного кода.
* `never` для `host_geometry` — потому что `T | any` схлопывается в `any`. Если бы
  `geometry_supported` по умолчанию содержал `any`, объединение потеряло бы `geometry_volume`.
  `never` нейтрален для объединения: без профиля `geometry_supported == geometry_volume`.

`vector` намеренно не абстрагируется: это стандартный тип Luau, а не тип Roblox.

### 3.2. Профиль хоста

Профиль — обычный `.luau`-модуль, который экспортирует типы. Пример:
`src/providers/bin/roblox/host.luau`.

```luau
-- providers/bin/roblox/host.luau
export type vec = vector
export type node = Instance
export type player = Player
export type humanoid = Humanoid
export type part = BasePart
export type model = Model
export type pvinstance = PVInstance

return table.freeze({})
```

Ядро не импортирует профиль. Профиль импортирует тот, кому нужна точность:

```luau
local Host = require("@providers/bin/roblox/host")

type solver = ikr6solver<Host.humanoid, Host.part>
type limb = ikr6limb<enumitem_iklegs_state, ikr6leginfo, Host.part>
type native_geometry = geometry_supported<Host.model, Host.part, Host.pvinstance>
type player_binder = binder<reference<Host.player>, Host.node>
```

Почему не другие варианты:

* **`require` внутри `core.d.luau`** — файл перестаёт быть самодостаточным ambient-определением:
  каждый потребитель обязан настроить тот же алиас (`@host/...`) у себя в luau-lsp.
* **`--#if PLATFORM` внутри `.d.luau`** — gpp-условия будут обработаны только сборкой, а
  luau-lsp читает `.d.luau` напрямую и увидит оба бранча сразу (дубли типов).
* **`unknown` в объединении `geometry_supported`** — схлопывает объединение.
* **`require` профиля в каждом игровом модуле** — допустимо, но лучше один раз определить
  алиасы в игровом `game.d.luau` (см. раздел 7).

### 3.3. Где именно появились generic-параметры

```luau
export type ikr6solver<THumanoid = host_humanoid, TPart = host_part> = ...
export type ikr6limb<T = enumitem, U = ikr6limbinfo, TPart = host_part> = ...
export type geometry_supported<TModel = host_geometry, TPart = host_geometry, TPVInstance = host_geometry> = ...
export type reference<T = host_instance> = ...
export type referenceable<T = unknown, U = host_instance> = ...
export type binder<T = unknown, TInstance = host_instance> = ...
export type binder_maker<T = unknown, TInstance = host_instance> = ...
export type profile<T = enumitem, TPlayer = host_player> = ...
export type localuser<TPlayer = host_player> = ...
export type dataserver<TPlayer = host_player> = ...
```

Всё остальное (`netpack`, `collision`, `character`, `provider` и т.д.) использует
`host_instance`, `host_player` или `native_host_object` — этих типов достаточно, потому что
ядро не вызывает у них нативных методов.

## 4. Рантайм-уровень: зависимости и их разрешение

Типовой профиль отвечает на вопрос «какого типа нативный объект». Контейнер зависимостей
отвечает на вопрос «откуда объект получает сервисы и как они разрешаются».

### 4.1. Ключ зависимости

```luau
export type dependency<T = unknown> = extend<{
    read name: string,
    read optional: boolean,
    read lifetime: enumitem_dependency_lifetime,
}, struct>
```

Ключ — это объект-слот, а не строка. Тип `T` связывает слот со значением, поэтому
`container:resolve(Dependencies.World)` возвращает `world`, а не `unknown`.

Ключи создаются один раз на модуль:

```luau
-- dependencies.luau
local Dependencies = {}

Dependencies.Scheduler = Dependency:new({ name = "scheduler" })
Dependencies.Raycast = Dependency:new({ name = "raycast" })
Dependencies.World = Dependency:new({ name = "world", optional = true })

return table.freeze(Dependencies)
```

### 4.2. Объект с зависимостями

```luau
export type dependable<T = unknown> = {
    read get_dependencies: (self: T) -> { dependency },
    read set_dependency: <U>(self: T, on: dependency<U>, value: U) -> (),
}
```

Объект сам решает, куда положить значение, и может его провалидировать. Контейнер не пишет
в поля напрямую и не знает структуру объекта.

Объекту, которому нужны платформенные возможности, а не одно значение, дополнительно
передаётся провайдер:

```luau
export type provider_aware<T = unknown> = {
    read get_provider: (self: T) -> provider,
    read set_provider: (self: T, to: provider) -> (),
}
```

### 4.3. Контейнер

```luau
export type container = {
    read provide: <T>(self: container, on: dependency<T>, make: (from: container) -> T,
        lifetime: enumitem_dependency_lifetime?) -> container,
    read bind: <T>(self: container, on: dependency<T>, value: T) -> container,
    read resolve: <T>(self: container, on: dependency<T>) -> T,
    read try_resolve: <T>(self: container, on: dependency<T>) -> T?,
    read has: (self: container, on: dependency) -> boolean,
    read inject: <T>(self: container, target: T & dependable) -> T & dependable,
    read scope: (self: container) -> container,
    read close: (self: container) -> (),
}
```

Времена жизни (`enumitem_dependency_lifetime`):

| Значение | Смысл |
| --- | --- |
| `Singleton` | одно значение на всё дерево провайдеров, кэшируется в корне |
| `Scoped` | одно значение на каждый scope, который его запросил |
| `Transient` | новое значение на каждый `resolve` |

### 4.4. Алгоритм разрешения (эскиз реализации)

```luau
function Container:resolve(dep)
    local scope = self

    while scope do
        local record = scope.registry[dep]

        if record then
            if record.state == "resolving" then
                error(`dependency cycle: {table.concat(scope.stack, " -> ")} -> {dep.name}`)
            end

            if record.lifetime == Lifetime.Singleton then
                scope = record.root
            end

            if record.value ~= nil and record.lifetime ~= Lifetime.Transient then
                return record.value
            end

            record.state = "resolving"
            table.insert(scope.stack, dep.name)

            local value = record.make(scope)

            record.state = "ready"
            table.remove(scope.stack)

            if record.lifetime ~= Lifetime.Transient then
                record.value = value
                if value and value.free then table.insert(scope.disposables, value) end
            end

            return value
        end

        scope = scope.parent
    end

    if dep.optional then
        return nil
    end

    error(`dependency not registered: {dep.name}`)
end

function Container:inject(target)
    for _, dep in target:get_dependencies() do
        target:set_dependency(dep, self:resolve(dep))
    end

    if target.set_provider then
        target:set_provider(self)
    end

    return target
end
```

Это эскиз, а не готовый класс: он показывает порядок и инварианты. Реализация
(`src/class/struct/Provider.luau`) должна добавить:

* наследование scope-ов (`parent`);
* кэш синглтонов в корне;
* стек разрешения для сообщений о циклах;
* освобождение `disposable`-значений в обратном порядке в `close()`;
* защиту от повторной регистрации слота (или явную перезапись через `bind`).

### 4.5. Провайдер платформы

`provider` — это `container` плюс фасад нативных возможностей:

```luau
export type provider = extend<
    { ...рейкаст, время, каналы, теги, атрибуты, жизненный цикл кадра... } & container,
    struct
>
```

Провайдер — единственный композиционный корень. Платформенный бинарь создаёт его и
регистрирует всё, что нужно игре:

```luau
local Provider = Container:new {
    name = "roblox",
    is_server = RunService:IsServer(),
    is_client = RunService:IsClient(),
    ...
}

Provider:bind(Dependencies.Scheduler, Scheduler:new())
Provider:bind(Dependencies.Raycast, Raycast:new { ... })
Provider:provide(Dependencies.World, function(from)
    return World:new { raycast = from:resolve(Dependencies.Raycast) }
end)
```

Игровой объект:

```luau
local Solver = LuaObject:new {
    get_dependencies = function(self)
        return { Dependencies.World, Dependencies.Scheduler }
    end,

    set_dependency = function(self, on, value)
        if on == Dependencies.World then
            self.world = value
        elseif on == Dependencies.Scheduler then
            self.scheduler = value
        end
    end,
}

local solver = Solver:new()
provider:inject(solver)
```

Встраивание в жизненный цикл `luaobject`: `inject` вызывается в `host`-фазе (после
`new`, до `finally`). Тогда зависимости доступны финализатору, а `close()` провайдера
освобождает их в обратном порядке.

### 4.6. Что считать зависимостью

Зависимость — это **возможность**, а не платформенный класс:

* `World` (рейкаст/оверлап), а не `workspace`;
* `Scheduler`, а не `task`;
* `NetworkChannel`, а не `RemoteEvent`;
* `NodeFactory`/`NodeStore`, а не `Instance.new`;
* `PlayerDirectory`, а не `Players`;
* `DataStore`, а не `ProfileStore`.

Такая формулировка позволяет реализовать один и тот же игровой код на Roblox, love2d,
Defold или в headless-тесте.

## 5. Как это ложится на текущее дерево

В репозитории уже есть заготовка:

* `src/providers/platform.luau` — выбирает бинарь по `--[[#PLATFORM]]`;
* `src/providers/bin/roblox/*` — нативные адаптеры;
* `src/providers/bin/shared/*` — заглушка для платформ без нативных адаптеров;
* `src/class/struct/Provider.luau` — пустой класс, который должен реализовать `provider`.

Важно: после переименования `src/platform` → `src/providers` часть кода всё ещё делает
`require("@platform/roblox/...")`, а алиас в `src/config.luaurc` уже называется `providers`.
Это нужно привести к одному виду (`@providers/bin/roblox/...`) независимо от того, будет ли
принят этот документ.

Рекомендуемый порядок миграции:

1. Реализовать `Container`/`Provider` в `src/class/struct/Provider.luau`.
2. Заполнить `providers/bin/<platform>/provider.luau` регистрацией возможностей.
3. Перевести на зависимости самые «платформенные» классы:
   * `class/common/Reference.luau`, `gc/Maid.luau`, `common/Binder.luau` — узлы, теги, уничтожение;
   * `class/game/character/ik/r6/*` — `World`, `NodeFactory`, `Humanoid`;
   * `class/service/SharedNet.luau` — `NetworkChannel`;
   * `class/service/DataServer.luau` — `DataStore`, `PlayerDirectory`;
   * `settings/*` — конфигурация, а не `@platform/roblox/engine`.
4. Удалить из игровых классов прямые `require("@platform/...")` и `typeof(x) == "Instance"`.
5. Только после этого подключать `core.independent.d.luau` вместо `core.d.luau`.

## 6. Чеклист новой платформы

1. Создать `src/providers/bin/<platform>/host.luau` с типами `node`, `player`, `humanoid`,
   `part`, `model`, `pvinstance` (или их нейтральными аналогами).
2. Создать `src/providers/bin/<platform>/provider.luau`, который создаёт провайдер и
   регистрирует базовые возможности.
3. Реализовать адаптеры для scheduler, времени, рейкаста, каналов, тегов/атрибутов,
   жизненного цикла кадра.
4. Убедиться, что ни один файл вне `providers/bin/<platform>/` не содержит имён классов
   платформы в типах.
5. Прогнать `luau-analyze` по ядру: ошибок `Unknown type` быть не должно.
6. Прогнать тесты с `PLATFORM="<platform>"`.

## 7. Ограничения и следующие шаги

* В `core.d.luau` по-прежнему лежат игровые типы (`round`, `faction`, `character`,
  `inventory`, `item*`, `ikr6*`). Для полной чистоты их стоит вынести в `game.d.luau`
  (или в несколько профильных файлов), а в core оставить только `luaobject`, `observer`,
  `scheduler`, `event`, `container`, `provider` и общие интерфейсы.
* `provider` пока содержит платформенные методы (`do_raycast`, `toggle_tag` и т.д.).
  Это допустимо как фасад, но игровому коду лучше зависеть от узких возможностей
  (`raycastable`, `tagged`, `networked`), а не от всего провайдера.
* `host_instance = any` — сознательный компромисс ради совместимости. Для строгого режима
  можно заменить дефолты на `never` (или на номинальный `host_opaque`) и требовать
  специализации во всех игровых модулях.
* `vector` — стандартный тип Luau; если платформа собирает Luau без vector-библиотеки,
  нужно добавить `host_vector` и прогнать его через generic-параметры геометрии.
