const Cryptography = require("@import/Cryptography")
export type stdrun = {
    read is_parallelable: boolean,
    read luau_virtual_machine_mark: string,

    read get_luau_universal_name: (self: stdrun, with: string) -> string,
    read is_parallel: (self: stdrun) -> boolean,
    
}

const stdrun: stdrun = {
    is_parallel = function ()
        const r, _ = pcall(function(...)
            const t = Instance.new "BoolValue"
            t.Parent = workspace
            t:Destroy()
        end)

        return r
    end,

    is_parallelable = pcall(function(...)
        task.desynchronize()
        task.synchronize()
    end),

    get_luau_universal_name = function (self: stdrun, name: string) : string
        return `{self.luau_virtual_machine_mark} :: @{name}`
    end,

    luau_virtual_machine_mark = Cryptography.Hashing.Blake3.Digest(buffer.fromstring((tostring(tick() + math.random(1, 10000)))), 8)
}

table.freeze(stdrun)
return stdrun