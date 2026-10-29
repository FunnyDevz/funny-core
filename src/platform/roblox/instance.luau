--!strict
const CollectionService = game:GetService("CollectionService")

const stderr = require("@extension/stderr")
const stdout = require("@extension/stdout")
const rbxtypes = require("@platform/roblox/rbxtypes")

const humanoid = table.freeze({
	get_limb_of = function(humanoid: Humanoid, limb: Enum.Limb): BasePart
		const parent = stderr:assert(humanoid.Parent, "cannot find parent of humanoid, crit")
		const model = stderr:assert(parent:IsA("Model") and parent or nil, "expected humanoid parent as a model, crit")

		for _, v in model:GetChildren() do
			if v:IsA("BasePart") and humanoid:GetLimb(v) == limb then
				return v
			end
		end

		return stdout:oute(`cannot find limb {limb.Name} in {model:GetFullName()}, crit fail`)
	end,
})

const instance = table.freeze({
	destroy_children_of_class = function(parent: Instance, classname: string): ()
		for _, child in parent:GetChildren() do
			if child:IsA(classname) then
				child:Destroy()
			end
		end
	end,

	destroy_descendants_of_class = function(parent: Instance, classname: string): ()
		for _, descendant in parent:GetDescendants() do
			if descendant:IsA(classname) then
				descendant:Destroy()
			end
		end
	end,

	destroy_ancestor_of_class = function(instance: Instance, classname: string): ()
		local current = instance.Parent

		while current do
			if current:IsA(classname) then
				current:Destroy()
				return
			end

			current = current.Parent
		end
	end,

	wait_for_child_of_class = function<T>(parent: Instance, classname: string): T & Instance
		const child = parent:FindFirstChildOfClass(classname)

		if child then
			return child
		end

		while true do
			const added = parent.ChildAdded:Wait()

			if added:IsA(classname) then
				return added
			end
		end
	end,

	wait_for_descendant_of_class = function<T>(parent: Instance, classname: string): T & Instance
		const descendant = parent:FindFirstChildWhichIsA(classname, true)

		if descendant then
			return descendant
		end

		while true do
			const added = parent.DescendantAdded:Wait()

			if added:IsA(classname) then
				return added
			end
		end
	end,

	wait_for_child_with_attribute = function<T>(parent: Instance, attribute: string): T & Instance
		const event = Instance.new("BindableEvent")
		const connections: { RBXScriptConnection } = {}

		const function observe(child: Instance)
			table.insert(
				connections,
				child:GetAttributeChangedSignal(attribute):Connect(function()
					if child:GetAttribute(attribute) ~= nil then
						event:Fire(child)
					end
				end)
			)

			if child:GetAttribute(attribute) ~= nil then
				event:Fire(child)
			end
		end

		table.insert(connections, parent.ChildAdded:Connect(observe))

		for _, child in parent:GetChildren() do
			observe(child)
		end

		const result = event.Event:Wait() :: Instance

		for _, connection in connections do
			connection:Disconnect()
		end

		event:Destroy()

		return result
	end,

	wait_for_descendant_with_attribute = function<T>(parent: Instance, attribute: string): T & Instance
		const event = Instance.new("BindableEvent")
		const connections: { RBXScriptConnection } = {}
		const function observe(descendant: Instance)
			table.insert(
				connections,
				descendant:GetAttributeChangedSignal(attribute):Connect(function()
					if descendant:GetAttribute(attribute) ~= nil and descendant:IsDescendantOf(parent) then
						event:Fire(descendant)
					end
				end)
			)

			if descendant:GetAttribute(attribute) ~= nil then
				event:Fire(descendant)
			end
		end

		table.insert(connections, parent.DescendantAdded:Connect(observe))

		for _, descendant in parent:GetDescendants() do
			observe(descendant)
		end

		const result = event.Event:Wait() :: Instance

		for _, connection in connections do
			connection:Disconnect()
		end

		event:Destroy()

		return result
	end,

	wait_for_child_with_tag = function<T>(parent: Instance, tag: string): T & Instance
		const event = Instance.new("BindableEvent")
		const connections: { RBXScriptConnection } = {}

		const function check(child: Instance)
			if CollectionService:HasTag(child, tag) then
				event:Fire(child)
			end
		end

		table.insert(connections, parent.ChildAdded:Connect(check))

		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
				if instance.Parent == parent then
					event:Fire(instance)
				end
			end)
		)

		for _, child in parent:GetChildren() do
			check(child)
		end

		const result = event.Event:Wait() :: Instance

		for _, connection in connections do
			connection:Disconnect()
		end

		event:Destroy()

		return result
	end,

	wait_for_descendant_with_tag = function<T>(parent: Instance, tag: string): T & Instance
		const event = Instance.new("BindableEvent")
		const connections: { RBXScriptConnection } = {}

		const function check(descendant: Instance)
			if CollectionService:HasTag(descendant, tag) and descendant:IsDescendantOf(parent) then
				event:Fire(descendant)
			end
		end

		table.insert(connections, parent.DescendantAdded:Connect(check))

		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
				if instance:IsDescendantOf(parent) then
					event:Fire(instance)
				end
			end)
		)

		for _, descendant in parent:GetDescendants() do
			check(descendant)
		end

		const result = event.Event:Wait() :: Instance

		for _, connection in connections do
			connection:Disconnect()
		end

		event:Destroy()

		return result
	end,

	wait_for_ancestor_with_tag = function<T>(instance: Instance, tag: string): T & Instance
		while true do
			local current = instance.Parent

			while current do
				if CollectionService:HasTag(current, tag) then
					return current
				end

				current = current.Parent
			end

			instance.AncestryChanged:Wait()
		end
	end,

	get_children_of_class = function<T>(parent: Instance, classname: string): { T & Instance }
		const children: { T } = {}

		for _, child in parent:GetChildren() do
			if child:IsA(classname) then
				table.insert(children, child)
			end
		end

		return children
	end,

	get_descendants_of_class = function<T>(parent: Instance, classname: string): { T & Instance }
		const descendants: { T } = {}

		for _, descendant in parent:GetDescendants() do
			if descendant:IsA(classname) then
				table.insert(descendants, descendant)
			end
		end

		return descendants
	end,

	get_ancestors = function(instance: Instance): { Instance }
		const ancestors = {}
		local current = instance.Parent

		while current do
			table.insert(ancestors, current)
			current = current.Parent
		end

		return ancestors
	end,

	get_ancestors_of_class = function<T>(instance: Instance, classname: string): { T & Instance }
		const ancestors: { T } = {}
		local current = instance.Parent

		while current do
			if current:IsA(classname) then
				table.insert(ancestors, current)
			end

			current = current.Parent
		end

		return ancestors
	end,

	wait_for_ancestors_of_class = function<T>(instance: Instance, classname: string): T & Instance
		while true do
			local current = instance.Parent

			while current do
				if current:IsA(classname) then
					return current
				end

				current = current.Parent
			end

			instance.AncestryChanged:Wait()
		end
	end,

	find_first_child_with_attribute = function<T>(parent: Instance, attribute: string): (T & Instance)?
		for _, child in parent:GetChildren() do
			if child:GetAttribute(attribute) ~= nil then
				return child
			end
		end

		return nil
	end,

	get_children_with_attribute = function<T>(parent: Instance, attribute: string): { T & Instance }
		const children: { T } = {}

		for _, child in parent:GetChildren() do
			if child:GetAttribute(attribute) ~= nil then
				table.insert(children, child)
			end
		end

		return children
	end,

	get_descendants_with_attribute = function<T>(parent: Instance, attribute: string): { T & Instance }
		const descendants: { T } = {}

		for _, descendant in parent:GetDescendants() do
			if descendant:GetAttribute(attribute) ~= nil then
				table.insert(descendants, descendant)
			end
		end

		return descendants
	end,

	get_ancestors_with_attribute = function<T>(instance: Instance, attribute: string): { T & Instance }
		const ancestors: { T } = {}
		local current = instance.Parent

		while current do
			if current:GetAttribute(attribute) ~= nil then
				table.insert(ancestors, current)
			end

			current = current.Parent
		end

		return ancestors
	end,

	find_first_child_with_tag = function<T>(parent: Instance, tag: string): (T & Instance)?
		for _, child in parent:GetChildren() do
			if CollectionService:HasTag(child, tag) then
				return child
			end
		end

		return nil
	end,

	get_children_with_tag = function<T>(parent: Instance, tag: string): { T & Instance }
		const children: { T } = {}

		for _, child in parent:GetChildren() do
			if CollectionService:HasTag(child, tag) then
				table.insert(children, child)
			end
		end

		return children
	end,

	get_descendants_with_tag = function<T>(parent: Instance, tag: string): { T & Instance }
		const descendants: { T } = {}

		for _, descendant in parent:GetDescendants() do
			if CollectionService:HasTag(descendant, tag) then
				table.insert(descendants, descendant)
			end
		end

		return descendants
	end,

	get_ancestors_with_tag = function<T>(instance: Instance, tag: string): { T & Instance }
		const ancestors: { T } = {}
		local current = instance.Parent

		while current do
			if CollectionService:HasTag(current, tag) then
				table.insert(ancestors, current)
			end

			current = current.Parent
		end

		return ancestors
	end,

	destroy_children_with_attribute = function(parent: Instance, attribute: string): ()
		for _, child in parent:GetChildren() do
			if child:GetAttribute(attribute) ~= nil then
				child:Destroy()
			end
		end
	end,

	destroy_descendants_with_attribute = function(parent: Instance, attribute: string): ()
		for _, descendant in parent:GetDescendants() do
			if descendant:GetAttribute(attribute) ~= nil then
				descendant:Destroy()
			end
		end
	end,

	destroy_ancestor_with_attribute = function(instance: Instance, attribute: string): ()
		local current = instance.Parent

		while current do
			if current:GetAttribute(attribute) ~= nil then
				current:Destroy()
				return
			end

			current = current.Parent
		end
	end,

	destroy_children_with_tag = function(parent: Instance, tag: string): ()
		for _, child in parent:GetChildren() do
			if CollectionService:HasTag(child, tag) then
				child:Destroy()
			end
		end
	end,

	destroy_descendants_with_tag = function(parent: Instance, tag: string): ()
		for _, descendant in parent:GetDescendants() do
			if CollectionService:HasTag(descendant, tag) then
				descendant:Destroy()
			end
		end
	end,

	destroy_ancestor_with_tag = function(instance: Instance, tag: string): ()
		local current = instance.Parent

		while current do
			if CollectionService:HasTag(current, tag) then
				current:Destroy()
				return
			end

			current = current.Parent
		end
	end,

	has_child_of_class = function(parent: Instance, classname: string): boolean
		return parent:FindFirstChildOfClass(classname) ~= nil
	end,

	has_descendant_of_class = function(parent: Instance, classname: string): boolean
		return parent:FindFirstChildWhichIsA(classname, true) ~= nil
	end,

	has_ancestor_of_class = function(instance: Instance, classname: string): boolean
		local current = instance.Parent

		while current do
			if current:IsA(classname) then
				return true
			end

			current = current.Parent
		end

		return false
	end,

	has_child_with_attribute = function(parent: Instance, attribute: string): boolean
		for _, child in parent:GetChildren() do
			if child:GetAttribute(attribute) ~= nil then
				return true
			end
		end

		return false
	end,

	has_descendant_with_attribute = function(parent: Instance, attribute: string): boolean
		for _, descendant in parent:GetDescendants() do
			if descendant:GetAttribute(attribute) ~= nil then
				return true
			end
		end

		return false
	end,

	has_ancestor_with_attribute = function(instance: Instance, attribute: string): boolean
		local current = instance.Parent

		while current do
			if current:GetAttribute(attribute) ~= nil then
				return true
			end

			current = current.Parent
		end

		return false
	end,

	has_child_with_tag = function(parent: Instance, tag: string): boolean
		for _, child in parent:GetChildren() do
			if CollectionService:HasTag(child, tag) then
				return true
			end
		end

		return false
	end,

	has_descendant_with_tag = function(parent: Instance, tag: string): boolean
		for _, descendant in parent:GetDescendants() do
			if CollectionService:HasTag(descendant, tag) then
				return true
			end
		end

		return false
	end,

	has_ancestor_with_tag = function(instance: Instance, tag: string): boolean
		local current = instance.Parent

		while current do
			if CollectionService:HasTag(current, tag) then
				return true
			end

			current = current.Parent
		end

		return false
	end,

	clone_children_to = function(parent: Instance, target: Instance): ()
		for _, descendant in parent:GetChildren() do
			descendant:Clone().Parent = target
		end
	end,

	set_attribute_on_children = function(parent: Instance, attribute: string, value: any): ()
		for _, child in parent:GetChildren() do
			child:SetAttribute(attribute, value)
		end
	end,

	set_attribute_on_descendants = function(parent: Instance, attribute: string, value: any): ()
		for _, descendant in parent:GetDescendants() do
			descendant:SetAttribute(attribute, value)
		end
	end,

	remove_attribute_from_children = function(parent: Instance, attribute: string): ()
		for _, child in parent:GetChildren() do
			child:SetAttribute(attribute, nil)
		end
	end,

	remove_attribute_from_descendants = function(parent: Instance, attribute: string): ()
		for _, descendant in parent:GetDescendants() do
			descendant:SetAttribute(attribute, nil)
		end
	end,

	add_tag_to_children = function(parent: Instance, tag: string): ()
		for _, child in parent:GetChildren() do
			CollectionService:AddTag(child, tag)
		end
	end,

	add_tag_to_descendants = function(parent: Instance, tag: string): ()
		for _, descendant in parent:GetDescendants() do
			CollectionService:AddTag(descendant, tag)
		end
	end,

	remove_tag_from_children = function(parent: Instance, tag: string): ()
		for _, child in parent:GetChildren() do
			CollectionService:RemoveTag(child, tag)
		end
	end,

	remove_tag_from_descendants = function(parent: Instance, tag: string): ()
		for _, descendant in parent:GetDescendants() do
			CollectionService:RemoveTag(descendant, tag)
		end
	end,
})

const object = table.freeze {
	get_invariant = function <T> (of: Object?, expected: string) : (T & Object)?
		return rbxtypes:is_rbx_type(typeof(of)) and of ~= nil and of:IsA(expected) and of or nil
	end,
}

return table.freeze {
    datamodel = instance,
    humanoid = humanoid,
	object = object
}