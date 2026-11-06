--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const datamodel = require("@platform/roblox/datamodel")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")
const std = require("@extension/std")

const private = { type = "path" }
const class: path = LuaObject:new({
	type = private.type,
	path_to_instance_parent = nil :: string?,
	expected_instance_name = nil :: string?,
	expected_instance_class = nil :: string?,
	is_path_strict = false,
	is_path_absolute = false,
	spoof = false,
	spoof_takes_any_similar_instance = false,

	get_by_absolute_path = ftype:write(function(self: path): Instance
		std:assert(self.path_to_instance_parent, "path is not set")

		const instance =
			private.validate_instance(datamodel.find_by_absolute_path(self.path_to_instance_parent or ""), self)
		if instance ~= nil then
			return instance
		end
		if self.spoof then
			return private.spoof_absolute_path(self)
		end

		return std:oute(
			`instance not found in absolute path {self.path_to_instance_parent} with name {self.expected_instance_name} and {self.expected_instance_class}`
		)
	end, ftype:opt(rbxtypes.Instance), private.type),

	get_by_relative_path = ftype:write(function(self: path, root: Instance | path): Instance
		std:assert(self.path_to_instance_parent, "path is not set")

		const root_instance: Instance = std:assert(private.resolve_path_value(root), "root is not valid")
		const instance = private.validate_instance(
			datamodel.find_by_relative_path(root_instance, self.path_to_instance_parent or ""),
			self
		)
		if instance ~= nil then
			return instance
		end
		if self.spoof then
			return private.spoof_relative_path(self, root_instance)
		end

		return std:oute(
			`instance not found in relative path {self.path_to_instance_parent} with name {self.expected_instance_name} and {self.expected_instance_class}`
		)
	end, ftype:opt(rbxtypes.Instance), private.type, ftype:uor(rbxtypes.Instance, private.type)),

	get_by_path = ftype:write(function(self: path, root: Instance | path): Instance
		if self.is_path_absolute then
			return self:get_by_absolute_path()
		else
			if root then
				return self:get_by_relative_path(root)
			end
		end

		return std:oute("instance does not exists in relative or absolute path")
	end, ftype:opt(rbxtypes.Instance), private.type, ftype:uor(rbxtypes.Instance, private.type, types["nil"])),

	get_by_absolute_path_or_nil = ftype:write(function(self: path): Instance?
		if not self.path_to_instance_parent then
			return nil
		end

		return private.validate_instance(datamodel.find_by_absolute_path(self.path_to_instance_parent), self)
	end, ftype:opt(rbxtypes.Instance), private.type),

	get_by_relative_path_or_nil = ftype:write(function(self: path, root: Instance | path | nil): Instance?
		if not self.path_to_instance_parent then
			return nil
		end
		if root == nil then
			return nil
		end

		const root_instance: Instance? = private.resolve_path_value(root)
		if not root_instance then
			return nil
		end

		return private.validate_instance(
			datamodel.find_by_relative_path(root_instance, self.path_to_instance_parent),
			self
		)
	end, ftype:opt(rbxtypes.Instance), private.type, ftype:uor(rbxtypes.Instance, private.type)),

	get_by_path_or_nil = ftype:write(function(self: path, root: Instance | path | nil): Instance?
		if self.is_path_absolute then
			return self:get_by_absolute_path_or_nil()
		else
			if root then
				return self:get_by_relative_path_or_nil(root)
			else
				return nil
			end
		end
	end, ftype:opt(rbxtypes.Instance), private.type, ftype:uor(rbxtypes.Instance, private.type, types["nil"])),

	set_absolute_path_to = ftype:write(function(self: path, to: Instance | path): ()
		const instance: Instance =
			std:assert(private.resolve_path_value(to), "cannot resolve instance from path target")

		self.path_to_instance_parent = datamodel.get_absolute_path_of(instance)
		self.is_path_absolute = true
	end, mtypes.never, private.type, ftype:uor(private.type, rbxtypes.Instance)),

	set_relative_path_to = ftype:write(
		function(self: path, root: Instance | path, to: Instance | path): ()
			const root_instance: Instance = std:assert(private.resolve_path_value(root), "cannot resolve root instance")
			const target_instance: Instance =
				std:assert(private.resolve_path_value(to), "cannot resolve target instance")
			const relative_path: string = std:assert(
				datamodel.get_relative_path_of(root_instance, target_instance) :: any,
				"target is not under root"
			)

			self.path_to_instance_parent = relative_path
			self.is_path_absolute = false
		end,
		mtypes.never,
		private.type,
		ftype:uor(rbxtypes.Instance, private.type),
		ftype:uor(rbxtypes.Instance, private.type)
	),

	has_instance = ftype:write(function(self: path): boolean
		if self.is_path_absolute then
			return self:get_by_absolute_path_or_nil() ~= nil
		end

		return self:get_by_relative_path_or_nil(game) ~= nil
	end, types.boolean, private.type),
})

do
	function private.resolve_path_value(value: any): Instance?
		if typeof(value) == rbxtypes.Instance then
			return value :: Instance
		elseif class.is(value :: path, class.type) then
			return value:get_by_path_or_nil()
		end
		return nil
	end

	function private.spoof_absolute_path(self: path): Instance
		const tokens = datamodel.path_tokenize(self.path_to_instance_parent or "")
		local current: Instance? = game

		for _, token in tokens do
			if token == "game" then
				continue
			elseif token == ".." then
				current = current and current.Parent
			else
				local child = current and current:FindFirstChild(token)

				if not child then
					if self.spoof_takes_any_similar_instance and not self.is_path_strict then
						child = current and current:FindFirstChildOfClass(self.expected_instance_class or "")
					end
				end

				if not child then
					child = Instance.new(self.expected_instance_class or "Folder")
					child.Name = token
					child.Parent = current
				end
				current = child
			end
		end

		return std:assert(current, "cannot find absolute path")
	end

	function private.spoof_relative_path(self: path, root: Instance): Instance
		const tokens = datamodel.path_tokenize(self.path_to_instance_parent or "")
		local current: Instance? = root

		for _, token in tokens do
			if token == ".." then
				current = current and current.Parent
			else
				local child = current and current:FindFirstChild(token)

				if not child then
					if self.spoof_takes_any_similar_instance and not self.is_path_strict then
						child = current and current:FindFirstChildOfClass(self.expected_instance_class or "")
					end
				end

				if not child then
					child = Instance.new(self.expected_instance_class or "Folder")
					child.Name = token
					child.Parent = current
				end

				current = child
			end
		end

		return std:assert(current, "spoof cannot find relative root")
	end

	function private.validate_instance(instance: Instance?, self: path): Instance?
		if not instance then
			return nil
		end

		if self.expected_instance_name ~= nil and instance.Name ~= self.expected_instance_name then
			return nil
		end

		if self.expected_instance_class ~= nil and instance.ClassName ~= self.expected_instance_class then
			return nil
		end

		return instance
	end
end

return class
