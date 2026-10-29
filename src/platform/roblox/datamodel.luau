const CollectionService = game:GetService("CollectionService")

const function tokenize(path: string): { string }
	const tokens: { string } = {}
	local i, n = 1, #path

	while i <= n do
		const c = path:sub(i, i)
		if c == "." then
			if path:sub(i, i + 1) == ".." then
				table.insert(tokens, "..")
				i += 2
			else
				i += 1
			end
		else
			local j = i
			while j <= n and path:sub(j, j) ~= "." do
				j += 1
			end
			table.insert(tokens, path:sub(i, j - 1))
			i = j
		end
	end

	return tokens
end

const datamodel = {
	get_nodes = function(of: luaobject): { Instance }
		return CollectionService:GetTagged(tostring(of:iden()))
	end,

	has_nodes = function(of: luaobject): boolean
		return #CollectionService:GetTagged(tostring(of:iden())) > 0
	end,

	add_nodes = function(of: luaobject, ...: Instance): ()
		const identity = tostring(of:iden())

		for i, v in { ... } do
			CollectionService:AddTag(v, identity)
		end
	end,

	rem_nodes = function(of: luaobject, ...: Instance): ()
		const identity = tostring(of:iden())

		for i, v in { ... } do
			CollectionService:RemoveTag(v, identity)
		end
	end,

	get_tagged = function(tag: string): { Instance }
		return CollectionService:GetTagged(tag)
	end,

	on_tag_added = function(tag: string, f: (instance: Instance) -> ()): RBXScriptConnection
		return CollectionService:GetInstanceAddedSignal(tag):Connect(f)
	end,

	on_tag_removed = function(tag: string, f: (instance: Instance) -> ()): RBXScriptConnection
		return CollectionService:GetInstanceRemovedSignal(tag):Connect(f)
	end,

	on_ancestry_changed = function(of: Instance, f: () -> ()): RBXScriptConnection
		return of.AncestryChanged:Connect(function()
			f()
		end)
	end,

	is_inside = function(of: Instance, ancestors: { Instance }?): boolean
		if not of:IsDescendantOf(game) then
			return false
		end

		for k, v in ancestors or { workspace } do
			if of:IsDescendantOf(v) then
				return true
			end
		end

		return false
	end,

	find_by_absolute_path = function (path: string): Instance?
		const tokens = tokenize(path)
		if tokens[1] == "game" then
			table.remove(tokens, 1)
		end

		local current: Instance? = game
		for _, token in tokens do
			if not current then
				return nil
			end
			current = current:FindFirstChild(token)
		end
		return current
	end,

	find_by_relative_path = function (root: Instance, path: string): Instance?
		local current: Instance? = root
		for _, token in tokenize(path) do
			if not current then
				return nil
			end
			if token == ".." then
				current = current.Parent
			else
				current = current:FindFirstChild(token)
			end
		end
		return current
	end
}

return datamodel
