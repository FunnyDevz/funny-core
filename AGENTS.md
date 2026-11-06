## 1. Overview

The project is the **core of a game runtime in Luau/Roblox**, implementing its own object model on top of the `luaobject` types declared in `src/core.d.luau`. Everything written in `src/class/**` must implement the types from `core.d.luau`, not invent a new contract. The `src/core.d.luau` file is the **single source of truth** for interfaces and RTTI mechanics.

The key principle is **inheritance via type intersection**, not through metatable chains like in standard OOP. The base type is `luaobject`, and extension is done via `extend<extension, base>`. Everything else (services, structs, enums, controllers, events) is assembled from these two building blocks.

```luau
export type extend<extension = {}, base = luaobject> = extension & base
```

Any deviation from this principle (manual metatables, "normal" classes, copying behavior from other languages) is considered an architectural violation. In the future, refer to the actual state of the project; this instruction may be outdated in its implementation. However, it is guaranteed not to become outdated in its stylistics.

---

## 2. Core Concepts the Agent Must Know

### 2.1. `luaobject`

The base object of the project is not a class, but a **semantic prototype**: both the class and the instance are `luaobject`. Construction is done via `:new()`, initialization via `:host(f)`, and finalization via `:finally(f)`. `luaobject` carries RTTI: `type`, `it`, `is`, `as`, `same`, `eq`, `base`, `iden`, `ttype`.

If the agent needs to write something that "is a project object", it **must not** write `{ ... }` manually. It must declare the type in `core.d.luau` and inherit from `luaobject` (either directly or through one of the base interfaces).

### 2.2. Struct

`struct` is an **immutable data carrier**, with no hidden state. Changes are only made via `:clone(change)` and `:new()`. All "informational" classes (`*Info`, `NetPack`, `Result`, geometry, `Basis`, etc.) are implemented as `struct`. Iteration over values is done via `:each(type, f)`.

If the agent needs to modify a `struct`, it must not write a mutating setter. It must either declare a new field and create it via `clone`, or leave it as is.

### 2.3. Enums

Enums are structured as objects: `enumobject` (the container, holding `enumitem`s) and `enumitem` (the specific value). They do not use Roblox `Enum`, but are "custom". Enum implementations are located in `src/enums/{descriptor,mode,notification,state}/*.luau`, and their types are in `core.d.luau` next to the corresponding `enumitem_*`/`enum_*`.

Rule: **any new enum** must be added to both `src/enums/**` and `core.d.luau` (types `enumitem_*` and `enum_*`).

### 2.4. Observer

`observer` is a typed observer. It serves as the foundation for `event`, `connection`, `signal`, `value`, `timer`, `binder`, `reference`, `maid`, `maybe`, `template`, `stateregistry`, `profile`, `iteminstance`, etc. Subscription behavior is described via `enumitem_connection_variant` (`Ever`, `Once`, `Skip`, `Next`).

If the agent needs a "custom event", it must not invent a new mechanism; it must use `event`/`observer`.

### 2.5. Services

`service` is a singleton object with `name` and `enabled`. Services are located in `src/class/service/` (`DataClient`, `DataServer`, `SharedNet`). Public service APIs must have types defined in `core.d.luau`.

### 2.6. Platform Layer

Roblox wrappers (Instance, Players, RBXScriptSignal, worldspace, network, datamodel, engine) are in `src/platform/roblox/`. **Game logic and the core must not directly depend on Roblox** if a wrapper exists. Direct access to `game`, `workspace`, `Enum`, `CFrame` is allowed, but only in `platform/` or where explicitly stated in the contract. If it is impossible to do otherwise, it may be permitted. It depends on the context of the situation.

### 2.7. Type Metadata

`src/static/` is a **custom typing layer** that:
- describes valid types (`mtargument`, `mtypes`);
- validates arguments, types and return values (`ftype`, `ctype`, `mtout`);
- contains "meta-information" about fields and their origins (`mtinfo`, `ctags`);
- provides declarations (`declare/`: `types`, `mtypes`, `tables`, `dummies`, `mtinfo`) and project-wide metadata (`project/`: `mtluaobject`, `geometry`, `extension`, `global`).

If the agent adds a new type/field/contract, the corresponding entry must appear in `src/static/**` (specifically in `src/static/mtargument` and `src/static/declare/mtypes`, where meta-types are stored), otherwise validation will not see the innovation. At least, this applies if it was not possible to describe it using standard means. `@declare/*` and `@project/*` are both aliases of folders inside `src/static/`.

### 2.8. Scheduler vs task

The project has a custom `scheduler`, which **conflicts** with `task`. By default, new code should use `scheduler` if it is already present in the class contract. Mixing them in the same module is only allowed with a runtime check of whose code it specifically is. For this, use `scheduler:whose()` and branching.

---

## 3. Directory Structure and Contents

```
src/
├── core.d.luau              # types and contracts (single source of truth)
├── class/                   # object implementations
│   ├── common/              # universal building blocks
│   │   ├── collection/      # Stack, Queue
│   │   ├── gc/              # Heap, Maid, Maybe, Template
│   │   ├── physics/         # KinematicController, P/PD/PI/PIDController
│   │   ├── runtime/         # Controller, Signal, Timer
│   │   ├── signal/          # Connection, Event
│   │   ├── Binder.luau      # Instance-to-object binding
│   │   ├── Reference.luau   # Instance wrapper with events
│   │   ├── StateRegistry.luau # registry of active enum states
│   │   └── Value.luau       # value + change notifications
│   ├── core/                # RTTI core: LuaObject, EnumItem, EnumObject,
│   │                        # Disposable, Observer, Path, Pointer,
│   │                        # Scheduler, Service, Struct, Variable
│   ├── game/                # game entities
│   │   ├── character/       # Character, Entity, ik/r6/
│   │   ├── control/         # Faction, Round, CharacterStorage
│   │   ├── inventory/       # Inventory, Item, ItemStack, ItemObject,
│   │   │                    # ItemInstance, ItemBehavior, ItemContext
│   │   ├── Ability.luau
│   │   └── Profile.luau
│   ├── service/             # services: DataClient, DataServer, SharedNet
│   └── struct/              # data structures
│       ├── common/          # NetPack, Result
│       ├── game/            # AbilityInfo, CharacterInfo, IKR6*Info
│       └── geometry/        # AABBVolume, Basis, CubeVolume, Directions,
│                            # GeoVolume, OBBVolume, Quad, Triangle
├── enums/                   # custom EnumObject/EnumItem
│   ├── descriptor/          # "variants" (DirectionVariant, NetSource, ...)
│   ├── mode/                # modes (IKLimbMode)
│   ├── notification/        # notification types
│   └── state/               # states (ControllerState, RoundState, ...)
├── extension/               # std and ttable — language extensions
├── platform/roblox/         # Roblox API wrappers
├── static/                  # metadata/typing layer
├── temp/                    # debugging tools (not for production)
└── templates/               # class/script/struct templates
```

There is no `src/settings/` anymore: preferences live in `core.d.luau`, and `@project` is an alias of `src/static/project/`.

**Layer correspondence rule:** `class/**` implements `core.d.luau`; `enums/**` implements custom `enumobject`; `static/**` validates and describes them; `platform/**` hides Roblox.

---

## 4. Type Style and Naming

1. **One public type = one declaration in `core.d.luau`.** Implementations do not "invent" fields, but follow the declared contract.
2. **Interfaces** are declared as `export type <name> = { read <field>: ... }`. Object methods are `read` functions, properties are `read` fields. Only non-reference data types can be mutable. At the same time, classes are forbidden to have reference types in the public field scope except for functions: this concerns table properties/fields. Mutations for `struct` are forbidden.
3. **Object property fields** are named in `snake_case` (e.g., `hit_position`, `up_direction`, `current_basis`).
4. **Object methods** start with a verb (`get_*`, `set_*`, `is_*`, `has_*`, `from_*`, `apply_*`, `add_*`, `rem_*`, `rebuild_*`, `invoke_*`).
5. **Mixin interface names** start with a prefix (`list_checks`, `list_operations`, `math_operations`, `geometry_*`, `vector_operations`, `I_targetable`, `positioned`, `rotateable`, `centerable`, `stateable`, `informable`, `initiable`, `switchable`, `instanceable`, `referenceable`, `controllable`, `modifier`, `iterations`, `loopable`, `reloadable`, `private_storage`, `invokeable`, `asyncable`).
6. **Enums:** `enum_<name>` — container, `enumitem_<name>` — specific enum. `enumitem` names are PascalCase (`DataLoaded`, `ProfileLoading`, `TickNotification`).
7. **Events and notifications:** `enumitem_<x>_notification` and `enum_<x>_notification`.
8. **Info structs:** `*info` (`abilityinfo`, `characterinfo`, `ikr6leginfo`), not "data" or "config".

---

## 5. Change Rules

### 5.1. Changing the Contract

Any change to `core.d.luau` (new field, new type, new interface) requires:
1. Updating `src/static/**` — if the type participates in validation.
2. Updating `src/enums/**` — if a new enum is introduced.
3. Implementation in the corresponding `src/class/**` — if the contract is declarative, the implementation must still be brought into compliance.
4. Verification that existing implementations do not violate the new requirements.

### 5.2. Separate the Layers

- `core.d.luau` — types only.
- `src/class/**` — contract implementations only.
- `src/enums/**` — enum objects only.
- `src/static/**` — meta-description only.
- `src/platform/**` — Roblox wrappers only.
- `src/temp/**` — temporary, deletable, not for production.

Mixing layers is not allowed. If there is a temptation to "put a utility nearby" — it goes into `src/extension/` or the corresponding layer.

### 5.3. Do Not Break RTTI

`luaobject` mechanics (`new`, `host`, `finally`, `base`, `ttype`, `it`, `is`, `as`, `same`, `eq`) are mandatory. A new class **must not** replace it with its own metatables. Inheritance is only via `extend`.

### 5.4. Enum-objects, Not Roblox Enum

A new enum is formatted as an `enumobject`, not as `Enum.<X>`. `enum_<name>` and `enumitem_<name>` must appear in `core.d.luau`.

### 5.5. Validation

If a type participates in `ftype:validate` / `ctype:validate`, its meta-description must be in `src/static/**`. Without this, validation will not "see" the object or field.

### 5.6. Scheduling

New code uses `scheduler` by default, not `task`. If a class already implements `scheduler`, do not mix in `task`, as they conflict.

---

## 6. Areas Requiring Coordination

The repository has `/.github/CODEOWNERS` — it defines which parts of the code belong to whom and who should review changes. Before changing areas outside the agent's/contributor's zone of responsibility, you must **coordinate the change with the area owner** — code cannot be changed "behind their back" without an explicit request.

Practical rule: if the agent is going to edit a file that is not "theirs" according to `CODEOWNERS`, they must explicitly state this in the PR/message and wait for the owner's response. Silent edits of someone else's areas are unacceptable.

---

## 7. Areas Marked as Requiring Attention (In General)

The project has areas that are either unfinished, marked as "in development"/"requires refinement", or depend on external approvals. Editing them is not forbidden, but requires **separate analysis and an explicit request** — they cannot be changed "along the way" or "while at it".

If the agent sees TODO comments in `core.d.luau`, `*_TODO_*` types, unfilled branches (e.g., geometric volumes that are declared but not implemented), or encounters an unimplemented class that does not yet have an implementation in `src/class/**`, this is a signal that:

1. Edits to such an area must be **discussed first**, not implemented in one go.
2. If the edit affects someone else's area according to `CODEOWNERS`, it must be coordinated with the owner.
3. "As best as I can" implementation is not welcome: either a full implementation according to the contract, or leaving the area as is.

Known examples at the time of writing (verify before relying on this list):

- `quant` and `remotecall` are declared in `core.d.luau`, but have no implementation in `src/class/**` (`Quant.luau` was removed, there is no `RemoteCall.luau`).
- `spherevolume`, `conevolume`, `capsulevolume` and `tetavolume` are declared in `core.d.luau`, but are not implemented and are not part of `geometry_volume`.
- `src/class/game/control/CharacterStorage.luau` is an empty placeholder.
- `src/temp/ik_arms_r6.luau` is a prototype.

Rule: **do not guess the behavior for the contract author**. If the contract is ambiguous, clarify it, do not implement it at random.

---

## 8. Quick Checklist for the Agent

- [ ] Is the type declared in `core.d.luau`?
- [ ] Does the implementation match the declared type (all `read` fields/methods are present)?
- [ ] Is inheritance done via `extend`, not custom metatables?
- [ ] For `struct` — are there no mutating setters, changes only via `clone`?
- [ ] For a new enum — are there both `src/enums/**` and types in `core.d.luau`?
- [ ] For a new field — is there a meta-description in `src/static/**`?
- [ ] Are there no direct core dependencies on Roblox (only via `src/platform/roblox`)?
- [ ] Is `task` not added if the class already implements `scheduler`?
- [ ] Is someone else's area not changed without coordination via `CODEOWNERS`?
- [ ] Is a "TODO area" not implemented without an explicit request?
- [ ] Are layers not mixed (`class`/`struct`/`enum`/`static`/`platform`)?

If at least one item is not completed, the change is not ready.

# 9. Building a Class

This section describes **exactly how a class is built** in the project, using `Observer.luau` as an example. All classes must follow this structure; deviations are only allowed if dictated by the contract from `core.d.luau` and coordinated with the area owner. This is not a strict instruction on how to do the class RUNTIME, because this is an instruction on how to ARCHITECTURALLY build a class in a unified style with the project.

## 9.1. File Skeleton

Any class file has a fixed skeleton:

```luau
--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

-- 1. Imports
const LuaObject = require("@class/core/LuaObject")
...

-- 2. Local type aliases
type observer_on<T = enumitem> = ...
type observer_var<T = unknown> = ...

-- 3. Private space
const private = { type = "observer" }

-- 4. Class creation
const class: observer = LuaObject:new({ ... })

-- 5. Initializer
class:host(function(new) ... end)

-- 6. Private block
do ... end

-- 7. Return
return class
```

The agent **must not** change this order. All 7 parts are always present; if a part is not needed (e.g., the `do` block), it is either empty or absent, but it does not move to another place.

## 9.2. Module Header and Imports

- `--!strict` — mandatory.
- `--#include` — mandatory, fixed order: `project.gpp` → `build.gpp` → `fflag_core.gpp` → `fflag.gpp`.
- Imports go via path aliases `@class/*`, `@enums/*`, `@declare/*`, `@extension/*`, `@project/*`, `@static/*`. Direct relative paths (`./`, `../`) are not used.
- After imports comes **grouping by layers**: first the core (`LuaObject`, `EnumItem`, `EnumObject`, `Pointer`), then enums, then `declare`, then `extension`/`static`/`project`. This is not a formal rule, but an agreed-upon order; breaking it is bad practice.

## 9.3. Local Type Aliases

Local aliases (`observer_on`, `observer_var`) are declared **before** `private` and **before** `class`. They are needed to:
- simplify `ftype:write` signatures;
- give a name to the "actual" type that is used only inside the module.

These are **not** exported types. Exported types are only in `core.d.luau`.

## 9.4. Private Space `private`

`const private = { type = "<type>" }` is **not** an ordinary table. Everything that should not leak outside is put into it: type constants, `newproxy()` sentinels, `metatable`s, helper functions, `shadow_space`, `dummies`, `relevant_actions`, etc.

Key rules:

1. **`private.type`** — string identifier of the class. It matches what is passed to `:new({ type = ... })`, and what is used in `:as<<observer>>(class.type)`, `:that(x, class.type)`, `ftype:write(..., private.type, ...)`.
2. **`private.shadow_space`** — table with weak keys (`tables.__mode_ks`), where per-object state accessible via `self:get`/`self:set` is stored.
3. **`private.pointers`, `private.items`** — `newproxy()` sentinels. They cannot be replaced with strings or tables, because through them `private_storage` (`:get`/`:set`) separates private fields of one class from fields of another.
4. **Helper functions** are placed in `private` and become available only inside the module.
5. **Public class fields** (`deferred_call`, `deferred_mode`, `allow_new_connections`) are declared directly in `:new({...})` and are `read` fields of the contract.

## 9.5. Class Creation via `LuaObject:new`

```luau
const class: observer = LuaObject:new({
    type = private.type,
    ...
    subscribe = ftype:write(...),
    ...
})
```

- The class is the **result** of `LuaObject:new({...})`, not a separate construct.
- All public fields and methods are listed in a single literal.
- Data fields are just values (`deferred_call = true`).
- Methods are wrapped in `ftype:write`. **Without the wrapper, the method is not considered a public contract**, because `ftype` checks arguments and types on input and output.

## 9.6. Method Wrapper `ftype:write`

Signature:

```luau
ftype:write(fn, <return_type?>, <self_type>, <arg1_type>, <arg2_type>, ...)
```

Rules:

1. **First argument** — `fn`. Usually this is `function(self, ...) ... end`.
2. **Second argument** — return type. If the function returns nothing — `mtypes.never`. If it returns `Y` — `ftype:opt(mtypes.anyt)` (for `Y?`) or `ftype:var(...)` (for `...`). The return type is **mandatory**, even if it is `mtypes.never`.
3. **Third argument** — `private.type` (the type of `self`). For static methods — the type of the class.
4. **Next** — argument types **in order** after `self`. For a variadic argument — `ftype:var(<type>)`.
5. **Logical alternatives** — via `ftype:uor(...)`.
6. **Specific types** — via `ftype:var(<TypeName>)` or `EnumItem.type`/`EnumObject.type`.
7. **`mtypes.anyt`** — "any type", used when typing is not needed.

If the signature in `ftype:write` does not match the actual function signature, this is an error that the validator should catch. The agent **must not** adjust the types in `ftype:write` to "what actually arrives", it must reflect the **contract**.

## 9.7. Initializer `:host`

```luau
class:host(function(new)
    const new = new:as <<observer>> (class.type)
    private.shadow_space[new] = {}
    new:set(private.pointers, setmetatable({}, private.meta))
    new:set(private.items, {})
end)
```

- `:host(f)` — replaces the constructor. It is called when creating each instance (including the `class` itself, if `CORE_CLASS_USEABLE` is enabled).
- Inside, it is mandatory to:
  1. **Cast `new`** to the target type via `new:as<<observer>>(class.type)`. This gives the correct `self` type further down.
  2. **Initialize `shadow_space`** for `new` (if the class uses private fields).
  3. **Initialize `:set(<sentinel>, ...)`** for each `newproxy()` sentinel, so that `:get(...)` returns a valid value, not `nil`.
- `:host` can be **only one**. Overwriting `:host` on an already existing class is a "toggle" (see the `luaobject.host` contract), not adding a second initializer. If multiple steps are needed, they are packed into a single lambda.
- `:host` **must not** call `:finally` or other lifecycle hooks itself — RTTI does that.

## 9.8. Private Block `do ... end`

Everything that is not part of the class and should not get into the public contract lives in `do ... end` after `:host`:

1. **Local types** (`type flatted = ...`, `type pointer_internal = ...`) — only for private functions.
2. **Initialization of `private.*`**: `private.meta = tables.__mode_ks`, `private.shadow_space = setmetatable({}, private.meta)`, `private.pointers = newproxy()`, `private.items = newproxy()`.
3. **`--#if CORE_CLASS_USEABLE`** — initialization block for `class` as an instance. Symmetrical to what `:host` does, but executed once when loading the module. **Mandatory** if the class can be used as an object.
4. **Private functions** (`private.create_flatted_on`, `private.get_pointers`, `private.call`, ...) — regular local functions bound to `private`.
5. **Dispatcher tables** (`private.relevant_actions`, `private.relevant_pointer_setting`) — `table.freeze({...})` with `enumitem` keys.

Rule: **public names — only in `:new`**. Everything else — `private` + `do` block.

## 9.9. Private Storage

Per-object state is stored **not in object fields**, but via `self:get(sentinel)` / `self:set(sentinel, value)`. Sentinels are `newproxy()`, declared once per class.

Access pattern:

```luau
private.get_pointers = function(of: observer): pointers
    return (of:get(private.pointers) or private.dummy) :: any
end
```

- `private.dummy = dummies.table` — a common "dummy" for cases when `:get` returned `nil`.
- The `:: any` cast is needed because `:get<Y>` returns `Y`, and `Y` depends on the context.

**Never** store private data in `shadow_space` directly if you can get by with `:get`/`:set` with a sentinel. `shadow_space` is for cases when the sentinel approach is insufficient (e.g., for an arbitrary `label: unknown`).

## 9.10. Dispatching via `relevant_*`

Key pattern: instead of `if mode == ConnectionVariant.Ever then ... elseif ...`, a **strategy table** with `enumitem` keys is used:

```luau
private.relevant_actions = table.freeze({
    [ConnectionVariant.Ever] = function(related, ...) ... end,
    [ConnectionVariant.Once] = function(related, ...) ... end,
    [ConnectionVariant.Next] = function(related, ...) ... end,
    [ConnectionVariant.Skip] = function(related, ...) ... end,
})
```

Rules:

1. **`table.freeze`** — mandatory. Strategies must not change at runtime.
2. **All branches are covered** for all possible `enumitem`s from the contract. If a new branch appears, it is added to **all** relevant `relevant_*` tables, otherwise the validator/contract will diverge.
3. **`private.relevant_actions[mode]`** is called without `self`, because the strategy already knows what it is working with (via the `related` context). If `self` is needed, it is passed in `related` or in the arguments.
4. Similarly for `private.relevant_pointer_setting` — a dispatcher by `enumitem_connection_variant` for changing the mode of existing subscriptions.

If the agent needs to add new behavior dependent on `enumitem`, they **add a branch to the existing `relevant_*` table**, and do not write `if/elseif` in the main method.

## 9.11. Conditional Compilation

`--#if <FLAG>` / `--#endif` — preprocessor directives:

- `CORE_CLASS_USEABLE` — class initialization block as an instance.
- `DEBUG` — diagnostic branches (`std:oute(...)`, additional checks).

Rules:

1. **Directives do not affect logic without the flag**; if code "only works with the flag" — it's a bug.
2. `--#if DEBUG` must not contain functionally significant code; only diagnostics.
3. Nested `--#if` are not welcome.
4. Without `--#endif`, the file should not compile.

## 9.12. Style Specifics

1. **`const` instead of `local`** — everywhere the value is not reassigned.
2. **`type(x) == types.function`** — use constants from `@declare/types`, not string literals.
3. **Checking luaobject types** — via `class:that(x, SomeType.type)` or `LuaObject:that(x, SomeType.type)`, **not** via `x.type == "..."` or `typeof(x)`.
4. **`self:as<<T>>(class.type)`** — cast before using the typed `self`.
5. **`std:check`, `std:assert`, `std:oute`** — standard utilities; do not write your own `assert`/`error`/`print` if these exist.
6. **`table.freeze`** — for all immutable strategy tables and constants.
7. **`pcall`** — around any user functions (`observer_var`, `ftype` callbacks), with `std:assert`/`std:oute` on the result.
8. **`coroutine.isyieldable()`** — before `scheduler:wait()`/`task.wait()`.
9. **`Scheduler:whose()`** — before `scheduler:last()`/`scheduler:wait()`; fallback to `task.wait()` only if `scheduler` is not found.
10. **Variadic in `for ... in`** — via `for _, v in { ... } do` (creates a copy), not via `for i = 1, select("#", ...)`.
11. **`table.clone`, `table.move`, `table.clear`, `table.find`** — preferred over manual loops.
12. **`return class`** — the only thing the module returns. Type exports — only in `core.d.luau`.

### 9.12.1. Formatting variants

Two formatting variants are allowed and both are present in the tree. CI does not check formatting, so a file is not rejected for using either of them.

**Variant A — legacy, most files, matches `stylua.toml`:**

```luau
const private = { type = "stack" }
const class: stack = LuaObject:new({
	type = private.type,

	put = ftype:write(function(self: stack, item: any): ()
		-- ...
	end, mtypes.never, private.type, mtypes.anyt),
})
```

- tabs for indentation;
- spaces inside table braces: `{ type = "stack" }`, `{ ... }`;
- `:new({ ... })` with call parentheses;
- `function(self, ...)`;
- `x:as<<T>>(class.type)` without spaces.

**Variant B — used by the newest files (`Character`, `Entity`, `Round`, `Faction`, `StateRegistry`, `Template`):**

```luau
const private = {type = "faction"}
const class : faction = (Observer :: observer<enumitem_faction_notification>):new {
    type = private.type,

    get_member = ftype:write(function (self: faction) : ...character
        -- ...
    end, ftype:var(Character.type), private.type),
}
```

- 4 spaces for indentation;
- no spaces inside braces: `{type = "faction"}`, `{...}`;
- `class : type` and `:new {` without call parentheses;
- `function (self: type) : ReturnType`;
- `x:as <<T>> (class.type)` with spaces;
- `for _, v in {...} do`.

Rules for both variants:

1. Do not reformat an existing file just to switch the variant. If you edit a file, keep its current variant.
2. A new file may use either variant, but must be internally consistent.
3. `stylua.toml` describes only variant A, so `stylua --check src` currently reports many files. Passing `stylua` is not a merge requirement.
4. The mandatory header (`--!strict` and the four `--#include`s) applies to both variants.

### 9.13. Class Building Checklist

- [ ] Are `--!strict` and the 4 mandatory `--#include`s in place?
- [ ] Are imports via `@`-aliases, grouped by layers?
- [ ] Are local `type` aliases declared before `private`?
- [ ] Does `private.type` match `:new({ type = ... })`?
- [ ] Are all public methods wrapped in `ftype:write` with a **complete** signature?
- [ ] Are return types specified (including `mtypes.never`)?
- [ ] Does `:host` cast `new:as<<T>>(class.type)` and initialize all sentinels?
- [ ] Is `private` initialized in the `do` block before first use?
- [ ] Is `--#if CORE_CLASS_USEABLE` present if the class can be used as an instance?
- [ ] Are all `relevant_*` tables `table.freeze`d and cover all `enumitem`s of the contract?
- [ ] Is there `pcall` around user callbacks?
- [ ] Is there `Scheduler:whose()` + `coroutine.isyieldable()` before `wait`?
- [ ] Is there `return class` at the end?
- [ ] Are there no public names outside `:new`?
- [ ] Are there no `if/elseif` by `enumitem` in main methods, only `relevant_*`?
- [ ] Is the file kept in its existing formatting variant (A or B), without wholesale reformatting?

## 9.14 Enum Example

```luau
    --!strict

    --#include <project.gpp>
    --#include <build.gpp>
    --#include <fflag_core.gpp>
    --#include <fflag.gpp>

    const EnumObject = require("@class/core/EnumObject")

    const class: enum_data_notification = EnumObject:new({
        name = script.Name,

        DataStateChanged = EnumObject.build_enumitem_mark, -- The item is created by `EnumObject` itself, with the field name as its name. The type is intentionally lowered to `enumitem<any>` to avoid typing errors; this is not a bug, but a feature. The `enum_*` type will still adjust what is needed, the main thing for it is to have the structure `[k]: item`
        DataLoaded = EnumObject.build_enumitem_mark,
        DataReleased = EnumObject.build_enumitem_mark,
        DataChanged = EnumObject.build_enumitem_mark,
        DataMessage = EnumObject.build_enumitem_mark,
    })

    return class
```

## 9.15 Struct Example

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

# 10. What to Use and in What Situations

This section describes **which primitive from `core.d.luau` to take for which task**, and why. The general rule: if there is already a type in `core.d.luau` for the task — use it, and do not invent your own. If the type is missing — first propose a contract extension, rather than writing an ad-hoc solution.

## 10.1. Choosing the Base Type

| Situation | What to take | Why |
|---|---|---|
| Need any project object | `luaobject` | The only base type, gives RTTI (`type`, `it`, `is`, `as`, `same`, `eq`, `base`, `iden`, `ttype`) |
| Need **data**, not behavior | `struct` | Immutable, `:clone`/`:each`, no hidden state — predictable |
| Need an identifier (role, state, mode, notification) | `enumobject` + `enumitem` | Stable `hashlink`, not a string, not Roblox `Enum`; works with `observer`/`event`/`stateregistry` |
| Need a singleton service with `name`/`enabled` | `service` | Contract `nameable & switchable`; services are registered and managed uniformly |
| Need a resource with release | `disposable` | `:free()`, `:released()`, `:watch()` — unified lifecycle |

**Do not** inherit directly from `{...}` if the object participates in RTTI, is serialized, replicated, or reviewed. Such things are always `luaobject` (directly or via `struct`/`service`/`disposable`).

## 10.2. Storing Values and State

| Situation | What to take | Why |
|---|---|---|
| Store a mutable value and expose it outside by reference | `variable<T>` | Reference type: `:get_value()`/`:set_value()` change the value, everyone sees the change |
| Store a value with subscription to changes, but without reference | `value<T>` | Notifies via `observer<enumitem_operation_variant>`; `:get_value()`/`:set_value()` with `default` |
| LIFO collection with a limit | `stack<T>` | `src/class/common/collection/Stack.luau`; `:pick()`/`:put()`/`:count()`, `max` — built-in |
| FIFO collection with a limit | `queue<T>` | `src/class/common/collection/Queue.luau`; `:pick()`/`:put()`/`:count()`, `max` — built-in |
| Lazy caching | `maybe<T, U>` | `:extract()`, `:enactment()`, `:erase()`, `:exist()` — do not invent `cache[key] = f()` |
| Lazy storage with a template for every new value | `template<T, U>` | `:get_template()`/`:set_template()`, `:allocate_for()`, `:exist_for()`, `:free_for()`; notifies via `observer<enumitem_operation_variant>` |
| Registry of active states | `stateregistry<T>` | `src/class/common/StateRegistry.luau`; `:get_state()`, `:set_state()`, `:blacklist()`, notifications via `enumitem_statemachine_notification` |

> `quant<T>` is still declared in `core.d.luau`, but has no implementation: do not use it in new code and do not reimplement it without an explicit request (see section 7).

**Do not** use `value` where a reference is needed (you need `variable`), and **do not** use `variable` where notifications are needed (you need `value` or `observer`). The difference is semantic: `variable` is a "cell", `value` is an "event source + value".

## 10.3. Indirection and References

| Situation | What to take | Why |
|---|---|---|
| Weak reference to "something" with control | `pointer<T>` | `:get_pointed()`, `:set_point()`, `:is_pointed_exists()`, `:is_pointed_hard()` — used in `observer` for `unsubscribe` |
| Wrapper over Roblox `Instance` with events | `reference<T>` | `:call_function()`, `:call_methode()`, `:read_field()`, `:write_field()`, `:has_field()` + `observer<enumitem_reference_notification>` |
| Path to `Instance` when a direct reference is undesirable | `path` | `:get_by_absolute_path()`, `:get_by_relative_path()`, `:get_by_path_or_nil()`, `spoof` modes |

**Do not** keep `Instance` directly if it can disappear — take `reference`. **Do not** do manual `FindFirstChild` traversal — take `path`. **Do not** replace `pointer` with a regular container table: `pointer` knows `is_pointed_exists`, `pointer` is weak-compatible.

## 10.4. Notifications and Subscriptions

| Situation | What to take | Why |
|---|---|---|
| Internal bus with fine control | `observer<T>` | Basic `:subscribe()`/`:unsubscribe()`/`:notificate()`; `deferred_call`, `deferred_mode`, `allow_new_connections` |
| User "event" with `connect`/`once`/`wait`/`invoke` | `event<T, U...>` | Convenient API over `observer`, `:wait()` — blocking, `:invoke()`/`:invoke_deferred()` |
| Subscription handle, manual unsubscribe | `connection<T, U...>` | `:disconnect()`, `:set_mode()`, `:is_connected()`, `:get_mode()` |
| Wrapper over Roblox `RBXScriptSignal` | `signal<T...>` | `:get_signal_event()`, `:set_signal_source()`, `:apply_as_source()`, `use_parallel_signals` |
| Auto-binding classes to `Instance` by tag | `binder<T>` | `:start()`/`:stop()`, `ancestors`, `maker`; notifications `BinderNotification.Bound`/`Unbound` |

**Do not** write your own `signal`-like mechanism: `observer`/`event` already cover 95% of cases. **Do not** subscribe directly to `RBXScriptSignal` in the core — wrap it in `signal`.

## 10.5. Lifecycle, Time, Scheduling

| Situation | What to take | Why |
|---|---|---|
| One releasable resource | `disposable` | `:free()`, `:released()`, `:watch()` — single release point |
| Set of releasable resources | `maid` | `:add_object()`, `:add_key()`, `:remove_object()`, `:remove_key()`, `:is_supported()`; `maid` itself is `disposable` |
| "Run" management | `controller` | `:continue()`, `:pause()`, `:reset()` + `enumitem_controller_state` |
| Timer with step | `timer` | `:get_elapsed()`, `:get_remaining()`, `:set_duration()`, `:set_step()` + `enumitem_tick_notification` |
| Scheduled coroutine | `scheduler` | `:plan()`, `:cancel()`, `:wait()`, `:hold()`, `:last()`, `:next()`, `:process()` |
| Track deletion of objects and attach finalizers | `heap` | `:register()`, `:unregister()`, `:finally()` — a GCTracker-style pool; `Maid`/`Maybe`/`Template` build on it |
| PID-style physical control | `kinematiccontroller<T>`, `pcontroller<T>`, `picontroller<T>`, `pdcontroller<T>`, `pidcontroller<T>` | `:apply_error()`, `:apply_measurement()`, `:get_output()`, `:get_error()`, `:reset()`; used by `entity` for movement, height and rotation |

**Do not** use `task.wait`/`task.spawn` if the class already implements `scheduler` — they conflict. **Do not** keep a reference to a resource without `disposable`/`maid` if the resource requires release.

## 10.6. Network

| Situation | What to take | Why |
|---|---|---|
| Client↔server transport | `sharednet` + `netpack` | `:get_event()`, `:emit_event()`; `netpack:pack()`, `:payload()`, `:get_flat()`, `:get_players()`, `:get_source()`, `:is_me_sender()` |
| Player data (server) | `dataserver` | `:start()`, `:get_data()`, `:wait_data()`, `:get_value()`, `:set_value()`, `:update_value()`, `:reset()`, `:send_message()`, `:get_data_event()` |
| Player data (client) | `dataclient` | `:start()`, `:get_state()`, `:get_value()`, `:wait_loaded()`, `:get_data_event()` |
| RPC to another machine | `remotecall` | Single point of remote call |

**Do not** send packets manually via `RemoteEvent` — use `sharednet`. **Do not** write from the client to `dataserver` — only `dataclient` (read-only). **Do not** use `dataserver:set_value` for replicable keys bypassing `update_value` — otherwise replication will diverge.

## 10.7. Geometry

| Situation | What to take | Why |
|---|---|---|
| Orientation + position in space | `basis` | `:basis_to_world/local`, `:point_to_world/local`, `:slerp`, `:inverse_basis`, `:get_components`/`:from_components` |
| Axis-aligned box | `aabbvolume` | `min`/`max`, `half`, `:is_inside`, `:is_intersection`, `:look_at` |
| Oriented box | `obbvolume` | Same + `:rotate_radian`, `:get_rotation_radian` |
| Cubic volume | `cubevolume` | `:up/:bottom/:left/:right/:front/:back`, `:get_corners`, `:get_axises`, `:get_quad`, `:get_sat_axises` |
| Polygon / face | `triangle`, `quad` | `:from_vector`, `:get_normal_geometric`, `:get_normal_interpolated` |
| Ordered axes | `directions` | `axisable` + `vector_operations` |

**Do not** calculate orientation manually via `CFrame` — take `basis`. **Do not** write manual SAT checks — take `geometry_check` from the corresponding volume. `spherevolume`, `conevolume`, `capsulevolume` and `tetavolume` are declared in `core.d.luau`, but are not implemented and are not part of `geometry_volume` — **do not** implement them without an explicit request and contract update (see section 7).

## 10.8. Game Entities

| Situation | What to take | Why |
|---|---|---|
| Game domain: round, factions | `round`, `faction` | `src/class/game/control/`; `:get_members()`, `:add_member()`, `:rem_member()`, `:is_member()`, `:has_faction()`; `round` — `timer` + `stateregistry` |
| Logical "character" entity | `character` | `:get_token()`, `:get_parameter()`, `:has_parameter()`, `:get_abilities()`, `:get_inventory()`, `:get_model_reference()`; `informable<characterinfo>` |
| Physical entity (movement, physics) | `entity` | `src/class/game/character/Entity.luau`; `disposable`, wraps `reference`/`kinematiccontroller`, has `enabled`, `up_direction`, `move_direction`, `jump`, `walk_speed`, `jump_power`, `hip_height`, `floor_reach`, `auto_rotate`, `lock_rotation_x` |
| Ability | `ability` + `abilityinfo` | `:activate()`, `:cooldown()`; `abilityinfo` — balance package (`has_*`, `cooldown`, `stun`, `recoil`, `kickback`, `slow`, `*_time`) |
| Inventory | `inventory` + `itemstack` + `itemobject` | `inventory` — `max` + `list_*` + `:get_stacks()`; `itemstack`/`itemobject` — "stack" and "unique" variants, both extend `iteminstance` |
| Item description | `item` | Singleton: `max`, `count`, `description`, `behavior`, `:get_stack()` |
| Item behavior | `itembehavior` + `itemcontext` | `:on_equip`, `:on_unequip`, `:on_take`, `:on_drop`, `:action` |
| Player profile | `profile<T>` | `:get_player()`, `:get_joined_at()`, `:get_last_seen_at()`, `:get_permissions()`, `:get_restrictions()`, `:has_platform()`, `:is_banned()`, `:is_kicked()` |

**Do not** replace `character` with a direct `Humanoid` in game logic — `character` does not depend on the control method. **Do not** store items directly in `inventory`: only `itemstack`/`itemobject`. **Do not** write item behaviors outside `itembehavior` — otherwise `:action` will not see `itemcontext`.

## 10.9. IK

| Situation | What to take | Why |
|---|---|---|
| R6 solver | `ikr6legs`, `ikr6arms`, `ikr6heads` | Automated solvers; each is `initiable` and manages its own `ikr6limb` |
| Single limb | `ikr6limb`, `ikr6foot`, `ikr6arm`, `ikr6head` | `:get_fake()`, `:get_limb_target()`, `:get_limb_pole()`, `:get_limb_facing()`, `:is_moving_finished()` |
| Solver configuration | `ikr6info`, `ikr6leginfo`, `ikr6arminfo`, `ikr6limbinfo` | Setup packages in `src/class/struct/game/IKR6*Info.luau`; used via `informable` |

**Do not** write your own IK — take `ikr6*`. **Do not** store solver settings in fields — use `*info` via `informable`. IK classes are marked as "support not guaranteed" (R6) — edits require coordination.

## 10.10. Return Values

| Situation | What to take | Why |
|---|---|---|
| Function returns "success/result" | `result<T, U...>` | `:state`, `:result`, `:unpack` — instead of `(boolean, T?)` |
| Network packet on the wire | `netpack` / `netpack_flat` | `netpack:get_flat()` — wire format, `netpack_flat` — flat table |

**Do not** return `(boolean, string | nil)` from public APIs — take `result`. **Do not** serialize `netpack` manually — use `:get_flat()`/`:from_flat()`.

## 10.11. Mixin Interfaces

Use for their intended purpose, not "just in case":

| Interface | When |
|---|---|
| `nameable` | Object has a name (service, faction, item) |
| `switchable` | Object can be turned on/off (`enabled`) |
| `operatable` | Need `continue`/`pause`/`reset` |
| `controllable` | Object has a `controller` (`:get_control()`) |
| `instanceable` | Object is tied to one Roblox `Instance` |
| `referenceable` | Object is tied to a `reference` (`:get_reference()`) |
| `disposable` | Object releases resources |
| `private_storage` | Need `:get`/`:set` by `label` |
| `invokeable` | Object is callable (`:invoke`) |
| `asyncable` | Object makes network/async attempts (`time_to_hold`, `time_to_response`, `attempts`) |
| `stateable<T, U>` | Object has a state machine (`:get_states()`) |
| `informable<T, U>` | Object has an `*info` package (`:get_info()`/`:set_info()`) |
| `initiable` | Object has an initialization phase (`:is_initiated()`) |
| `loopable` | Object has a loop (`:get_loop()`) |
| `reloadable` | Object can be reloaded (`:reload()`) |
| `modifier<T>` | Object has a modifier |
| `iterations<T>` | Object is iterable |
| `list_checks` | Object is a collection; need `is_full`/`is_empty`/`is_half` |
| `list_operations<T, U...>` | Object is a collection; need `clear`/`count`/`length`/`adjust`/`insert`/`remove`/`collect`/`find` |
| `math_operations` | Object is number-like (`multiple`, `divide`, `lerp`, `fuzzy_eq`, ...) |
| `vector_operations` | Object converts to `basis`/`vector` |
| `positioned`, `rotateable`, `centerable`, `normal`, `normals`, `axisable` | Geometric guarantees |
| `geometry_check`, `geometry_control`, `geometry_rotatable`, `geometry_convertation`, `geometry_half` | Geometric operations |
| `I_targetable<T, U>` | Object has a target (`:set_target()`/`:get_target()`) |
| `expected_calltype<T>` | Subscription knows its expected type |
| `loopable`/`iterations`/`modifier`/`reloadable` | Only if the contract is really needed, not "just to have it" |

**Do not** mix in interfaces "for completeness": each adds fields/methods that will have to be implemented and reviewed. Take exactly the set that describes the object's behavior.

## 10.12. Notifications `enum_*_notification`

Choosing a notification = choosing what the object reacts to. Use existing ones:

- `enum_setup_notification` — installation/connection phases (`Install`, `Installed`, `Require`, `Disconnected`).
- `enum_tick_notification` — timer lifecycle (`Started`, `Stepped`, `Paused`, `Resumed`, `Finished`).
- `enum_operation_variant` — `New`/`Change`/`Remove`.
- `enum_reference_notification` — `NewInstance`/`ChangedInstance`/`DestroyedInstance`/`NullifiedInstance`.
- `enum_binder_notification` — `Bound`/`Unbound`.
- `enum_net_notification` — `Received`.
- `enum_data_notification` — `DataStateChanged`/`DataLoaded`/`DataReleased`/`DataChanged`/`DataMessage`.
- `enum_shared_net_variant` — `Unsafe`/`Safe`/`Internal`.
- `enum_net_source` — `FromServer`/`FromMe`/`FromClient`.
- `enum_controller_state`, `enum_round_state`, `enum_state`, `enum_data_state`, `enum_iklegs_state` — states.
- `enum_item_context` — `Primary`/`Secondary`/`Cycle`/`Special` (for `itemcontext`).
- `enum_item_notification` — item lifecycle (`Equip`/`Unequip`/`Take`/`Drop`/`Action`).
- `enum_list_notification` — list changes (`AddedElement`/`RemovedElement`/`ListFull`/`ListEmpty`/`ListHalf`).
- `enum_character_parameter_variant` — character parameters.
- `enum_action_map_variant` — actions for the future `InputMap`.
- `enum_input_notification` — input pipeline (`CodeAdded`/`CodeRemoved`/`Pressed`/`Clamped`/`Stopped`/`RelatedChanged`/`RelatedNullified`/`NetworkEnabled`/`NetworkDisabled`).
- `enum_executor_notification` — executor phases (`Process`/`Simulation`).
- `enum_statemachine_notification` — `ChangedState`/`NewState`/`BlacklistAdded`/`BlacklistRemoved` (used by `stateregistry`).
- `enum_disposable_notification` — `OnRelease`/`Released`.
- `enum_faction_notification` — `MemberJoined`/`MemberRemoved`.
- `enum_ability_notification` — ability phases.
- `enum_user_notification` — profile events (`ServerJoin`/`ServerExit`/`ServerBan`/`ServerKick`/`ServerDataRequest`).
- `enum_user_data_require` — profile data keys (`UserProfile`/`UserLastDataSave`/`UserLastDataRequest`/`UserPlayedTime`/`UserLastEnter`/`UserPreviousKick`/`UserPreviousBan`).
- `enum_data_internal_variant` — internal data transport (`DataSnapshot`/`DataSet`/`DataReady`/`DataRequest`/`DataExit`).
- `enum_direction_variant`, `enum_collision_variant`, `enum_asset_type_variant`, `enum_physx_mode_variant`, `enum_user_machine_variant`, `enum_shared_net_link` — domain variants.

**Do not** introduce a new notification if an existing one is sufficient. If a new one is really needed — it is added to `src/enums/notification/**` and to `core.d.luau`, otherwise the validator will not see it.

## 10.13. Summary Rule of Choice

1. **First look for a ready type** in `core.d.luau`. 90% of tasks are already covered.
2. **If the type exists but does not fit semantically** — consider a neighbor (`variable` vs `value`, `pointer` vs `reference`, `event` vs `signal`, `aabb` vs `obb`).
3. **If there is no type** — first propose an extension to `core.d.luau` (plus `src/static/**` and, if necessary, `src/enums/**`), then the implementation.
4. **Do not mix layers:** `struct` for data, `service` for singletons, `disposable` for resources, `observer` for notifications.
5. **Do not duplicate:** if the project already has `scheduler`, `signal`, `maid`, `pointer`, `observer`, `sharednet`, `dataserver`, `heap`, `queue`, `stateregistry` — use them, even if "your own" seems simpler.
6. **Coordinate** if the task requires touching someone else's area according to `CODEOWNERS`, implementing a type that is declared but not implemented in the contract, or changing the public API.