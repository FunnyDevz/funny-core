--!strict

return table.freeze({
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
	["anyt"] = "anyt" :: "anyt",

	["groups"] = table.freeze {
		["init"] = "init" :: "init"
	},

	--[==[

	]==]
	utypeof = function (of: any)
		const T = typeof(of)


		if (T == "table") then
			const mt = getmetatable(of)
			if (type(mt) == "table") then
				if (type(mt.__utype) == "string") then
					return mt.__utype
				end
			end

		elseif (T == "userdata") then
			const mt = getmetatable(of)

			if (type(mt) == "table") then
				if (type(mt.__utype) == "string") then
					return mt.__utype
				end
			end

		end

		return T
	end,

	["metatable"] = table.freeze {
		["__index"]    = "__index"    :: "__index",
		["__newindex"] = "__newindex" :: "__newindex",

		["__call"]     = "__call"     :: "__call",
		["__concat"]   = "__concat"   :: "__concat",

		["__unm"]      = "__unm"      :: "__unm",

		["__add"]      = "__add"      :: "__add",
		["__sub"]      = "__sub"      :: "__sub",
		["__mul"]      = "__mul"      :: "__mul",
		["__div"]      = "__div"      :: "__div",
		["__idiv"]     = "__idiv"     :: "__idiv",
		["__mod"]      = "__mod"      :: "__mod",
		["__pow"]      = "__pow"      :: "__pow",

		["__eq"]       = "__eq"       :: "__eq",
		["__lt"]       = "__lt"       :: "__lt",
		["__le"]       = "__le"       :: "__le",

		["__len"]      = "__len"      :: "__len",
		["__iter"]     = "__iter"     :: "__iter",

		["__tostring"] = "__tostring" :: "__tostring",

		["__metatable"] = "__metatable" :: "__metatable",
		["__mode"]      = "__mode"      :: "__mode", -- k/v/s

		--[==[
			Это специальный user-type, который определяется через `utypeof()`

			В Luau существует внутреннее мета-поле `__type` и оно используется в `userdata`, которые
			были созданы не через `newproxy()` функцию самим host-приложением. Для пользовательских данных
			это поведение недоступно и захардкожено в угоду безопасности языка для host приложения. Таким
			образом подменить информацию о реальном типе полученных данных не выйдет.

			Теоретически можно разрешить для `table` обращаться к `__type` через `typeof()`, но это потребует
			пересборки LVM. Кроме того, через lua_stack можно глобально переобъявить типы данных, что само по себе
			нивелирует такие изменения.
		]==]
		["__utype"]		= "__utype"		:: "__utype",

		--[==[

		]==]
		["__uindex"]	= "__uindex"	:: "__uindex",

		--[==[
			Идея взята из Godot. Для данных, которые были 
		]==]
		["__urpc"]		= "__urpc"		:: "__urpc",

		--[==[
			Это поле не используется в проекте, поскольку оно предоставляет преимущества в оптимизации только
			для стороны host приложения, в котором работает LVM. Суть в том, что обычная маршрутизация требует
			пройти через userdata metatable __index -> class table -> needle methode. То бишь цепь путей большая,
			и для С++ кода это дороговато: LVM на каждый такой lookup кидает байткод инструкции и выполняет тонну вещей.

			Зачем тратить ресурсы на то, что можно прокинуть ручками?

			Когда для userdata вызывается что-либо через шорткат `object:methode(args)`, то есть синтаксическим сахаром `:`,
			в функцию на метаметоде `__namecall` передается весь штат аргументов. Имя вызванной функции получается отдельно,
			через C++ функцию. Это намеренное поведение, потому что добавление его как аргумента в стек было бы дублированием
			информации. Получить эти данные же можно на лету, так что смысла в передаче как аргумент у этого нету.

			В проекте userdata не поддерживается. Велись отдельные исследования, но для использования это неподходящий тип.
		]==]
		['__namecall']	= "__namecall"	:: "__namecall",

		-- ["__band"]  = "__band"  :: "__band",
		-- ["__bor"]   = "__bor"   :: "__bor",
		-- ["__bxor"]  = "__bxor"  :: "__bxor",
		-- ["__bnot"]  = "__bnot"  :: "__bnot",
		-- ["__shl"]   = "__shl"   :: "__shl",
		-- ["__shr"]   = "__shr"   :: "__shr",
	},

	["roblox"] = table.freeze({
		["AdReward"] = "AdReward" :: "AdReward",
		["Axes"] = "Axes" :: "Axes",
		["BrickColor"] = "BrickColor" :: "BrickColor",
		["CatalogSearchParams"] = "CatalogSearchParams" :: "CatalogSearchParams",
		["CFrame"] = "CFrame" :: "CFrame",
		["Color3"] = "Color3" :: "Color3",
		["ColorSequence"] = "ColorSequence" :: "ColorSequence",
		["ColorSequenceKeypoint"] = "ColorSequenceKeypoint" :: "ColorSequenceKeypoint",
		["Content"] = "Content" :: "Content",
		["DateTime"] = "DateTime" :: "DateTime",
		["DockWidgetPluginGuiInfo"] = "DockWidgetPluginGuiInfo" :: "DockWidgetPluginGuiInfo",
		["Enum"] = "Enum" :: "Enum",
		["EnumItem"] = "EnumItem" :: "EnumItem",
		["Enums"] = "Enums" :: "Enums",
		["Faces"] = "Faces" :: "Faces",
		["FloatCurve"] = "FloatCurve" :: "FloatCurve",
		["Font"] = "Font" :: "Font",
		["Instance"] = "Instance" :: "Instance",
		["NumberRange"] = "NumberRange" :: "NumberRange",
		["NumberSequence"] = "NumberSequence" :: "NumberSequence",
		["NumberSequenceKeypoint"] = "NumberSequenceKeypoint" :: "NumberSequenceKeypoint",
		["OverlapParams"] = "OverlapParams" :: "OverlapParams",
		["Path2DControlPoint"] = "Path2DControlPoint" :: "Path2DControlPoint",
		["PathWaypoint"] = "PathWaypoint" :: "PathWaypoint",
		["PhysicalProperties"] = "PhysicalProperties" :: "PhysicalProperties",
		["Random"] = "Random" :: "Random",
		["Ray"] = "Ray" :: "Ray",
		["RaycastParams"] = "RaycastParams" :: "RaycastParams",
		["RaycastResult"] = "RaycastResult" :: "RaycastResult",
		["RBXScriptConnection"] = "RBXScriptConnection" :: "RBXScriptConnection",
		["RBXScriptSignal"] = "RBXScriptSignal" :: "RBXScriptSignal",
		["Rect"] = "Rect" :: "Rect",
		["Region3"] = "Region3" :: "Region3",
		["Region3int16"] = "Region3int16" :: "Region3int16",
		["RotationCurveKey"] = "RotationCurveKey" :: "RotationCurveKey",
		["Secret"] = "Secret" :: "Secret",
		["SecurityCapabilities"] = "SecurityCapabilities" :: "SecurityCapabilities",
		["SharedTable"] = "SharedTable" :: "SharedTable",
		["TweenInfo"] = "TweenInfo" :: "TweenInfo",
		["UDim"] = "UDim" :: "UDim",
		["UDim2"] = "UDim2" :: "UDim2",
		["UserValue"] = "UserValue" :: "UserValue",
		["Vector2"] = "Vector2" :: "Vector2",
		["Vector2int16"] = "Vector2int16" :: "Vector2int16",
		["Vector3"] = "Vector3" :: "Vector3",
		["Vector3int16"] = "Vector3int16" :: "Vector3int16",
	}),

    ["tables"] = table.freeze {
        ["dummy"] = table.freeze {},
        ["__mode_ks"] = table.freeze {__mode = "ks" :: 'ks'},
        ["__mode_vs"] = table.freeze {__mode = "vs" :: "vs"},
        ["__mode_kvs"] = table.freeze {__mode = "kvs" :: "kvs"},
        ["__newindex_null"] = table.freeze {__newindex = function () end},
        ["__null"] = setmetatable({} :: {[any]: any}, {__newindex = function () end})
    }
})
