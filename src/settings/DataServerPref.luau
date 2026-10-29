const engine = require("@platform/roblox/engine")

export type template = {
    read settings: {[unknown]: unknown},
    read stats: {[unknown]: unknown}
}

const template: template = {
    settings = {},
    stats = {},
}

return {
    --[=[
		DataStore name. Changing it starts every player from the template
	]=]
    store = "PlayerData",

    --[=[
		Profile key of a player
	]=]
    key = function(id: number): string
        return `player_{id}`
    end,

    template = template,

	--[=[
		Top-level keys sent to the owner client, everything else stays on the server
	]=]
    replicating = table.freeze({
        settings = true,
        stats = true,
    }),

    studio = table.freeze({
        --[=[
			Use ProfileStore.Mock in Studio: data lives only for the session and nothing is saved.
			false: Studio saves to the real store (needs Game Settings -> Security -> Enable Studio Access to
			API Services), so the base and inventory survive between play tests and places
		]=]
        mock = engine.is_studio
    }),
}