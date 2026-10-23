--[==[
    Это типы для систем, которые работают с метаданными
]==]
export type mtypes = {
	--[==[
        Абсолютно без разницы какой тип. Используется только для метаданных.
    ]==]
	read anyt: "anyt",

	--[==[
        Результата никогда не будет, потому что функция ничего не возвращает. Используется только для метаданных.
    ]==]
	read never: "never",

    --[==[
        Всегда выводит ошибку.
    ]==]
    read error: "error",
}

const mtypes: mtypes = {
    anyt = "anyt",
    never = "never",
    error = "error"
}

table.freeze(mtypes)
return mtypes