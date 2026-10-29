--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage:FindFirstChild("DevPackages"):FindFirstChild("JestGlobals"))
local describe, expect, it, jest = JestGlobals.describe, JestGlobals.expect, JestGlobals.it, JestGlobals.jest

local core = ReplicatedStorage:FindFirstChild("core") or error("ReplicatedStorage.core is missing in the test place", 0)

local engine = core:FindFirstChild("platform"):FindFirstChild("roblox"):FindFirstChild("engine")
jest.mock(engine, function()
	local isolated = table.clone(jest.requireActual(engine))
	isolated.on_script_error = Instance.new("BindableEvent").Event
	return isolated
end)

export type class_spec = {
	type: string,
	module: string,
	bases: { string },
	methods: { string },
}

export type enum_spec = {
	type: string,
	module: string,
	items: { string },
	methods: { string },
}

export type enumitem_spec = {
	type: string,
	enum: string,
	module: string,
}

export type mixin_spec = {
	type: string,
	methods: { string },
	implementers: { { type: string, module: string } },
}

export type pending_spec = {
	type: string,
	reason: string,
}

local contract = {}

local function find(path: string): ModuleScript
	local current: Instance = core
	for segment in string.gmatch(path, "[^/]+") do
		local child = current:FindFirstChild(segment)
		if not child then
			error(`module {path} not found in the test place`, 0)
		end
		current = child
	end
	return current :: ModuleScript
end

local function loader(path: string): () -> any
	local loaded, ok, result = false, false, nil
	return function()
		if not loaded then
			loaded = true
			ok, result = pcall(function()
				return require(find(path))
			end)
		end
		if not ok then
			local reason = if type(result) == "table" then `{result.message or ""}\n{result.stack or ""}` else tostring(result)
			error(`require {path} failed: {reason}`, 0)
		end
		return result
	end
end

local function expect_methods(get: () -> any, methods: { string })
	for _, method in methods do
		it(`has method {method}`, function()
			expect(typeof(get()[method])).toBe("function")
		end)
	end
end

local function expect_rtti(get: () -> any, otype: string, bases: { string })
	it("loads", function()
		expect(get()).toEqual(expect.any("table"))
	end)

	it(`it/is("{otype}")`, function()
		local class = get()
		expect(class:it(otype)).toBe(true)
		expect(class:is(otype)).toBe(true)
	end)

	for _, base in bases do
		it(`is("{base}")`, function()
			expect(get():is(base)).toBe(true)
		end)
	end
end

function contract.class(spec: class_spec)
	describe(spec.type, function()
		local get = loader(spec.module)

		it(`type == "{spec.type}"`, function()
			expect(get().type).toBe(spec.type)
		end)

		expect_rtti(get, spec.type, spec.bases)
		expect_methods(get, spec.methods)
	end)
end

function contract.enum(spec: enum_spec)
	describe(spec.type, function()
		local get = loader(spec.module)

		expect_rtti(get, "enumobject", { "luaobject" })
		expect_methods(get, spec.methods)

		it(`has exactly the {#spec.items} declared items`, function()
			local names = {}
			for name in get():get_enums_list() do
				table.insert(names, tostring(name))
			end
			table.sort(names)
			expect(names).toEqual(spec.items)
		end)

		for _, name in spec.items do
			it(`item {name}`, function()
				local enum = get()
				local item = enum[name]

				expect(item).never.toBeNil()
				expect(item:is("enumitem")).toBe(true)
				expect(item.name).toBe(name)
				expect(item.enum).toBe(enum)
				expect(item.hashlink).toEqual(expect.any("string"))
				expect(enum:is_my_enumitem(item)).toBe(true)
				expect(enum:get_enum_by_name(name)).toBe(item)
				expect(enum:get_enum_by_hashlink(item.hashlink)).toBe(item)
			end)
		end
	end)
end

function contract.enumitem(spec: enumitem_spec)
	describe(spec.type, function()
		local get = loader(spec.module)

		it(`every item of {spec.enum} is an enumitem of that enum`, function()
			local enum = get()
			local count = 0

			for _, item in enum:get_enums_list() do
				count += 1
				expect(item:it("enumitem")).toBe(true)
				expect(item.enum).toBe(enum)
				expect(enum:is_my_enumitem(item)).toBe(true)
			end

			expect(count).toBeGreaterThan(0)
		end)

		it("item hashlinks are unique", function()
			local seen = {}
			for name, item in get():get_enums_list() do
				expect(seen[item.hashlink]).toBeNil()
				seen[item.hashlink] = name
			end
		end)
	end)
end

function contract.mixin(spec: mixin_spec)
	describe(spec.type, function()
		for _, implementer in spec.implementers do
			describe(`in {implementer.type}`, function()
				expect_methods(loader(implementer.module), spec.methods)
			end)
		end
	end)
end

function contract.pending(spec: pending_spec)
	describe(spec.type, function()
		it.todo(spec.reason)
	end)
end

return contract
