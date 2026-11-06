export type types = {
	--[==[
        Соответствие к `nil`
    ]==]
	read ["nil"]: "nil",

	--[==[
        Соответствие к `number`
    ]==]
	read number: "number",

	--[==[
        Соответствие к `string`
    ]==]
	read string: "string",

	--[==[
        Соответствие к `boolean`
    ]==]
	read boolean: "boolean",

	--[==[
        Соответствие к `table`
    ]==]
	read table: "table",

	--[==[
        Соответствие к `vector`, оно же вектор
    ]==]
	read vector: "vector",

	--[==[
        Соответствие к `function`, оно же функция
    ]==]
	read ["function"]: "function",

	--[==[
        Соответствие к `thread`, оно же коррутина
    ]==]
	read thread: "thread",

	--[==[
        Соответствие к `userdata`.

        `userdata` - любой Си-сторонний код. Например, экземпляры роблокс.
    ]==]
	read userdata: "userdata",

	--[==[
        Соответствие к `buffer`
    ]==]
	read buffer: "buffer",

	read primetive_types: {[number]: "number" | "string" | "boolean" | string},
	read link_types: {[number]: "table" | "userdata" | "vector" | "thread" | "buffer" | "function" | string}
}

const types: types = table.freeze {
	["nil"] = "nil" :: "nil",
	["number"] = "number" :: "number",
	["string"] = "string" :: "string",
	["boolean"] = "boolean" :: "boolean",
	["table"] = "table" :: "table",
	["vector"] = "vector" :: "vector",
	["function"] = "function" :: "function",
	["thread"] = "thread" :: "thread",
	["userdata"] = "userdata" :: "userdata",
	["buffer"] = "buffer" :: "buffer",
	["primetive_types"] = table.freeze {"number", "string", "boolean"} :: any,
	["link_types"] = table.freeze {"table", "userdata", "vector", "thread", "buffer", "function"} :: any
}

return types