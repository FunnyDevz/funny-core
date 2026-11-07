# Сборка и публикация funny-core

> Документ лежит в `build/BUILD.md`. Команды в нём выполняются из корня репозитория.
> Проверка пакета глазами потребителя (gpp + darklua + локальный registry + `build/dev`) описана в [BUILD_DEV.md](./BUILD_DEV.md).

Репозиторий использует четыре разных сборочных сценария:

| Сценарий | Команда | Результат |
| --- | --- | --- |
| Полная сборка | `python3 build/build.py` | `build.rbxl`, готовый `build.project.json`, `core/` с вендоренными пакетами |
| Сборка для тестов | `python3 CI/test.py --prepare-only` | `CI/build/core`, `CI/build/spec` |
| Проверка пакета как потребителем | `python3 build/build_test.py` | локальный registry и `build/dev/consumer` |
| Публикация в crater | `crater publish` | архив пакета и PR в реестр |

`src/` в сыром виде запускать нельзя: в нём остаются `--#if`, `--#define` и `--#include`, а константы вроде `DEBUG` и `CORE_CLASS_USEABLE` появляются только после gpp-препроцессинга. Для запуска всегда нужна сборка.

Документ сверен с официальным README crater 0.7.5. В 0.7.4 появились настройка `vendor` и поле `vendor_packages`: зависимости можно не заставлять ставить потребителя, а вкладывать в сам пакет. В 0.7.5 `vendor` стал объектом: у каждого реалма (`client`, `server`) свой `path` и `alias`, поэтому в этом репозитории зависимости лежат в `src/vendor/import` и `src/vendor/include`, а публичный архив собирается через `package_root` + `prepack`.

---

## 1. Требования

| Инструмент | Версия | Зачем |
| --- | --- | --- |
| [crater](https://github.com/TheExeDEV/crater) | 0.7.5+ (в `crater.json` версия инструмента не фиксируется) | зависимости, инструменты, публикация |
| [gpp](https://github.com/logological/gpp) | 2.28+ | раскрытие `--#if` / `--#define` / `--#include` |
| darklua | 0.19.0 | замена `@alias` на пути в собранном коде |
| rojo | 7.7.1 | сборка `.rbxl` и sourcemap |
| stylua | 2.6.0 | форматирование |
| jest-roblox-cli | 0.4.10 | полный прогон Jest в Studio или Open Cloud |
| Python | 3.12+ | `CI/*.py` и `build/build.py` |
| Roblox Studio | — | локальный полный прогон Jest; CI использует Open Cloud |

Версии darklua, rojo, stylua и jest-roblox-cli закреплены в `crater.json` (`tools`) и устанавливаются crater-ом. gpp ставится отдельно:

```bash
# Debian / Ubuntu
sudo apt install gpp

# macOS
brew install gpp
```

Установка crater:

```bash
# Linux / macOS / Git Bash
curl -fsSL https://raw.githubusercontent.com/TheExeDEV/crater/main/installers/install | sh
```

```powershell
# Windows PowerShell
irm https://raw.githubusercontent.com/TheExeDEV/crater/main/installers/install | iex
```

После установки открой новый терминал и проверь:

```bash
crater --version
gpp --version
```

Обновить crater:

```bash
crater self-update
```

### Установка зависимостей

```bash
crater install -y
```

Все пакетные зависимости объявлены в `vendor_packages` и ставятся в
`src/vendor` (`vendor` в `crater.settings.json`): crater раскладывает их по
`src/vendor/import/<alias>` и `src/vendor/include/<alias>`, потому что у
реалмов `client` и `server` заданы `path` (`src/vendor/import`,
`src/vendor/include`) и `alias` (`import`, `include`). `import_client` и
`import_server` пусты — один пакет не может быть одновременно импортируемым и
вендоренным. Отдельно стоит `DevPackages` (`import_develop`: Jest и JestGlobals,
нужны только тестам), алиас `internal`.

В `crater.settings.json` (схема 0.7.5) включены `link_style: "string"`,
`vscode_definitions: true`, `darklua: true`, `sync: "auto"`, а `vendor` — это
объект с `client.path: "src/vendor/import"`, `server.path:
"src/vendor/include"` и алиасами `import` / `include`. Поэтому `crater install`
может обновить `.luaurc` и `.vscode/settings.json`. После установки проверь
`git status`. Для сборки алиасы уже прописаны в `src/config.luaurc`:

- `import` → `vendor/import`;
- `include` → `vendor/include`.

`vscode_definitions: true` важен: если он выключен, crater предупреждает, что
`path_to_definition_files` пакета (у ядра это `src/core.d.luau`) не доходит до
luau-lsp. `darklua: true` оставляет crater-у штатный darklua-сетап; ручной
пайплайн сборки (`src/build_info.darklua.json`) это не затрагивает.
`sync: "auto"` выбирает rojo/azul по наличию `default.project.json`.

Если `crater install` падает с `✗ Invalid dependency ...`, исправь строку в `crater.json`: она должна иметь вид `[Alias:][registry#]scope/name<operator><version>`. Подробнее — в разделе 7.

Заодно crater устанавливает закреплённые инструменты. Проверить их состояние:

```bash
crater tool list
```

Если какой-то инструмент отсутствует:

```bash
crater tool install
```

---

## 2. Полная сборка

```bash
python3 build/build.py
```

По умолчанию результат кладётся в `../bin` относительно текущей папки. Если запускать из корня репозитория, это соседняя папка `bin`:

```bash
python3 build/build.py -o /tmp/funny-build
```

`build/build.py` удаляет существующий каталог вывода и отказывается собирать в корень репозитория или внутрь `src`.

### Что делает `build/build.py`

1. Проверяет, что в `src/` есть `project.gpp`, а `src/vendor` уже установлен.
2. Находит `gpp`, `darklua` и `rojo` в `PATH`.
3. Препроцессит каждый `src/**/*.luau`, кроме `src/vendor/**`:
   - подставляет `src/project.gpp` + `src/build.gpp`;
   - раскрывает `--#include <fflag_core.gpp>`, `--#include <fflag.gpp>` и остальные include;
   - удаляет `--#if` / `--#else` / `--#endif` вместе с неактивными ветками;
   - пропускает `.d.luau`, `.gpp`, `*.project.json`, `.darklua.json` и `.md`.

   Флаги в `.gpp` задаются только числами `1` и `0`. `gpp` вычисляет `--#if` арифметически и считает любое нечисловое выражение истинным, поэтому `true`/`false` (как и неопределённый флаг) не вырезают ветку, а оставляют её. `build/run`, `build/build_test.py`, `build/prepack.py` и `CI/prepare.py` используют тот же формат.

4. Копирует `src/vendor` в `core/vendor` как есть (darklua их не обрабатывает). Это те же пакеты, что crater кладёт потребителю по тому же пути `src/vendor`.
5. Прогоняет `darklua process` с правилом `convert_require`: `require("@class/...")` превращается в путь внутри собранного дерева. Правило лежит в `src/build_info.darklua.json`, алиасы — в `src/config.luaurc` (он временно копируется в собранное дерево как `.luaurc` и удаляется после обработки). Корневой `.darklua.json` для `build/build.py` не используется. В `src/config.luaurc` есть алиасы `import` и `include` на `vendor/...` — darklua переписывает и их. `skip_files: ["**/vendor/**"]` не даёт darklua трогать вендоренные пакеты.

   Перед этим шагом явные инстанциации дженериков `f <<T>>(x)` маскируются комментариями, а после — возвращаются на место: `darklua 0.19.0` выбрасывает этот синтаксис при пересборке AST. Из-за маски darklua запускается с `--format retain_lines` (дефолтный формат удаляет комментарии), поэтому `core/` сохраняет исходные комментарии и форматирование. Логика вынесена в `build/darklua_safe.py` и используется всеми сборщиками; та же проблема и то же решение описаны в [BUILD_DEV.md](./BUILD_DEV.md), раздел 3.2.
6. Пишет `build.project.json` с деревом `ReplicatedStorage.core` (вендоренные пакеты лежат внутри `core/vendor`).
7. Собирает `rojo build` в `build.rbxl`.

Структура результата:

```text
<output>/
├── build.rbxl
├── build.project.json
└── core/
    ├── class/
    ├── enums/
    ├── extension/
    ├── platform/
    ├── static/
    ├── vendor/            # вендоренные пакеты
    │   ├── import/        # client-реалм
    │   └── include/       # server-реалм
    └── ...
```

### Флаг `UNIQUE`

Если заданы `CI=true` и `CORE_COMMIT`, в сборку попадает реальный commit:

```bash
CI=true CORE_COMMIT="$(git rev-parse HEAD)" python3 build/build.py -o /tmp/funny-build
```

Иначе `UNIQUE` остаётся `"UNKNOWN_BUILD"` из `src/project.gpp`, а в лог печатается `NON_PRODUCTION_BUILD (local build)`. CI-сборка передаёт `CORE_COMMIT` автоматически.

### Старый fish-скрипт

```bash
./build/run
```

Требует `fish` и `gpp`, кладёт результат в `build/target`. Скрипт делает только gpp-препроцессинг: не копирует пакеты, не запускает darklua и rojo. Для обычной работы используй `build/build.py`.

### Запуск собранного места

Открой `<output>/build.rbxl` в Studio либо подними live-sync:

```bash
rojo serve /tmp/funny-build/build.project.json
```

`rojo serve src/default.project.json` синхронизирует сырой `src/` без препроцессинга — это удобно для редактирования и работы Luau LSP, но не для запуска игры.

---

## 3. Сборка и тесты

```bash
# только собрать CI/build, без Studio
python3 CI/test.py --prepare-only

# полный прогон Jest: локально — headless Studio, в CI — Open Cloud
python3 CI/test.py

# только часть тестов
python3 CI/test.py types/value
```

`CI/prepare.py` собирает `CI/build` иначе, чем релизный build:

- раскрывает те же gpp-директивы;
- переписывает `require("@class/...")` в относительные пути;
- не запускает darklua и rojo;
- генерирует по спеку на каждый `export type` из `src/core.d.luau`.

Полезные команды:

```bash
python3 CI/generate.py   # какие типы и как покрыты
python3 CI/report.py     # Markdown-отчёт по последнему CI/output/CI_*.json
```

Результаты тестов: `CI/output/CI_<шаблон>.json` и `CI/output/game_<шаблон>.log`.

Подробности по тестам, Open Cloud и известным проблемам — в [CI/README.md](../CI/README.md).

---

## 4. Что попадает в пакет crater

Пакет описывается `crater.json`:

| Поле | Значение |
| --- | --- |
| `name` | `funnydevz/funny-core` |
| `registry` | `crater` — реестр по умолчанию для зависимостей без `registry#` (как в `crater init`) |
| `registries` | `{}` — своих реестров нет; встроенные (`crater`, `wally`, `pesde`, `forest`, `ember`, `luarocks`) доступны как префиксы |
| `version` | текущая версия; на момент написания — `0.0.1` |
| `can_publish` | `true` |
| `import_to` | `shared` |
| `path_to_main` | пусто — crater пытается собрать коллекцию модулей из корня пакета |
| `path_to_definition_files` | `./src/core.d.luau` (файл должен существовать, иначе `pack`/`publish` падают) |
| `vendor_packages` | все пакетные зависимости (`client` и `server`); они вкладываются в архив, а не ставятся потребителем |
| `import_client` / `import_server` | пусто — вендоренные пакеты не могут быть ещё и импортируемыми |
| `package_root` | `build/package` — то, что уходит в архив вместо корня репозитория |
| `scripts.prepack` | `python3 build/prepack.py` — запускается перед `pack`/`publish` |
| `package_files.exclude` | `CI/**`, `.github/**`, `build/**`, `src/temp/**`, `**/__pycache__/**`, `jest.config.json`, `test.project.json` |

### 4.1. `build/prepack.py`

`crater pack` и `crater publish` сначала запускают `prepack`, который собирает
публикуемое дерево:

1. `gpp` раскрывает `--#if` / `--#define` / `--#include` в `src/**`, кроме
   `src/vendor/**` и `src/temp/**`;
2. временно копирует `src/vendor` в `build/package/src/vendor`, чтобы
   darklua нашёл цели алиасов;
3. временный `.luaurc` сопоставляет `import` / `include`
   с `vendor/import` / `vendor/include` (пути берутся из
   `crater.settings.json`, см. `build/crater_layout.py`), поэтому собранный код
   получает пути `../../vendor/<realm>/<alias>`;
4. прогоняет darklua с `skip_files` и маскировкой `<<T>>` (общая логика в
   `build/darklua_safe.py`);
5. удаляет временный `src/vendor` и `.luaurc`;
6. сжимает пустые строки (`compact_tree` из `build/darklua_safe.py`): gpp оставляет пустые строки на месте директив и подключённых `.gpp`, а `retain_lines` их сохраняет. Пустые строки в начале файла убираются, серии из нескольких пустых строк сжимаются до одной, многострочные строки `[[ ]]` и комментарии `--[==[ ]==]` не меняются. То же делает `build/build.py` для `build.rbxl`;
7. копирует `src/core.d.luau`.

После `prepack` crater добавляет в архив залоченные вендоренные пакеты по тем
же путям, что и при разработке (`src/vendor/import/<alias>`,
`src/vendor/include/<alias>`), а всё содержимое `build/package` кладёт в корень.

Что реально попадает в архив (проверено на рабочем дереве, 247 файлов, ~405 КБ):

- корневые `crater.json`, `README.md`, `LICENSE.md` (и другие документы);
- собранный `src/**`: `core.d.luau`, `class/`, `enums/`, `extension/`,
  `platform/`, `static/`, `templates/` — уже без `--#if` и без `@alias`;
- `src/vendor/import/**` (LINQ, Quat, SAT, Cryptography, BufferedArrays, crate,
  BitMap) и `src/vendor/include/ProfileStore`;
- служебные файлы (`src/config.luaurc`, `*.gpp`, `src/default.project.json`,
  `src/build_info.darklua.json`) в архив не попадают: `prepack` их не копирует.

> **Текущее состояние пакета.** `path_to_main` пуст, а в корне пакета нет
> `init.luau`: все модули лежат в `src/`. Crater не может собрать ни main module,
> ни collection, поэтому `install`, `pack` и `publish` предупреждают:
>
> ```text
> ! No main module and no modules to expose. Set path_to_main, add init.luau,
>   or put .luau modules in the package root so users can require it.
> ```
>
> Это планово для библиотеки классов: потребитель требует модули по путям
> (см. [BUILD_DEV.md](./BUILD_DEV.md), раздел 5.2).

Важно:

- `src/core.d.luau` публикуется как definition-файл: у потребителя появляются
  типы ядра.
- Вендоренные пакеты лежат по тем же путям, что и при разработке
  (`src/vendor/import/<alias>`, `src/vendor/include/<alias>`): crater 0.7.5
  сохраняет раскладку `vendor` и в архиве, а не переносит её в `_vendor`.
  Собранный код рассчитан именно на такую раскладку.
- `src/temp/**` не попадает ни в архив, ни в `build/package`; в `build/build.rbxl`
  он, наоборот, собирается. `src/temp` — отладочный слой, не для продакшена.
- `.crater-declare` и `crater.lock` нужно коммитить. `src/vendor`, `DevPackages`,
  `build/package`, `build/dev` — нет.
- Crater принимает `.md` только на английском или русском; если текст на другом
  языке, `pack`/`publish` остановятся с именем файла.
- Перед публикацией полезно выполнить `crater pack` и глазами проверить список
  файлов: он показывает ровно то, что уйдёт в реестр.
- Проверить пакет глазами потребителя (gpp + darklua + локальный registry +
  `build/dev/consumer`) можно командой `python3 build/build_test.py`; подробности
  — в [BUILD_DEV.md](./BUILD_DEV.md).

---

## 5. Публикация

Публикация ручная. CI (`test.yml`) только проверяет код и ничего не публикует.

### 5.1. Первый раз

```bash
crater login
crater whoami
```

`crater login` открывает `https://github.com/login/device` и просит одноразовый код. Вход сохраняется в `~/.config/crater/credentials.json` (на Linux/macOS). Для смены аккаунта — `crater login --force`, для выхода — `crater logout`.

Пакет принадлежит организации `funnydevz`: публиковать может любой её участник. Registry check видит только **публичных** участников, поэтому при скрытом членстве `crater publish` предложит сделать его публичным: GitHub → организация → People → твоя строка → Public. Если GitHub не разрешает, видимость меняют вручную по той же ссылке.

### 5.2. Перед публикацией

1. Все изменения закоммичены, рабочее дерево чистое.
2. CI на `main` зелёный.
3. Локальные проверки проходят:

   ```bash
   crater install -y
   crater doctor
   python3 CI/test.py --prepare-only
   ```

4. Полный прогон тестов выполнен, если менялся рантайм:

   ```bash
   python3 CI/test.py
   ```

5. `crater pack` показывает ожидаемый список файлов. Команда сама запускает `prepack` и добавляет `src/vendor/**`; предупреждение `No main module and no modules to expose` для библиотеки классов ожидаемо:

   ```bash
   crater pack
   ```

6. Версия в `crater.json` ещё не публиковалась:

   ```bash
   crater versions funnydevz/funny-core
   ```

Для воспроизводимой установки зависимостей (например, на чистой машине или в CI) используй `crater install --locked`: команда упадёт, если `crater.lock` расходится с `crater.json`, вместо того чтобы молча обновить lock-файл.

### 5.3. Релиз

```bash
# поднять версию: patch | minor | major
crater bump

# посмотреть, что именно уйдёт в архив
crater pack

# полная проверка без отправки
crater publish --dry-run

# отправить в реестр
crater publish
```

`crater bump` без аргумента поднимает patch, `crater bump minor` — minor, `crater bump major` — major. Компоненты версии не переходят в двузначные числа: patch-бамп `0.0.9` даёт `0.1.0`, `0.9.9` — `1.0.0`. Если нужен именно `0.0.10`, версию придётся поправить в `crater.json` вручную, но crater всё равно потребует, чтобы она была новой.

`crater publish` прогоняет тот же сканер, что и registry check: исполняемые файлы блокируют отправку, а опасные и подозрительные паттерны показываются в отчёте. `--dry-run` делает всё, кроме отправки.

`crater publish` открывает PR в [TheExeDEV/crater-registry](https://github.com/TheExeDEV/crater-registry). Пакет появляется в реестре только после того, как PR примут. После принятия:

```bash
crater info funnydevz/funny-core
crater versions funnydevz/funny-core
```

Если в корне есть `CHANGELOG.md`, crater перенесёт в реестр секцию текущей версии; без секции `publish` предупредит. `CHANGES.md` и `HISTORY.md` тоже подходят.

### 5.4. После публикации

Закоммить изменение версии и, по желанию, поставь тег:

```bash
git add crater.json crater.lock
git commit -m "chore: release 0.0.2"
git tag v0.0.2
git push
git push --tags
```

### 5.5. Правила версий

- Каждая публикация требует **новой** версии. Уже опубликованную версию изменить нельзя.
- Формат — три числа: `1.0.0`, `0.2.5`; не `1.0` и не `v1`.
- Пока пакет живёт в `0.x`, ломающие изменения допустимы в minor, но лучше фиксировать их в описании релиза.
- Для игры, которая не публикуется, `can_publish` ставят в `false`. У `funny-core` стоит `true`.

---

## 6. CI

`.github/workflows/test.yml` запускается на:

- `pull_request`;
- push в `main` и `pre-main*`.

Что делает workflow:

1. Ставит rokit (`CompeyDev/setup-rokit`) и выполняет `rokit install --no-trust-check`.
2. Скачивает crater `v0.7.5` в `~/.local/bin` и добавляет в `PATH` также `~/.crater/bin`.
3. Запускает `python3 CI/test.py --install`: внутри выполняется `crater install -y`, затем Jest через Roblox Open Cloud.
4. Вычищает `ROBLOX_UNIVERSE_ID` и `ROBLOX_PLACE_ID` из `CI/output`, собирает Summary через `CI/report.py` и прикладывает `CI/output` артефактом.

Нужные секреты организации:

| Секрет | Назначение |
| --- | --- |
| `RBX_API_KEY` | ключ Open Cloud с `universe-places:write` и `universe.place.luau-execution-session:write` |
| `ROBLOX_UNIVERSE_ID` | universe тестового experience |
| `ROBLOX_PLACE_ID` | тестовый place, не боевой |

PR из форков секретов не получают и тесты в Open Cloud не запускают.

Публикация в реестр crater выполняется в `release.yml` вместе с GitHub Release (см. ниже).

### 6.1. GitHub Release

`.github/workflows/release.yml` запускается после успешного `Tests` на push в `main` (то есть после слияния PR) и вручную через `workflow_dispatch`:

1. читает `version` из `crater.json`; если релиз `v<version>` уже есть, ничего не делает;
2. ставит gpp и crater `v0.7.5`, выполняет `crater install --locked -y`;
3. собирает архив пакета `crater pack -o dist/funny-core-<version>.zip` и место `python3 build/build.py`, копирует `build.rbxl` в `dist/funny-core-<version>.rbxl`;
4. создаёт GitHub Release `v<version>` на слитом коммите с этими двумя файлами и автоматическими release notes;
Затем job `registry` публикует пакет в реестр crater (работает и для уже существующего релиза, поэтому повторный запуск через `workflow_dispatch` дозаливает пропущенную версию):

1. проверяет `TheExeDEV/crater-registry`: если `<name>@<version>` уже есть в `index.json`, ничего не делает; если PR `Publish <name>@<version>` уже открыт, сразу переходит к слиянию;
2. требует секрет `CRATER_GITHUB_TOKEN` и падает с ошибкой, если его нет. Это classic personal access token участника организации `funnydevz` (членство публичное) со scope `public_repo` и `read:org`. Встроенный `GITHUB_TOKEN` не подходит: он не может открыть PR в другом репозитории;
3. выполняет `crater publish -y`, который открывает PR в реестр;
4. если у владельца токена есть права maintain на реестр, дожидается проверки `Check packages` и пробует слить PR (squash). Если правила реестра не дают слить (например, нужно одобрение, а автор PR и есть владелец токена) или прав нет, job не падает, а оставляет PR открытым с пометкой в логе, и его сливают вручную.

Чтобы выпустить новый релиз, подними версию (`crater bump`) в `pre-main-tests`: PR в `main` откроется сам (см. 6.2), после его слияния выйдет релиз.

### 6.2. Автоматический PR в `main` и флаг `DEBUG`

`.github/workflows/promote.yml` держит `DEBUG 1` в `pre-main-tests` и `DEBUG 0` в `main`. Руками `--#define DEBUG` в `src/project.gpp` менять не нужно.

Job `promote` запускается после успешного `Tests` на push в `pre-main-tests` и вручную через `workflow_dispatch`:

1. сравнивает `pre-main-tests` с `main`, считая `DEBUG` равным `0`; если отличий нет, ничего не делает;
2. иначе, если в `src/project.gpp` стоит `--#define DEBUG 1`, пушит в `pre-main-tests` коммит `Disable DEBUG for main` с `0`;
3. открывает PR `pre-main-tests` → `main`, а если он уже открыт, обновляет заголовок и описание. Заголовок `Release <version>`, если версия в `crater.json` отличается от `main`, иначе `Merge pre-main-tests into main`.

Пока PR открыт, в `pre-main-tests` стоит `DEBUG 0`: это то состояние, которое уйдёт в `main`.

Job `sync` запускается на push в `main` (то есть после слияния PR): вливает `main` в `pre-main-tests`, возвращает `--#define DEBUG 1` коммитом `Enable DEBUG for pre-main-tests` и пушит. Если `main` не вливается без конфликтов, job падает, и слияние нужно сделать вручную, оставив `DEBUG 1`.

Обоим job нужен секрет `CRATER_GITHUB_TOKEN` (тот же PAT, что и для реестра). PR, открытый встроенным `GITHUB_TOKEN`, не запускает `Tests`, и его нельзя слить. Если в `pre-main-tests` меняются файлы в `.github/workflows`, у токена должен быть ещё scope `workflow`, иначе GitHub не даст workflow запушить в `pre-main-tests`.


CI выполняет `crater install -y`, а не `crater install --locked`. Если нужна строгая проверка соответствия `crater.lock`, замени команду в `.github/workflows/test.yml` или добавь отдельный шаг с `--locked`.

---

## 7. Если что-то не работает

| Симптом | Причина и решение |
| --- | --- |
| `prepare: missing src/vendor, DevPackages` | не выполнен `crater install -y` |
| `build: missing src/vendor` | не выполнен `crater install -y` |
| `prepack: missing src/vendor` | не выполнен `crater install -y` |
| `build: gpp is not installed or not on PATH` | установи gpp и открой новый терминал |
| `build: darklua is not installed` | `crater tool install` |
| `build: rojo is not installed` | `crater tool install` |
| `✗ Invalid dependency LINQ:` | алиас указан без пакета. Нужно `"LINQ:scope/name^"`, `"LINQ:scope/name=1.2.3"` или удалить строку. Любая такая ошибка блокирует `doctor`, `pack` и `publish` |
| `! No main module and no modules to expose` | crater не нашёл require-входа: `path_to_main` пуст, а в корне пакета нет `init.luau` или `.luau`-модулей. Для библиотеки классов это ожидаемо; для require-пакета создай `init.luau` и укажи `path_to_main` |
| `✗ vendor = ... overlaps the package folder ...` | в `crater.settings.json` `vendor` и пути реалмов пересекаются. В 0.7.5 используй объект `vendor.client` / `vendor.server` с разными `path`, как здесь (`src/vendor/import`, `src/vendor/include`) |
| `unable to find ... vendor/...` при `crater pack` | `prepack` не выполнился или упал; запусти `python3 build/prepack.py` и посмотри ошибку |
| `crater doctor` показывает lock/manifest, folders, links, `.luaurc`, Rojo mapping | исправь то, на что указывает вывод; после изменения зависимостей выполни `crater install` |
| `You are not signed in to GitHub` | `crater login` |
| `make your membership public` | сделай членство в организации публичным, см. раздел 5.1 |
| `the package name must start with <login>/` | имя в `crater.json` должно начинаться с твоего GitHub-логина в нижнем регистре; для организации — `<организация>/<пакет>`, здесь `funnydevz/funny-core` |
| `version '1.0' needs three numbers, write '1.0.0'` | версия должна быть `MAJOR.MINOR.PATCH`, например `0.1.0` |
| `<scope>/<name>@<version> is already published` | `crater bump`, затем снова `crater publish`; опубликованную версию изменить нельзя |
| `Publishing is disabled` | поставь `"can_publish": true` в `crater.json` |
| `path_to_definition_files` не находит файл | проверь, что `./src/core.d.luau` существует и не исключён |
| Studio не стартует тесты | закрой все открытые Studio; см. [CI/README.md](../CI/README.md) |
| `require <модуль> failed` в тесте | модуль падает при загрузке; это баг ядра, смотри текст ошибки в `CI/output/game_*.log` |

---

## 8. Шпаргалка

```bash
# зависимости и инструменты
crater install -y
crater tool list

# локальная сборка
python3 build/build.py -o /tmp/funny-build

# проверка пакета как потребителем (локальный registry + build/dev)
python3 build/build_test.py

# проверка без Studio
python3 CI/test.py --prepare-only

# полные тесты
python3 CI/test.py

# проверка конфигурации и пакетов
crater doctor
crater audit

# вход (один раз на машину)
crater login

# релиз
crater bump
crater pack
crater publish --dry-run
crater publish
```
