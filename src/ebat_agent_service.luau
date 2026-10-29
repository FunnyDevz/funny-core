const DataServer = require("@class/service/DataServer")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const actor = assert(script:GetActor(), "actor does not exist")

actor:BindToMessage(DefaultVariant.Any.hashlink, function(...): ...any
    
end)

DataServer:start()