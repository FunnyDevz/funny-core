--!strict
const Struct = require("@game/ReplicatedStorage/class/core/Struct")
const NetSource = require("@game/ReplicatedStorage/enums/descriptor/NetSource")
const engine = require("@game/ReplicatedStorage/platform/engine")
const players = require("@game/ReplicatedStorage/platform/players")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: netpack = Struct:new({
	type = "netpack",
	loaded = {} :: { any },
	count = 0,
	to = {} :: { number },
	from = "",
	sender = nil :: number?,
	rpc = false,

	pack = ftype:write(function(self: netpack, to: { Player | number }?, ...: any): netpack
		return self:new({
			to = to or {},
			loaded = { ... },
			count = select("#", ...),
		}) :: any
	end, "netpack", "netpack", ftype:opt(declare.table), ftype:var_opt(declare.anyt)),

	from_flat = ftype:write(function(self: netpack, flat: unknown): netpack?
		if type(flat) ~= declare.table then
			return nil
		end

		const raw = flat :: { [string]: unknown }
		if type(raw.loaded) ~= declare.table then
			return nil
		end

		const to = {}
		if type(raw.to) == declare.table then
			for k, v in raw.to :: { unknown } do
				if type(v) == declare.number then
					table.insert(to, v :: number)
				end
			end
		end

		const count = if type(raw.count) == declare.number then math.clamp(math.floor(raw.count :: number), 0, project.max_send_packet) else 0

		return self:new({
			loaded = raw.loaded,
			count = count,
			to = to,
			from = if type(raw.from) == declare.string then raw.from else NetSource.FromClient.name,
			sender = if type(raw.sender) == declare.number then raw.sender else nil,
			rpc = raw.rpc == true,
		}) :: any
	end, ftype:opt("netpack"), "netpack", declare.anyt),

	payload = ftype:write(function(self: netpack): ...any
		return table.unpack(self.loaded, 1, self.count)
	end, ftype:var_opt(declare.anyt), "netpack"),

	get_flat = ftype:write(function(self: netpack): netpack_flat
		return {
			loaded = self.loaded,
			count = self.count,
			to = self.to,
			from = self.from,
			sender = self.sender,
			rpc = self.rpc,
		}
	end, declare.table, "netpack"),

	get_players = ftype:write(function(self: netpack): { Player }
		const result = {}

		for k, v in self.to do
			const player = players.get_by_user_id(v)

			if player then
				table.insert(result, player)
			else
				project.console_out(`netpack target {v} isn't in the game`)
			end
		end

		return result
	end, declare.table, "netpack"),

	get_source = ftype:write(function(self: netpack): enumitem_net_source?
		return NetSource:get_enum_by_name(self.from) :: any
	end, ftype:opt("enumitem"), "netpack"),

	is_me_sender = ftype:write(function(self: netpack): boolean
		if engine.is_server then
			return self.sender == nil and self.from ~= NetSource.FromClient.name
		end

		return self.sender == private.local_user_id() and self.from ~= NetSource.FromServer.name
	end, declare.boolean, "netpack"),
})

class:host(function(new)
	const this = new :: any

	this.loaded = table.clone(this.loaded)

	if this.from == "" then
		this.from = NetSource:get_enum_by_current_machine().name
	end

	if this.sender == nil and not engine.is_server then
		this.sender = private.local_user_id()
	end

	const to = {}
	for k, v in this.to :: { Player | number } do
		if typeof(v) == declare.roblox.Instance and (v :: Instance):IsA("Player") then
			table.insert(to, (v :: Player).UserId)
		elseif type(v) == declare.number then
			table.insert(to, v :: number)
		else
			project.console_out("unexpected netpack target", v)
		end
	end
	this.to = to
end)

do
	function private.local_user_id(): number?
		const player = players.get_local()
		return if player then player.UserId else nil
	end
end

return class
