--!nolint
--!strict

-- luau-lang/luau #3059
type mt = setmetatable<{}, {} & {}> -- TypeError: Type function instance setmetatable<{  }, {  } & {  }> is uninhabited
type mt2 = setmetatable<{}, {} | {}> -- TypeError: Type function instance setmetatable<{  }, {  } | {  }> is uninhabited

type obj_test = extend<{
    read r: string
}, disposable>

local obj_test_mt = getmetatable({} :: obj_test)