--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage:FindFirstChild("DevPackages"):FindFirstChild("JestGlobals"))
local describe, expect, it, jest, beforeAll =
	JestGlobals.describe, JestGlobals.expect, JestGlobals.it, JestGlobals.jest, JestGlobals.beforeAll

local core = ReplicatedStorage:FindFirstChild("core") or error("ReplicatedStorage.core is missing in the test place", 0)

local function find(path: string): ModuleScript
	local current: Instance = core
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment) or error(`module {path} not found in the test place`, 0)
	end
	return current :: ModuleScript
end

local TIMEOUT = 10

local roster = {}
local added = {}
local removing = {}
local gates = {}
local next_user_id = 0

local function deep_copy(from)
	if type(from) ~= "table" then
		return from
	end

	local copy = {}
	for k, v in from do
		copy[k] = deep_copy(v)
	end
	return copy
end

local function fire(list, player)
	for _, f in list do
		task.spawn(f, player)
	end
end

local function signal(list)
	return function(f)
		table.insert(list, f)
		return {
			Disconnect = function()
				table.remove(list, table.find(list, f) or 0)
			end,
		}
	end
end

local engine = find("platform/roblox/engine")
jest.mock(engine, function()
	local isolated = table.clone(jest.requireActual(engine))
	isolated.is_server = true
	isolated.is_studio = false
	isolated.on_script_error = Instance.new("BindableEvent").Event
	return isolated
end)

jest.mock(find("platform/roblox/players"), function()
	return {
		get_by_user_id = function(user_id)
			for player in roster do
				if player.UserId == user_id then
					return player
				end
			end
			return nil
		end,
		get_local = function()
			return nil
		end,
		get_all = function()
			local list = {}
			for player in roster do
				table.insert(list, player)
			end
			return list
		end,
		is_in_game = function(player)
			return roster[player] == true
		end,
		on_added = signal(added),
		on_removing = signal(removing),
		kick = function() end,
	}
end)

jest.mock(find("vendor/include/ProfileStore"), function()
	return {
		New = function(_, template)
			return {
				StartSessionAsync = function(_, key, params)
					while not gates[key] do
						if params and params.Cancel and params.Cancel() then
							return nil
						end
						task.wait()
					end

					local ended = {}
					local profile = {
						Data = deep_copy(template),
						OnSessionEnd = {
							Connect = function(_, f)
								table.insert(ended, f)
							end,
						},
					}

					function profile.AddUserId() end
					function profile.Reconcile() end
					function profile.MessageHandler() end
					function profile.EndSession()
						for _, f in ended do
							task.spawn(f)
						end
					end

					return profile
				end,
			}
		end,
	}
end)

jest.mock(find("class/service/SharedNet"), function()
	return {
		get_event = function()
			return {
				connect = function() end,
			}
		end,
		emit_event = function() end,
	}
end)

local DataServer = require(find("class/service/DataServer"))
local DataState = require(find("enums/state/DataState"))

local function new_player(name: string)
	next_user_id += 1
	return { Name = name, UserId = next_user_id }
end

local function key(player)
	return `player_{player.UserId}`
end

local function enter(player)
	roster[player] = true
end

local function leave(player)
	roster[player] = nil
	fire(removing, player)
end

local function wait_data(player)
	local box = { done = false }
	task.spawn(function()
		box.value = DataServer:wait_data(player)
		box.done = true
	end)
	return box
end

local function settle(condition: () -> boolean): boolean
	local deadline = os.clock() + TIMEOUT
	while not condition() and os.clock() < deadline do
		task.wait()
	end
	return condition()
end

local function frames(count: number)
	for _ = 1, count do
		task.wait()
	end
end

describe("dataserver.wait_data", function()
	it("returns nil before start", function()
		local player = new_player("early")
		enter(player)

		expect(DataServer:wait_data(player)).toBeNil()
		roster[player] = nil
	end)

	describe("after start", function()
		beforeAll(function()
			DataServer:set_env({ store = "test", template = { coins = 7 } })
			DataServer:start()
		end)

		it("waits when called before player_added and ignores other players", function()
			local player = new_player("before")
			local other = new_player("other")
			enter(player)

			local box = wait_data(player)
			frames(5)
			expect(box.done).toBe(false)

			enter(other)
			gates[key(other)] = true
			fire(added, other)
			expect(settle(function()
				return DataServer:get_state(other) == DataState.ProfileLoaded
			end)).toBe(true)
			frames(5)
			expect(box.done).toBe(false)

			gates[key(player)] = true
			fire(added, player)

			expect(settle(function()
				return box.done
			end)).toBe(true)
			expect(box.value).never.toBeNil()
			expect(box.value.coins).toBe(7)
		end)

		it("waits while the profile is loading", function()
			local player = new_player("loading")
			enter(player)
			fire(added, player)

			expect(settle(function()
				return DataServer:get_state(player) == DataState.ProfileLoading
			end)).toBe(true)

			local box = wait_data(player)
			frames(5)
			expect(box.done).toBe(false)

			gates[key(player)] = true

			expect(settle(function()
				return box.done
			end)).toBe(true)
			expect(box.value).never.toBeNil()
			expect(box.value.coins).toBe(7)
		end)

		it("returns nil when the player leaves before player_added", function()
			local player = new_player("gone-early")
			enter(player)

			local box = wait_data(player)
			frames(5)
			expect(box.done).toBe(false)

			leave(player)

			expect(settle(function()
				return box.done
			end)).toBe(true)
			expect(box.value).toBeNil()
			expect(DataServer:get_state(player)).toBe(DataState.ProfileReleased)
		end)

		it("returns nil when the player leaves while the profile is loading", function()
			local player = new_player("gone-loading")
			enter(player)
			fire(added, player)

			expect(settle(function()
				return DataServer:get_state(player) == DataState.ProfileLoading
			end)).toBe(true)

			local box = wait_data(player)
			frames(5)
			expect(box.done).toBe(false)

			leave(player)

			expect(settle(function()
				return box.done
			end)).toBe(true)
			expect(box.value).toBeNil()
		end)

		it("returns nil after the player left", function()
			local player = new_player("gone")
			enter(player)
			gates[key(player)] = true
			fire(added, player)

			expect(settle(function()
				return DataServer:get_state(player) == DataState.ProfileLoaded
			end)).toBe(true)

			leave(player)

			expect(DataServer:wait_data(player)).toBeNil()
		end)
	end)
end)
