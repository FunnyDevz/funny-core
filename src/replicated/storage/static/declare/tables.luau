export type tables = {
    read __mode_ks: {read __mode: "ks"},
    read __mode_vs: {read __mode: "vs"},
    read __mode_kvs: {read __mode: "kvs"},
}

const tables: tables = {
    __mode_ks = table.freeze {
        __mode = "ks" :: "ks"
    },
    __mode_kvs = table.freeze {
        __mode = "kvs" :: "kvs"
    },
    __mode_vs = table.freeze {
        __mode = "vs" :: "vs"
    }
}

table.freeze(tables)
return tables