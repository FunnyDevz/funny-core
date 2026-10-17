--!strict

--[==[
	Это специальный решатель для строковых операторов.
]==]
const fspec = {}

export type Context = {
	self: unknown,
	args: {unknown},
}

type Resolver = (context: Context, path: string) -> (boolean, unknown?)

type ResolverMap = {
	[string]: Resolver,
}

type ControllerMatch = {
	name: string,
	path: string,
}

const RESOLVERS: ResolverMap = {}

const CONTROLLER_PATTERN = "_@([%w_]+[%w_%.]*)"
const ARG_PATTERN = "^%.(%d+)(.*)$"

const function resolvePath(root: unknown, path: string): (boolean, unknown?)
	local current = root

	if path == "" then
		return true, current
	end

	const parts = string.split(path, ".")

	for _, part in parts do
		if part == "" then
			continue
		end

		if type(current) ~= "table" then
			return false, nil
		end

		const value = (current :: { [string]: unknown })[part]

		if value == nil then
			return false, nil
		end

		current = value
	end

	return true, current
end

const function resolveSelf(context: Context, path: string): (boolean, unknown?)
	return resolvePath(context.self, path)
end

const function resolveArg(context: Context, path: string): (boolean, unknown?)
	if path == "" then
		return false, nil
	end

	const indexString, remainingPath = string.match(path, ARG_PATTERN)

	if not indexString then
		return false, nil
	end

	const index = tonumber(indexString)
	if not index then
		return false, nil
	end

	const value = context.args[index]

	if value == nil then
		return false, nil
	end

	if remainingPath == "" then
		return true, value
	end

	return resolvePath(value, remainingPath)
end

RESOLVERS.self = resolveSelf
RESOLVERS.arg = resolveArg

const function find_controller(value: string): ControllerMatch?
	const start, _, capture = string.find(value, CONTROLLER_PATTERN)

	if not start or not capture then
		return nil
	end

	const name, path = string.match(capture, "^([%w_]+)([%w_%.]*)$")

	if not name then
		return nil
	end

	return {
		name = name,
		path = path or "",
	}
end

function fspec.has_controller(value: string): boolean
	return string.find(value, CONTROLLER_PATTERN) ~= nil
end

function fspec.is_controller(value: string): boolean
	return string.match(value, CONTROLLER_PATTERN) ~= nil
end

function fspec.is_resolveable(value: string): boolean
	const match = find_controller(value)

	if not match then
		return false
	end

	return RESOLVERS[match.name] ~= nil
end

function fspec.get(value: string, context: Context): (boolean, string?)
	const match = find_controller(value)

	if not match then
		return false, nil
	end

	const resolver = RESOLVERS[match.name]
	if not resolver then
		return false, nil
	end

	const success, resolved = resolver(context, match.path)
	if not success then
		return false, nil
	end

	return true, tostring(resolved)
end

function fspec.resolve(value: string, context: Context): string
	const out = string.gsub(value, CONTROLLER_PATTERN, function(capture: string): string
		local name, path = string.match(capture, "^([%w_]+)([%w_%.]*)$")

		if not name then
			return "_@" .. capture
		end
		
		path = path or ""

		const resolver = RESOLVERS[name]

		if not resolver then
			return "_@" .. capture
		end

		const success, resolved = resolver(context, path)

		if not success then
			return "_@" .. capture
		end

		return tostring(resolved)
	end)

    return out
end

function fspec.register(name: string, resolver: Resolver)
	assert(
		RESOLVERS[name] == nil,
		string.format("Controller '%s' already exists", name)
	)

	RESOLVERS[name] = resolver
end

return table.freeze(fspec)