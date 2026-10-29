--[==[
    Параметры для работы `SharedNet`
]==]
export type shared_net_preferences = {

    --[==[
        Максимальное количество пакетов, которое можно отправить за N время и это не будет отброшено.
    ]==]
    max_network_packages: number,

    --[==[
        Название назначения, в котором должен распаковаться `SharedNet` и хранить свои связи для репликации.
    ]==]
    deploy_placement_name: string
}

const pref: shared_net_preferences = {
    max_network_packages = 4,
    deploy_placement_name = "shared_net_placement"
}

return pref