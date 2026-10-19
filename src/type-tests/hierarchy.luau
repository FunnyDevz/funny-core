--!nolint
--!strict

-- luau-lang/luau #3059 
type mt = setmetatable<{}, {} & {}> -- TypeError: Type function instance setmetatable<{  }, {  } & {  }> is uninhabited
type mt2 = setmetatable<{}, {} | {}> -- TypeError: Type function instance setmetatable<{  }, {  } | {  }> is uninhabited

type obj_test = extend<{
    read r: string
}, disposable>

local obj_test_mt = getmetatable({} :: obj_test)

-- luau-lang/luau #3060 (same as 3059)
type b0 = setmetatable<{}, nil>


-- luau-lang/luau #3062
-- Это не баг, это специальное поведение решателя для защиты от сырых generic типов

type h = {
    r: any,
    h: <T> (t: h & T, f: (t: T) -> ()) -> ()
}

local h_test : h = {} :: any
h_test:h(function(t)
    
end)
h_test.h(h_test, function(t)
    
end)