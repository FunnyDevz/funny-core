--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TIMEOUT = 10

return function(jest)
	local core = ReplicatedStorage:FindFirstChild("core")
		or error("ReplicatedStorage.core is missing in the test place", 0)

	local function find(path: string): ModuleScript
		local current: Instance = core
		for segment in string.gmatch(path, "[^/]+") do
			current = current:FindFirstChild(segment) or error(`module {path} not found in the test place`, 0)
		end
		return current :: ModuleScript
	end

	local harness = { calls = {} }
	local roster = {}
	local added = {}
	local next_user_id = 0
	local mocked_engine = nil

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

	local function new_store(name: string, template)
		local store = {}

		function store.StartSessionAsync(_, key)
			table.insert(harness.calls, { store = name, method = "StartSessionAsync", key = key })

			local profile = {
				Data = deep_copy(template),
				OnSessionEnd = {
					Connect = function() end,
				},
			}

			function profile.AddUserId() end
			function profile.Reconcile() end
			function profile.MessageHandler() end
			function profile.EndSession() end

			return profile
		end

		function store.MessageAsync(_, key)
			table.insert(harness.calls, { store = name, method = "MessageAsync", key = key })
		end

		return store
	end

	local engine = find("platform/roblox/engine")
	jest.mock(engine, function()
		local isolated = table.clone(jest.requireActual(engine))
		isolated.is_server = true
		isolated.is_studio = false
		isolated.on_script_error = Instance.new("BindableEvent").Event
		mocked_engine = isolated
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
			on_added = function(f)
				table.insert(added, f)
				return { Disconnect = function() end }
			end,
			on_removing = function()
				return { Disconnect = function() end }
			end,
			kick = function() end,
		}
	end)

	jest.mock(find("vendor/include/ProfileStore"), function()
		return {
			New = function(_, template)
				local live = new_store("live", template)
				live.Mock = new_store("mock", template)
				return live
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

	harness.DataServer = require(find("class/service/DataServer"))

	if not mocked_engine then
		error("DataServer did not require the mocked engine", 0)
	end

	local function used(method: string, key: string): string?
		local deadline = os.clock() + TIMEOUT
		while os.clock() < deadline do
			for _, call in harness.calls do
				if call.method == method and call.key == key then
					return call.store
				end
			end
			task.wait()
		end
		return nil
	end

	function harness.set_studio(value: boolean)
		mocked_engine.is_studio = value
	end

	function harness.load(): string?
		next_user_id += 1
		local player = { Name = `player{next_user_id}`, UserId = next_user_id }
		roster[player] = true

		for _, f in added do
			task.spawn(f, player)
		end

		return used("StartSessionAsync", harness.DataServer:get_env().key(player.UserId))
	end

	function harness.message(): string?
		next_user_id += 1
		local user_id = next_user_id

		harness.DataServer:send_message(user_id, { text = "hello" })
		return used("MessageAsync", harness.DataServer:get_env().key(user_id))
	end

	return harness
end
