# Проверочная сборка funny-core как пакета

`build/build_test.py` собирает **готовый к установке** пакет ядра и проверяет его
так, как это сделал бы внешний потребитель:

1. `gpp` раскрывает `--#if` / `--#define` / `--#include` в `src/**`.
2. `darklua` заменяет внутренние `require("@class/...")`, `@declare`, `@enums`,
   `@static`, `@import`, `@include` на относительные пути.
3. Пакет публикуется в **локальный** crater-registry (`build/dev/registry`), без
   GitHub и без публичного реестра.
4. `crater install` ставит пакет в отдельный проект `build/dev/consumer` как
   обычную зависимость.
5. `rojo build` собирает `build/dev/consumer/build.rbxl` (если установлен rojo).

Это не релизная публикация. Релизная сборка и публикация описаны в
[BUILD.md](./BUILD.md).

---

## 1. Быстрый старт

Из корня репозитория:

```bash
crater install -y
python3 build/build_test.py
```

Скрипт сам найдёт `gpp`, `darklua` и `crater` в `PATH`. `rojo` нужен только для
финального `.rbxl`; без него используй `--no-place`.

Полезные флаги:

```bash
python3 build/build_test.py --no-place          # без rojo build
python3 build/build_test.py --keep              # не удалять build/dev/registry
python3 build/build_test.py --version 0.0.1-dev.1
```

По умолчанию версия тестового пакета — `0.0.1-dev.<unix timestamp>`, чтобы
повторные запуски не конфликтовали в локальном registry.

---

## 2. Что создаётся

Все пакетные зависимости crater ставит в `src/vendor` (`vendor` в
`crater.settings.json`): `import/` — общие (реалм `client`), `include/` —
серверные (реалм `server`). Дев-пакет несёт эту папку внутри себя, поэтому
потребителю не нужно ничего доустанавливать.

```text
build/dev/
├── registry/                 # локальный crater-registry
│   ├── packages.json
│   └── funnydevz/funny-core/
│       ├── index.json
│       ├── 0.0.1-dev.<...>.zip
│       └── source/
├── work/
│   └── root/
│       └── Packages/
│           └── funny-core/   # собранный пакет (gpp + darklua)
│               └── src/
│                   ├── class/ enums/ extension/ platform/ static/ templates/
│                   └── vendor/    # import/ и include/ из src/vendor
└── consumer/                 # тестовый проект-потребитель
    ├── crater.json
    ├── crater.settings.json
    ├── default.project.json
    ├── .luaurc
    ├── client/Smoke.client.luau
    ├── server/Smoke.server.luau
    ├── Packages/             # создаёт crater install
    │   └── funny-core/
    └── build.rbxl            # если был rojo
```

`build/dev/` — генерируемый каталог, его не нужно коммитить.

---

## 3. Как работает `build_test.py`

### 3.1. GPP-препроцессинг

Скрипт повторяет логику `build/build.py`:

- читает `src/project.gpp` и `src/build.gpp` как общий заголовок;
- обрабатывает каждый `src/**/*.luau`, кроме `src/temp/**` и `src/vendor/**`;
- пропускает `.d.luau`, `.gpp`, `*.project.json`, `.darklua.json`, `*.md`;
- удаляет неактивные ветки `--#if` и подставляет `--#define`.

`core.d.luau` не является исполняемым модулем, поэтому копируется после darklua.
`src/vendor/**` копируется как есть: это уже собранные пакеты crater.

### 3.2. Darklua

Пакет собирается сразу в «потребительской» раскладке: `src/vendor` лежит внутри
`funny-core/src`, поэтому алиасы совпадают с `src/config.luaurc`.

В `funny-core/src/.luaurc` временно записываются алиасы:

| Алиас | Куда указывает |
| --- | --- |
| `class`, `enums`, `static`, `extension`, `platform`, `project`, `declare`, `templates` | внутрь `funny-core/src` |
| `import` | `funny-core/src/vendor/import` |
| `include` | `funny-core/src/vendor/include` |

Поэтому `require("@import/Quat")` превращается в
`require("../../vendor/import/Quat")`, а `require("@include/ProfileStore")`
— в `require("../../vendor/include/ProfileStore")`. Это ровно те пути, которые
будут у потребителя внутри `Packages/funny-core/src`.

Правило `src/build_info.darklua.json` содержит `skip_files: ["**/vendor/**"]`,
поэтому содержимое `vendor` не переписывается.

После обработки скрипт проверяет, что в модулях ядра (без `vendor`) не осталось
`require("@...")`, строк `--#...` и временных маркеров, и удаляет `.luaurc`.

#### Обход потери `<<T>>` в darklua

`darklua 0.19.0` пересобирает код из собственного AST и **молча выбрасывает**
явную инстанциацию дженериков `f <<T>>(x)` — при этом сам Luau такой синтаксис
поддерживает. Проверяется даже на пустом списке правил:

```lua
local x = self:get <<number>> (1)   -- после darklua
local x = self:get (1)              -- `<<number>>` потерян
```

Чтобы типы не терялись, общий модуль `build/darklua_safe.py` (его используют и
`build_test.py`, и релизный `build/build.py`, и `build/prepack.py`):

1. маскирует каждую инстанциацию комментарием
   `--[[__CORE_TYPEINST_<n>__]]` (сканирование учитывает строки, обычные и
   длинные комментарии, поэтому `<<` внутри строк и комментариев не трогается);
2. запускает darklua с `--format retain_lines` — дефолтный формат удаляет
   комментарии и вместе с ними маски;
3. возвращает оригинальный `<<T>>` на место и проверяет, что число найденных
   масок совпадает с исходным, иначе сборка падает.

Побочный эффект: пакет сохраняет комментарии и исходное форматирование
(`retain_lines`), а не переформатируется darklua. Это ожидаемо.

### 3.3. Локальная публикация

В `crater.json` собранного пакета записывается:

```json
"registry": "<абсолютный путь к build/dev/registry>",
"path_to_main": "",
"path_to_definition_files": ["./src/core.d.luau"]
```

`path_to_main` пуст намеренно: ядро — библиотека классов, а не игра. У пакета
нет `init.luau`, поэтому crater предупреждает:

```text
! No main module and no modules to expose...
```

Это ожидаемо. Потребитель требует модули по путям (см. раздел 5).

### 3.4. Установка в `consumer`

`build/dev/consumer/crater.json` содержит зависимость:

```json
"import_client": ["funny-core:funnydevz/funny-core@0.0.1-dev.<...>"]
```

и `registry`, указывающий на локальную папку. Список зависимостей пуст: все
пакеты (`Quat`, `SAT`, `Cryptography`, `BufferedArrays`, `LINQ`, `crate`,
`BitMap`, `ProfileStore`) лежат внутри пакета в `src/vendor` и не ставятся
отдельно.

`crater.settings.json` потребителя записывается по схеме crater 0.7.5:
`vscode_definitions: true`, `darklua: false`, `sync: "auto"` и
`link_style: "roblox"`. `vscode_definitions: true` обязателен: у пакета есть
`path_to_definition_files`, и crater иначе предупреждает, что типы не доходят до
luau-lsp. `darklua: false` выключён намеренно — в собранном пакете не осталось
`@alias`-require, все пути относительные.

---

## 4. Запуск и проверка

### 4.1. Через Rojo

```bash
rojo serve build/dev/consumer/default.project.json
```

Либо открой `build/dev/consumer/build.rbxl` в Studio.

В проекте есть два smoke-скрипта:

- `client/Smoke.client.luau` — требует `LuaObject`, `Observer`, `EnumObject` и
  `Basis` (последний тянет `Quat`);
- `server/Smoke.server.luau` — требует `DataServer` (тянет
  `@include/ProfileStore`).

В Output должно появиться:

```text
[funny-core dev] client smoke ok ...
[funny-core dev] server smoke ok ...
```

Если smoke падает на `require`, смотри раздел 6.

### 4.2. Без запуска

Можно проверить только установку:

```bash
python3 build/build_test.py --no-place
ls build/dev/consumer/Packages/funny-core/src
```

Скрипт уже проверяет, что все алиасы заменены и gpp-директив не осталось.

---

## 5. Что нужно потребителю пакета

### 5.1. Установка

Через crater:

```bash
crater add funnydevz/funny-core
```

Или вручную в `crater.json`:

```json
"import_client": ["funny-core:funnydevz/funny-core@0.0.1"]
```

Пакет имеет `"import_to": "shared"`, поэтому его место — `import_client`
(клиентская/общая папка), а не `import_server`. Зависимости приезжают внутри
пакета: crater кладёт их по тем же путям, что и при разработке
(`src/vendor/import/<alias>`, `src/vendor/include/<alias>`), потому что они
объявлены в `vendor_packages`. В `import_client`/`import_server` их добавлять не
нужно.

### 5.2. Нет инициатора — require по путям

У пакета нет `init.luau` и `path_to_main`. Это планово для библиотеки классов:
`require(Packages["funny-core"])` не работает. Нужно требовать конкретные
модули:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local core = Packages:WaitForChild("funny-core")

local LuaObject = require(core.src.class.core.LuaObject)
local Observer = require(core.src.class.core.Observer)
local EnumObject = require(core.src.class.core.EnumObject)
local Basis = require(core.src.class.struct.geometry.Basis)
```

Публичный архив уже собран (`gpp` + `darklua`), поэтому `@alias`-require в нём
отсутствуют: пути относительные, включая `src/vendor/...`.

### 5.3. Зависимости

Ставить отдельно ничего не нужно. Пакет несёт в архиве:

- `src/vendor/import/Quat`;
- `src/vendor/import/SAT`;
- `src/vendor/import/Cryptography`;
- `src/vendor/import/BufferedArrays`;
- `src/vendor/import/LINQ`, `src/vendor/import/crate`, `src/vendor/import/BitMap`;
- `src/vendor/include/ProfileStore`.

Собранный код ссылается на них как `../../vendor/<realm>/<alias>` из
`src/class/...`, что соответствует раскладке архива.

> `ProfileStore` лежит в `src/vendor/include`, а пакет имеет `"import_to": "shared"`.
> Crater предупреждает, что серверные пакеты становятся видны клиенту: вендорить
> туда стоит только то, что не жаль показать.

### 5.4. Раскладка `vendor`

crater 0.7.5 хранит вендоренные пакеты в архиве по тем же путям, что и при
разработке (`src/vendor/import/<alias>`, `src/vendor/include/<alias>`), а не
переносит их в `_vendor`. Собранный код `build/prepack.py` рассчитывает пути
именно на такую раскладку.

В репозитории (для разработки и `crater install`) пакеты лежат в
`src/vendor/import` и `src/vendor/include`, а на них указывают алиасы
`import` / `include` из `src/config.luaurc`. Раскладку читает
`build/crater_layout.py` из `crater.settings.json`, поэтому переименование
папок в настройках достаточно.

### 5.5. Типы

`path_to_definition_files` указывает на `src/core.d.luau`. Если в
`crater.settings.json` включён `vscode_definitions: true`, crater добавит файл в
`luau-lsp.types.definitionFiles`. Тогда типы ядра доступны в автодополнении.

При `vscode_definitions: false` `crater install` пишет, что пакет пришёл с
`.d.luau`, но luau-lsp их не увидит. Тестовый проект ставит `true`.

### 5.6. Чем dev-пакет отличается от публичного

| | Публичный `crater pack` / `publish` | `build/build_test.py` |
| --- | --- | --- |
| Источник | `build/package` (результат `build/prepack.py`) | gpp + darklua напрямую |
| Вендор | `src/vendor/<realm>/<alias>` добавляет crater | `src/vendor` внутри пакета |
| Внутренние `@class` | заменены на относительные пути | заменены на относительные пути |
| `--#if` | раскрыты | раскрыты |
| Registry | GitHub PR | локальная папка |
| Назначение | публикация | проверка потребителем |

Публичный пакет больше не source-only: `prepack` (см. [BUILD.md](./BUILD.md))
собирает `build/package` до архивации. Dev-пакет проверяет ту же логику, но без
GitHub и без vendor-инъекции crater.

---

## 6. Если что-то не работает

| Симптом | Причина и решение |
| --- | --- |
| `build_test: gpp is not installed` | установи `gpp` (`apt install gpp` / `brew install gpp`) |
| `build_test: darklua is not installed` | `crater tool install`, затем открой новый терминал |
| `build_test: missing src/vendor` | выполни `crater install -y` в корне |
| `unresolved alias requires after darklua` | darklua не нашёл цель для `@alias`; проверь, что `src/vendor/import` и `src/vendor/include` существуют |
| `unprocessed gpp directives` | gpp не раскрыл `--#if`/`--#include`; проверь `src/project.gpp` |
| `No main module and no modules to expose` | ожидаемо: у библиотеки нет `init.luau` |
| `crater install` не видит версию | посмотри `build/dev/registry/packages.json` и `index.json`; при `--keep` версия могла уже существовать |
| smoke падает на `require` | проверь, что `Packages/funny-core/src/vendor` на месте |
| `build.rbxl` не создан | установи rojo (`crater tool install`) или запусти с `--no-place` |

---

## 7. Шпаргалка

```bash
# один раз
crater install -y

# собрать, опубликовать локально и установить потребителю
python3 build/build_test.py

# только сборка и установка, без .rbxl
python3 build/build_test.py --no-place

# посмотреть, что ушло в локальный registry
cat build/dev/registry/packages.json
find build/dev/registry/funnydevz/funny-core -maxdepth 2

# запустить тестовый проект
rojo serve build/dev/consumer/default.project.json
```
