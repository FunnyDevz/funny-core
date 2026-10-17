type stream = string

export type library = {
    read new: <T> (stream: stream) -> T,

    read is_urpc: <T> (...T) -> boolean,
    read request: (stream: stream, field: any) -> any,
    read call: (stream: stream, field: any, ...any) -> any,
    read send: (stream: stream, field: any, ...any) -> ()
}

const mt = {
    __index = function (t)
}

const library: library = {}

return library