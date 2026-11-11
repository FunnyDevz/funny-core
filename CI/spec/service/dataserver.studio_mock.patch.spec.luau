--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage:FindFirstChild("DevPackages"):FindFirstChild("JestGlobals"))
local describe, expect, it, jest, beforeAll =
	JestGlobals.describe, JestGlobals.expect, JestGlobals.it, JestGlobals.jest, JestGlobals.beforeAll

local harness = require("./dataserver_store")(jest)
local DataServer = harness.DataServer

describe("dataserver.studio_mock with a patch", function()
	beforeAll(function()
		DataServer:set_env({ store = "test", studio = { mock = true } })
		DataServer:start()
	end)

	it("merges the patch into the default env", function()
		local env = DataServer:get_env()
		expect(env.studio.mock).toBe(true)
		expect(env.store).toBe("test")
		expect(env.template.user).never.toBeNil()
		expect(env.key(1)).toBe("player_1")
	end)

	it("uses store.Mock in Studio", function()
		harness.set_studio(true)
		expect(harness.load()).toBe("mock")
		expect(harness.message()).toBe("mock")
	end)

	it("uses the live store outside Studio", function()
		harness.set_studio(false)
		expect(harness.load()).toBe("live")
		expect(harness.message()).toBe("live")
	end)
end)
