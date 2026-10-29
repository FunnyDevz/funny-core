# Тесты типов `core.d.luau`

Jest-тесты, которые проверяют, что рантайм ядра соответствует декларациям из `src/core.d.luau`.
На каждый `export type` генерируется отдельный спек, поэтому новый тип получает тесты автоматически.

## Установка

Нужно:

- [Roblox Studio](https://create.roblox.com/), запущенная хотя бы раз и залогиненная;
- [Python](https://www.python.org/) 3.12+;
- [rokit](https://github.com/rojo-rbx/rokit);
- [crater](https://github.com/TheExeDEV/crater) 0.6.2+.

### Из архива

1. Распакуй архив в корень репозитория `funny-core` с заменой файлов. Структура папок в архиве уже совпадает с репозиторием. Кроме тестов, в архиве есть:
   - обновлённые `crater.json` (зависимости берутся из реестра wally, алиас `JestGlobals`), `rokit.toml` (jest-roblox-cli 0.4.10), `.gitignore` и `.github/workflows/test.yml`;
   - исправленные `src/class/core/EnumObject.luau` и `src/class/core/Observer.luau`. Studio не компилирует `if const x = … then`, без этого исправления не грузятся все енамы и всё, что зависит от `Observer`.

   После распаковки удали старые `src/jest.config.json` и `CI/run`, они больше не нужны.
2. Поставь инструменты и зависимости:

   ```bash
   rokit install
   crater install -y
   ```

3. Проверь, что всё собирается без Roblox:

   ```bash
   python CI/test.py --prepare-only
   ```

   Должно вывести `generate: 189 types ...` и `prepare: CI/build ready`.

### Из репозитория

Если всё уже лежит в репо, достаточно второго и третьего шага.

## Запуск

| Команда | Что делает |
| --- | --- |
| `python CI/test.py` | все тесты в headless Studio |
| `python CI/test.py types/value` | только тип `value` (шаблон — регулярное выражение по пути спека) |
| `python CI/test.py "types/(stack\|value)\."` | несколько типов |
| `python CI/test.py --prepare-only` | только собрать `CI/build`, без запуска |
| `python CI/test.py --install` | принудительно выполнить `crater install` |
| `python CI/test.py --retries 3` | сколько раз повторять, если Studio не стартовала (по умолчанию 2) |
| `python CI/generate.py` | показать, какой тип какой проверкой покрыт |

Результаты пишутся в `CI/output/`: `CI_<шаблон>.json` с результатами Jest и `game_<шаблон>.log` с выводом игры.

Пока идут тесты, не запускай вторую Studio и второй прогон: headless Studio и открытая Studio используют один раннер-плагин и мешают друг другу.

## Как это устроено

```
src/core.d.luau ──generate.py──► CI/build/spec/types/<тип>.spec.luau ─┐
src/**/*.luau ───prepare.py────► CI/build/core/**                     ├─ rojo (test.project.json) ─► jest-roblox-cli ─► Studio
CI/spec/contract.luau ─────────► CI/build/spec/contract.luau ─────────┘
```

- `CI/generate.py` разбирает `core.d.luau` и для каждого `export type` создаёт спек с описанием контракта. Виды контрактов:
  - `class`: тип с реализацией в `src/class`. Проверяется, что модуль загружается, `type` совпадает с именем типа, работает `it`/`is` на себя и на все базы, есть все объявленные методы.
  - `enum`: енам из `src/enums`. Элементы в рантайме совпадают с декларацией один в один, у каждого правильные `name`, `enum` и `hashlink`, работают `get_enum_by_name`, `get_enum_by_hashlink` и `is_my_enumitem`.
  - `enumitem`: все элементы принадлежат своему перечислению, хэшлинки уникальны.
  - `mixin`: интерфейс вроде `controllable`. Его методы есть у каждого реализованного класса, который его подмешивает.
  - `pending`: проверять в рантайме нечего (нет реализации, только поля-данные или чистый алиас). Показывается как `todo` с причиной.
- `CI/spec/contract.luau` содержит сами проверки. Здесь же можно писать ручные спеки: любой `CI/spec/**/*.spec.luau` попадёт в прогон.
- `CI/prepare.py` собирает `CI/build`:
  - раскрывает `--#if`/`--#define` из `project.gpp` и `build.gpp` (повторяет то подмножество gpp, которое использует `build/run`);
  - переписывает `require("@class/...")` в относительные пути, потому что Jest понимает только их.
- `test.project.json` кладёт `core`, `spec` и пакеты crater в `ReplicatedStorage` тестового плейса.
- `jest.config.json` задаёт настройки jest-roblox-cli.

## CI

`.github/workflows/test.yml` гоняет тесты через Open Cloud (`python3 CI/test.py --install`) на pull request и на push в `main` и `pre-main*`. Он только проверяет код и ничего не публикует.

Публикация в crater ручная, после того как CI на `main` зелёный:

```bash
crater bump
crater publish
```

`crater publish` открывает PR в реестр crater, и пакет появляется после того, как этот PR примут.

Нужны секреты организации FunnyDevz (Settings → Secrets and variables → Actions → **Secrets**) с доступом для `funny-core`:

| Секрет | Что это |
| --- | --- |
| `RBX_API_KEY` | Ключ Roblox Open Cloud с правами `universe-places:write` и `universe.place.luau-execution-session:write` на тестовый experience. |
| `ROBLOX_UNIVERSE_ID` | Universe тестового experience. |
| `ROBLOX_PLACE_ID` | Тестовый плейс. CLI перезаписывает его при каждом прогоне, поэтому не указывай боевой. |

Репозиторий публичный, поэтому:
- в логах Actions значения секретов GitHub заменяет на `***` сам;
- перед загрузкой артефакта `jest-results` шаг `Scrub results` вычищает `ROBLOX_UNIVERSE_ID` и `ROBLOX_PLACE_ID` из файлов `CI/output`;
- PR из форков секреты не получают, такие PR не могут запустить тесты в Open Cloud.

## Если что-то не работает

| Симптом | Причина и что делать |
| --- | --- |
| `Studio did not start the run`, `no run-mode plugin took the run over` | Headless Studio не подхватила прогон. `test.py` повторит сам; если не помогло, закрой все Studio и запусти снова. |
| `Studio did not start the run within 45000ms` | Headless Studio не успела загрузиться. Закрой открытые Studio. На медленной машине увеличь окно запуска переменной `JEST_ROBLOX_STUDIO_BOOT_TIMEOUT` (в мс), например `120000`. |
| `Studio run timed out` | Либо Studio не подхватила прогон, либо в ядре что-то вешает VM. Смотри «Известные проблемы». |
| `Do not import JestGlobals outside of the Jest 3 test environment` | Пакет jest-globals должен называться ровно `JestGlobals`, это алиас в `crater.json`. |
| `prepare: missing Packages, DevPackages` | Не выполнен `crater install -y`. |
| `require <модуль> failed: …` в тесте | Модуль ядра падает при загрузке, текст ошибки идёт следом. Это баг ядра, а не теста. |

## Известные проблемы ядра

На момент написания (прогон через Jest в Studio): 2712 тестов прошли, 112 упали, 56 todo.

1. **`Maybe:enactment` всегда возвращает класс вместо нового объекта.** В `src/class/common/gc/Maybe.luau:30` тип проверяется как `"LuaObject"`, а настоящий `type` — `"luaobject"`. Поэтому `Signal:get_signal_event()` отдаёт сам класс `Event`, у которого нет хранилища соединений, и `Event:connect` падает в `Event:27` (`table.insert(nil, …)`). Первым это ломает `Agent`.

   В игре это ещё и вешает сервер. `Agent` при загрузке подписывает `Signal` на `ScriptContext.Error`, каждая ошибка вызывает обработчик, обработчик падает, и это снова вызывает `ScriptContext.Error`. Тесты подменяют `engine.on_script_error` безопасным сигналом (`jest.mock` в `CI/spec/contract.luau`), поэтому здесь `Agent` просто падает с ошибкой, а не вешает прогон.

2. `IKR6Legs`: `StateMachine:34`, `table.find` получает `nil`.
3. `ikr6head` не наследуется от `ikr6limb`, и у него нет 17 методов `ikr6limb`.
4. `ikr6arms`: нет `get_left_arm`, ещё двух методов и `is_initiated`.
5. Енамы расходятся с декларацией: в `enum_connection_variant` лишний `Never`, в `enum_operation_variant` лишний `Null`.
6. `abilityinfo` и `variable` не задают своё поле `type`: получается `"struct"` и `"luaobject"`.
7. `directions`: нет `to_basis` из `vector_operations`.
8. `src/static/declare.luau` конфликтует с папкой `src/static/declare/`: в Roblox это два соседа с одинаковым именем. Файл нигде не импортируется.
