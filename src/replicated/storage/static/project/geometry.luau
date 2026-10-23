--[==[
    Статические константы для `geometry` части ядра, определяемые до момента билда. Они будут учитываться в
    работе функций и кода.
]==]
const geometry = table.freeze {
    fuzzy_eq_diff = 0.0001 
}

return geometry