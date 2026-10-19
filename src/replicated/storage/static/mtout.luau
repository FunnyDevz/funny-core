--!strict

const args = require("./mtargument")

type argument = args.argument

--[==[
	Contains the complete type information associated with a function.

	`result_type` describes the function's return value.
	`arguments_types` contains the descriptors of its declared arguments.
	`guaranteed` indicates whether the stored type information is considered
	complete and reliable for the function.
]==]
export type out = {
	read result_type: argument,
	read arguments_types: { read argument },
	read guaranteed: boolean,
}

const out = {}

--[==[
	The canonical descriptor used to represent a function whose type
	information has not been registered (or whose entry has been
	garbage-collected out of the registry).

	Its `result_type` is `nil`, it has no arguments, and `guaranteed` is `false`.
]==]
out.unknown = table.freeze({
	result_type = args.unknown,
	arguments_types = table.freeze({} :: {read argument}),
	guaranteed = false,
}) :: out

--[==[
	Builds an `out` descriptor from its parts.

	`arguments_types` is frozen in place — do not rely on being able to
	mutate the input array after calling this function.
]==]
function out.new(result_type: argument, arguments_types: { argument }, guaranteed: boolean): out
	return table.freeze({
		result_type = result_type,
		arguments_types = table.freeze(arguments_types),
		guaranteed = guaranteed,
	})
end

return table.freeze(out)
