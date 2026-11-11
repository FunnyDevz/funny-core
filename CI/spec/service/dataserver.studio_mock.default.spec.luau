--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage:FindFirstChild("DevPackages"):FindFirstChild("JestGlobals"))
local describe, expect, it, jest, beforeAll =
	JestGlobals.describe, JestGlobals.expect, JestGlobals.it, JestGlobals.jest, JestGlobals.beforeAll

local harness = require("./dataserver_store")(jest)
local DataServer = harness.DataServer

describe("dataserver.studio_mock by default", function()
	it("keeps studio.mock off in the default env", function()
		expect(DataServer:get_env().studio.mock).toBe(false)
	end)

	describe("after start", function()
		beforeAll(function()
			DataServer:set_env({ store = "test" })
			DataServer:start()
		end)

		it("keeps studio.mock off after a patch without studio", function()
			expect(DataServer:get_env().studio.mock).toBe(false)
		end)

		it("uses the live store in Studio", function()
			harness.set_studio(true)
			expect(harness.load()).toBe("live")
			expect(harness.message()).toBe("live")
		end)

		it("uses the live store outside Studio", function()
			harness.set_studio(false)
			expect(harness.load()).toBe("live")
			expect(harness.message()).toBe("live")
		end)
	end)
end)
