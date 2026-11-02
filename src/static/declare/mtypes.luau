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

    read inf_positive: "+inf",
    read inf_negative: "-inf",
    read nan: "NaN",
}

const mtypes: mtypes = {
    anyt = "anyt",
    never = "never",
    error = "error",
    inf_positive = "+inf",
    inf_negative = "-inf",
    nan = "NaN",
}

table.freeze(mtypes)
return mtypes