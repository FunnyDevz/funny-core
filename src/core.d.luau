--!strict

-- TFUNC

type function neg (t) return types.negationof(t) end
export type truthful = neg<false>
export type exist = neg<nil>

--[==[
    Тип гарантированно является пустой `userdata`.
]==]
export type userdata = {read [never]: never}

--- CORE

--[==[
    Неправильно настроенные типы могут привести к типовой деградации нижнего уровня (самого luaobject). Появление
    *error-type* типов внутри типа - признак неправильной настройки.
]==]

--[==[
    В этом проекте механика наследования построена на интерсекции типов.
]==]
export type extend<extension = {}, base = luaobject> = extension & base

--[==[
    Базовый объект проекта.

    Это самый низкоуровневый объект для участия в иерархии проекта. Содержит в себе RTTI и в принципе все что необходимо,
    чтобы превратить обычную таблицу в используемые классы.

    В проекте такой объект не является классом или экземпляром в - все вдохновляется семантикой `SmallTalk`, в котором
    классы это такие-же объекты как и экземпляры этих классов. Поэтому здесь разрешено изменять, наследовать, и в
    принципе следовать логике того, что каждый объект сам решает что ему лучше и как делать.

    Однако классы и объекты никуда не делись. Классами считается тот объект, который первым реализует эту логику, а
    все кто наследуются от него - объекты этого класса. И также работает и для них. Обычный экземпляр, по сути, просто
    то что переиспользует уже придуманное и ничего не добавляет.
]==]
export type luaobject = {
	--[==[
        Узнать какой перед вами объект и какого класса можно при помощи этого поля
    ]==]
	read type: string,

	--[==[
        Конструирует объект: левая часть считается за основание, а правая за расширение. Расширение перезаписывает
        данные из основания. За инициализацию отвечают `luaobject.host(self, f)` и `luaobject.finally(self, f)`.

        Наследоваться, то бишь создавать объект из любого другого объекта можно, но имейте ввиду что поведение зависит
        от контекста наследования.

        Если создаете экземпляр класса, то это одно дело, другое если это экземпляр объекта класса.
    ]==]
	read new: <T, U>(self: T, that: U?) -> extend<T, U>,

	--[==[
        Это прямая проверка, что тип объекта является этим типом. Можно проверять и через `luaobject.type == "type"`,
        однако это унифицированная проверка и она предпочтительней.
    ]==]
	read it: (self: luaobject, otype: string) -> boolean,

	--[==[
        Проверка что объект наследует или является этим типом.
    ]==]
	read is: (self: luaobject, otype: string) -> boolean,

	--[==[
        Каст объекта в другой тип. Если объект не соответствует этому типу, то будет ошибка.

        При отсутствии `debug` метки, или если рантайм разрешит выполняться бракованному коду, будет вернут
        объект `null`, который просто умалчивает любые прорехи. Даже если рантайм падет, мы попытаемся сделать так, чтобы
        это было выполнено.
    ]==]
	read as: <T>(self: luaobject, otype: string) -> luaobject & T,

	--[==[
        Это проверка на то, что переданные объекты либо эквивалентны этому объекту, либо наследуют
        тот же класс что и этот объект, то есть наследуют его.
    ]==]
	read same: (self: luaobject, ...luaobject) -> boolean,

	--[==[
        Эквивалитет объекта к другому объекту как по его сравнению через `TableValue` самой LVM, так и через
        типы каждого экземпляра
    ]==]
	read eq: (self: luaobject, ...luaobject) -> ...boolean,

	--[==[
        Возвращает суперкласс этого класса, то есть его базу, то есть его родителя из которого
        этот объект вообще произошел.

        Состояние родителя не влияет на ребенка, и даже если родитель уже невалиден и освобожден, то
        ребенок будет продолжать всегда ссылаться на него. Это все конечно зависит от контекста.
    ]==]
	read base: (self: luaobject) -> luaobject?,

	--[==[
        Host представляет функцию для инициализации нового объекта. По сути это замена функции конструктора,
        поскольку предоставленная лямбда получает доступ к новосозданному неинициализированному объекту. Обычно именно
        host функция занимается его инициализацией, чтобы объект полностью функционировал.

        Если вызвать `luaobject:host(f)` на `f` который уже существовал, то он будет удален из `host` списка, иначе
        будет вставлен обратно. То есть работает как toggle.

        В текущей версии лямбда принимает нетипизированный `luaobject` только потому что generic `T` не подхватывает
        `self`. Это между прочем намеренное поведение
    ]==]
	read host: (self: luaobject, f: (new: luaobject) -> ()) -> (),

	--[==[
        Это аналог `luaobject.as(self, type)`, но мягкий и для каста других объектов. Он не вернет ошибку,
        вместо этого вернется `nil`. Через него можно кастовать сам объект `self` в другой объект.
    ]==]
	read that: <T>(self: luaobject, that: unknown, otype: string) -> (luaobject & T)?,

	--[==[
        Возвращает идентификатор объекта. Это уникальный идентификатор только на 1 экземпляр виртуальной машины,
        для параллельности этот идентификатор лучше никогда не использовать.
    ]==]
	read iden: (self: luaobject) -> string,

	--[==[
        Эта функция запускается в конце создания любого экземпляра, который наследуется от этого объекта.
        Она используется, в основном, в качестве финализатора для инициализации того или иного объекта и архетипа.

        Например, для `struct` она может использоваться для заморозки.

        Его можно перезаписать, а все предыдущие финализаторы можно вызвать из финализатора. При этом вызван будет
        самый верхний финализатор
    ]==]
	read seal: <T>(self: luaobject, f: object_finally_type?) -> (),

    --[==[
        Вытаскивает объект по его идентификатору.
    ]==]
    read fetch: (self: luaobject, ...string) -> ...luaobject?,

	--[==[
        Typeless getter. Используется когда информации о типе объекта недостаточно, и недостаточно информации
        в общем о том что может быть у объекта.

        Геттер проверяет метаданные классы, прежде чем получить данные по этому ключу.
    ]==]
	read tget: (self: luaobject, name: string) -> any?,

	--[==[
        Typeless setter. Используется когда информации о типе объекта недостаточно, и недостаточно информации в
        в общем о том что может быть у объекта. Конкретно в этом случае это предназначено для назначения объекту
        каких-либо данных.

        Сеттер проверяет метаданные класса и метаданные функции, если потребуется. Поэтому пустышки он не принимает,
        и некорректные данные выбрасывает в мусорку и умолчит.
    ]==]
	read tset: (self: luaobject, name: string, value: any?) -> (),

	--[==[
        Typeless caller. Используется когда информации о типе объекта недостаточно, и недостаточно информации в
        в общем о том что может быть у объекта. Конкретно в этом случае это предназначено для вызова у объекта
        каких-либо функций.

        Каллер проверяет метаданные классы и метаданные функции. Некорректные данные он просто отбросит и умолчит.
    ]==]
	read tcall: (self: luaobject, name: string, ...any) -> ...any?,

	--[==[
        Это способ получить тип у объекта, либо узнать, что это вообще не объект.
    ]==]
	read ttype: (self: luaobject | unknown) -> string?,
}

--[==[
    Функция финализации генерации объекта.
]==]
export type object_finally_type = (self: luaobject, base: object_finally_type?) -> ()

--[==[
    Объект, позволяющий отслеживать удаление других объектов из своего пула.

    Реализация копирует и модифицирует работу Арсения Капулкина (zeux) `GCTracker` по
    ссылке https://gist.github.com/zeux/99c0ede2680d1aad565cb37e0d0f076d
]==]
export type heap = extend<{
    --[==[
        Регистрирует этот объект на наблюдение
    ]==]
    read register: (self: heap, ...luaobject|{[any]: any}) -> userdata,
    --[==[
        Убирает этот объект и его финализаторы с наблюдения.
    ]==]
    read unregister: (self: heap, ...userdata) -> (), 

    --[==[
        Добавляет финализаторы-деструкторы на эти объекты.
    ]==]
    read finally: (self: heap, to: userdata, ...(luaobject_identity: string) -> ()) -> ()
}, luaobject>

--[==[
    Представляет собой перечисление и содержит его значения EnumItem

    EnumObject определяет именованный набор связанных элементов перечисления.
    Он предоставляет доступ к отдельным значениям EnumItem и может использоваться везде, где требуется перечисление в целом.

    Каждый элемент ENUM, предоставляемый EnumObject, принадлежит этому перечислению.
    Таким образом, EnumObject действует как пространство имен и как владелец своих значений перечисления.

    Типичное использование:

    ```luau
    local value = ExampleEnumObject.SomeValue
    local items = ExampleEnumObject:get_enums_list()
    ```
]==]
export type enumobject = extend<{
	--[==[
        Имя в объекте енамов используется для идентификации.
    ]==]
	read name: string,

    --[==[
        Объект метка, использующийся для построения `enumitem`. Объект строит предмет только по такой метке,
        иначе в енам попадет то что попадет.
    ]==]
    read build_enumitem_mark: any,

	--[==[
        Возвращает список всех релевантных этому `enumobject` объектов `enumitem`.
    ]==]
	read get_enums_list: (self: enumobject) -> { [unknown]: enumitem },

	--[==[
        Возвращает общее количество енамов в объекте.
    ]==]
	read get_enums_count: (self: enumobject) -> number,

	--[==[
        Возвращает все имена енамов в объекте.
    ]==]
	read get_enums_name: (self: enumobject, ...enumitem) -> ...string?,

	--[==[
        Возвращает все хэши каждого енама в объекте.
    ]==]
	read get_hashlink_list: (self: enumobject) -> { string },

	--[==[
        Пробует вытащить енам по его имени из объекта.
    ]==]
	read get_enum_by_name: (self: enumobject, name: string) -> enumitem?,

	--[==[
        Прощует вытащить енам по его хэшу из объекта.
    ]==]
	read get_enum_by_hashlink: (self: enumobject, hashlink: string) -> enumitem?,

	--[==[
        Проверяет, является ли этот енам, или имя или строка частью этого объекта.
    ]==]
	read is_my_enumitem: (self: enumobject, that: enumitem | string) -> boolean,
}, luaobject>

--[==[
    Представляет собой единственное именованное значение, принадлежащее объекту EnumObject.

    EnumItem - это неизменяемое значение перечисления, идентифицируемое по его родительскому перечислению и имени элемента.
    Его можно использовать в качестве стабильного дескриптора в сравнениях, отправке, подписках и других API,
    которые работают со значениями перечисления.

    EnumItem не представляет собой произвольное значение во время выполнения.
    Каждый элемент принадлежит EnumObject и однозначно идентифицируется в рамках этого перечисления.

    Типичное использование:

    ```luau

    local function foo(item: enumitem)
        if item == ExampleEnumObject.SomeValue then
            -- ...
        end

        if item.hashlink == ExampleEnumObject.SomeValue2.hashlink then
            -- ...
        end
    end

    ```
]==]
export type enumitem<T = enumobject?> = extend<{
	--[==[
        Уникальная строка, которая генерируется из `.name` и `.enum.name`.

        Используйте ее для проверки валидности.
    ]==]
	read hashlink: string,

	--[==[
        Ссылка на `enumobject`, который держит этот объект.
    ]==]
	read enum: T,
} & nameable, luaobject>

--[==[
    Базовый структурный тип

    Struct предоставляет общие операции для работы со структурированными объектами среды выполнения.
    Он может быть скопирован с сохранением конкретного типа luaobject и может выполнять итерацию по
    значениям указанного типа.

    Разница между всеми другими классами ядра в том, что этот объект `никогда` не имеет скрытого состояния,
    которое можно изменить. Все что у него есть - доступно читателю. Он не представляет работу, он является
    именно данными для работы.

    Каждый luaobject структурного типа неизменяем, создайте новую структуру через `base.new()`,
    если вам нужно что-то изменить и при этом этот `base` является именно классом, а не экземпляром класса.
]==]
export type struct = extend<{
	read clone: <T>(self: T, change: unknown?) -> T,
	read each: <T>(self: struct, type: string, f: (value: T) -> T) -> { [unknown]: T },
}, luaobject>

--[==[
    Объект который представляет переменную.

    Поскольку это объект, он имеет ссылочный тип. Это значит, что можно передавать наружу объект переменной
    и изменить его значение, если это возможно.
]==]
export type variable<T = unknown> = extend<{
    --[==[
        Возвращает хранимое значение
    ]==]
	read get_value: (self: variable<T>) -> T,

    --[==[
        Устанавливает хранимое значение
    ]==]
	read set_value: (self: variable<T>, to: T) -> (),
}, luaobject>

--[==[
    Представляет собой ссылку на значение.

    Указатель может указывать на существующее значение или представлять неразрешенную ссылку.
    Он поддерживает считывание указанного значения, изменение целевого объекта и
    проверку того, существует ли целевой объект в настоящее время или хранится в качестве жесткой ссылки.
]==]
export type pointer<T = unknown> = extend<
	{
		read get_pointed: (self: pointer<T>) -> T,

		--[==[
        `Attention`, в будущих патчах это будет изменено.

        Это одноразовая операция установки объекта, на который указывает указатель. Дальше будут ошибки.
    ]==]
		read set_point: (self: pointer<T>, to: T, hard: boolean?) -> (),

    --[==[
        `Deprecated`, в будущих патчах это будет удалено.

        Указатель может иметь жесткую ссылку на объекты на которые указывает.
    ]==]
		read is_pointed_hard: (self: pointer<T>) -> boolean,

		read is_pointed_exists: (self: pointer<T>) -> boolean,

		--[==[
        Для указанных вариантов режимов работы указателя можно установить специфичное состояние.

        По умолчанию они все выключены.
    ]==]
		-- read set_mode: (self: pointer<T>, to: boolean, ...enumitem_pointer_mode) -> (),

		--[==[
        Возвращает режимы работы всех полученных состояний для этого указателя.
    ]==]
		-- read get_mode: (self: pointer<T>, ...ernumitem_pointer_mode) -> ...boolean
	},
	luaobject
>

--[==[
    Объект, представляющий собой путь к экземпляру, который может быть абсолютным или относительным.

    Используется как способ поиска объектов в иерархии. Выгодней иметь прямую ссылку на экземпляр, чем
    такой объект, если только нужно получить экземпляр. Если же экземпляр необязателен, то следует использовать
    этот объект
]==]
export type path = extend<{
    --[==[
        Может быть абсолютным или относительным.
    ]==]
    path_to_instance_parent: string?,

    --[==[
        Если объявлен `path.is_path_strict` как `true`, то объект будет проверять, что полученный
        экземпляр имеет ровно это имя
    ]==]
    expected_instance_name: string?,

    --[==[
        Объект при получении экземпляра будет сверять, что данный экземпляр является
        именно указанным классом.
    ]==]
    expected_instance_class: string?,

    --[==[
        Для обычных методов получения того или иного объекта делает спуфинг, если включено. То есть
        подменяет отсутствующий экземпляр на тот, что по идее нужно было получить.
    ]==]
    spoof: boolean,

    --[==[
        При спуфинге заставляет брать любой экземпляр у которого один и тот же класс, что и с ожидаемым.
        Если включен `path.is_path_strict`, то это не будет работать, потому что ожидаемый экземпляр
        должен иметь строго определенное имя.
    ]==]
    spoof_takes_any_similar_instance: boolean,

    --[==[
        Путь ведет строго к определенному объекту, он обязан существовать.

        В таком случае путь указывается с именем объекта.
    ]==]
    is_path_strict: boolean,

    --[==[
        Путь будет интерпретироваться как абсолютный путь, если is_path_absolute установлен в true.
    ]==]
    is_path_absolute: boolean,

    --[==[
        Вернет экземпляр по абсолютному пути. Выбрасывает ошибку при отсутствии экземпляра либо
        спуфит, если включено такое свойство в объекте.
    ]==]
    read get_by_absolute_path: (self: path) -> Instance,

    --[==[
        Вернет экземпляр по относительному пути. Выбрасывает ошибку при отсутсвии экземпляра либо
        спуфит, если включено такое свойство в объекте.
    ]==]
    read get_by_relative_path: (self: path, root: Instance|path) -> Instance,

    --[==[
        Подбирает нужный способ получить экземпляр при помощи инстанса. Выбрасывает ошибку при отсутствии экземпляра либо
        спуфит, если включено такое свойство в объекте. Требует root, чтобы гарантировать инвариант поиска.
    ]==]
    read get_by_path: (self: path, root: Instance|path) -> Instance,

    --[==[
        Вернет экземпляр по абсолютному пути, либо вернет `nil`. Ошибки не кидает.
    ]==]
    read get_by_absolute_path_or_nil: (self: path) -> Instance?,

    --[==[
        Вернет экземпляр по относительному пути через root экземпляр или путь, либо вернет `nil`.
        Ошибки не кидает.
    ]==]
    read get_by_relative_path_or_nil: (self: path, root: Instance|path|nil) -> Instance?,

    --[==[
        Вернет экземпляр с автоматическим поиском нужного метода. Требует root, если понадобится. Либо
        вернет `nil`. Ошибки не кидает.
    ]==]
    read get_by_path_or_nil: (self: path, root: Instance|path|nil) -> Instance?,

    --[==[
        Устанавливает абсолютный путь к экземпляру. Автоматически изменяет настройки пути,
        корректируя его `path.is_absolute_path` на `true`.
    ]==]
    read set_absolute_path_to: (self: path, to: Instance|path) -> (),

    --[==[
        Устанавливает относительный путь к экземпляру. Автоматически изменяет настройки пути,
        корректируя его `path.is_absolute_path` на `false`.
    ]==]
    read set_relative_path_to: (self: path, root: Instance|path, to: Instance|path) -> (),

    --[==[
        Проверяет, существует ли экземпляр вообще
    ]==]
    read has_instance: (self: path) -> boolean,
}, luaobject>


--[==[
    Представляет типизированный наблюдатель уведомлений, который управляет подписками на уведомления enumitem и enumobject.

    Наблюдатель управляет подписками с помощью объектов-указателей.
    Каждая подписка может иметь свой собственный режим подключения и дополнительные параметры.
]==]
export type observer<T = enumitem | enumobject> = extend<
	{
		--[==[
            Отложенный вызов откладывает выполнение вызова каждого следующего соединения на конец работы планировщика
            в этом такте. Его можно включить из соединения, или выключить, и это будет применяться к любому соединению
            дальше.
        ]==]
		deferred_call: boolean,

		--[==[
            Отложенный режим откладывает выполнение начала вызова всех соединений на конец работы планировщика в этом
            такте. То есть сам факт уведомления и вызова всех соединений отложен.
        ]==]
		deferred_mode: boolean,

		--[==[
            Новые соединения будут просто выбрасываться, вместо этого будут возвращаться пустые указатели на ничего,
            объект спокойно проигнорирует если передать их в него.
        ]==]
		allow_new_connections: boolean,

		--[==[
            Подписаться на какое-либо уведомление в каком-либо режиме с какими-либо обработчиками, которые
            поддерживает этот объект. Вернет столько же указателей, сколько передано обработчиков.

            Может вернуть пустые указатели. Они будут проигнорированы, если попадут обратно в объект.
        ]==]
		read subscribe: (
			self: observer<T>,
			on: observer_on<T>,
			mode: enumitem_connection_variant,
			...observer_var<T>
		) -> ...pointer,

		--[==[
            По указателю можно отписать тот или иной обработчик. Если такого нет, то этот указатель проигнорируется.
        ]==]
		read unsubscribe: (self: observer<T>, ...pointer) -> (),

		--[==[
            Перезаписать режим работы подписки на другой через указатель.
        ]==]
		read subscription_set_mode: (self: observer<T>, to: enumitem_connection_variant, ...pointer) -> (),

		--[==[
            Получить режим работы подписки через указатель.
        ]==]
		read subscription_get_mode: (self: observer<T>, ...pointer) -> ...enumitem_connection_variant,

		--[==[
            Вызвать все подписки указанного уведомления с такими-то аргументами.
        ]==]
		read notificate: (self: observer<T>, notification: observer_on<T>, ...unknown) -> (),
	}
	& private_storage<observer<T>>,
	luaobject
>

--[==[
    Alias-тип для поддерживаемых видов уведомлений
]==]
type observer_on<T = enumitem> = T | { T } | enumobject | { enumobject } | { T | enumobject }
--[==[
    Alias-тип для поддерживаемых работников
]==]
type observer_var<T = unknown> = ((...any) -> ()) | thread | observer<T>

--[==[
    Represents an luaobject that performs a single role in the system as a singleton
]==]
export type service = extend<{} & nameable & switchable, luaobject>

--[==[
    Represents an luaobject with an explicit resource-release lifecycle

    A disposable provides a free operation that releases resources owned by the luaobject
    The operation may be performed immediately or deferred
]==]
export type disposable = extend<{
	--[==[
    Releases the resources associated with the disposable luaobject.

    deffered determines whether the release is deferred. When omitted, the implementation uses its default behavior.

    ```luau
    value:free() -- GC will be able to collect this value later
    ```
    ]==]
	read free: (self: disposable) -> (),

	--[==[
        Returns the state of the luaobject at the current time of the request
    ]==]
	read is_releasing: (self: disposable) -> boolean,

	--[==[
        Connects an outside observer to the moment of release
    ]==]
	read finally: <T>(self: disposable, ...((luaobject_identity: string) -> ())|disposable) -> (),
} & private_storage<disposable>, luaobject>

export type scheduler_teta<T... = ...any> = thread | (T...) -> ()

--[==[
    Объект для управления задачами внутри самого Luau вне зависимости от Host приложения.

    По сути это универсальная `task` библиотека в виде объекта, вынесенная за рамки обычного роблокса.
]==]
export type scheduler = extend<{
	--[==[
        Планирует коррутину в любое удобное время для планировщика. Коррутина будет вызвана
        в следующем `scheduler:process()` либо в этом же цикле, если уже запланированная
        коррутина подала запрос.
    ]==]
	read plan: <T...>(self: scheduler, t: scheduler_teta<T...>, T...) -> thread,

	--[==[
        Пробует найти в каком именно обработчике зарегистрирована эта коррутина. Если не найдет,
        значит она вообще не зарегистрирована в `scheduler` классе и его наследниках. Скорее всего
        она либо создана
    ]==]
	read whose: (self: scheduler, c: thread?) -> scheduler?,

	--[==[
        Отменяет коррутину из планировщика. Функция безопасна для вызова, она тихо проигнорирует
        если эта коррутина не была запланирована.
    ]==]
	read cancel: (self: scheduler, c: thread?) -> (),

	--[==[
        Проверяет, является ли эта коррутина запланированной для выполнения
    ]==]
	read is_planned: (self: scheduler, c: thread?) -> boolean,

	--[==[
        Проверяет, является ли эта коррутина в процессе ожидания или холда.
    ]==]
	read is_waiting: (self: scheduler, c: thread?) -> boolean,

    --[==[
        Проверяет, не была ли эта коррутина перехвачена извне?
    ]==]
    read is_foreign: (self: scheduler, c: thread?) -> boolean,

	--[==[
        Ставит текущую выполняемую коррутину на паузу до момента, когда не будет достигнуто указанное время
        в реальном `os.clock()` времени. После истечения времени ожидания в течении какого-то периода вызовет
        ожидавшую коррутину обратно.

        Функционал ожидания для кадрового (тикового) времени смотрите в
        других функциях, либо он может быть не реализован.
    ]==]
	read wait: (self: scheduler, time: number?) -> (),

	--[==[
        Коррутина будет запланирована на ожидание, но на сам факт не будет поставлена. Это должен будет
        сделать пользовательский код.
    ]==]
	read hold: (self: scheduler, time: number?) -> (),

	--[==[
        Планирует на конец `scheduler:process()` еще одну коррутину.

        Доступно только из коррутины, которая сейчас выполняется планировщиком.
    ]==]
	read last: <T...>(self: scheduler, t: scheduler_teta<T...>?, T...) -> (),

	--[==[
        Планирует на следующий планировочный этап еще одну коррутину. Эта коррутина будет выполняться
        сразу после текущей коррутины.

        Доступно только из коррутины, которая сейчас выполняется планировщиком.
    ]==]
	read next: <T...>(self: scheduler, t: scheduler_teta<T...>?, T...) -> (),

	--[==[
        Планировщик выполняет плановые задачи согласно циклу приложения. То, как именно будет работать
        вызов и когда - контроллируется управляющим кодом над планировщиком. Обычно эта работа выделяется
        Host приложению, но в случае с этим объектом эта работа доступна Luau коду.
    ]==]
	read process: (self: scheduler) -> (),

	--[==[
        Регистрирует внешнее хранилище источников управления планировщиками. Функция должна вернуть объект
        планировщика этой библиотеки, либо ничего. Если передать уже зарегистрированную функцию, то она будет
        убрана с регистрации. Работает как `toggle`.

        Регистрируется на вообще весь класс.
    ]==]
	read external_source: (fn: (thread) -> scheduler?) -> (),
}, luaobject>













































-- Common

--[==[
    Универсальный объект-ивент, который используется в ситуациях когда требуется поддержка полноценной системы
    доставки уведомлений и управления соединениями.

    Стандартный `observer` покрывает практически любую ситуацию связанную с подписчиками и уведомлениями, но
    этот класс специально разбит на несколько элементов и частей, которые почти не зависят друг от друга и
    предоставляют более явные инструменты управления.
]==]
export type event<T = enumitem<any>, U... = ...unknown> = extend<{

	--[==[
        Подключиться к ивенту на указанное уведомление.
    ]==]
	read connect: <T0>(self: event<T, U...>, on: T, f: ((U...) -> ()) | thread | observer<T>) -> connection<T, U...>,

	--[==[
        Подключиться к ивенту на указанное уведомление одноразово.
    ]==]
	read once: <T0>(self: event<T, U...>, on: T, f: ((U...) -> ()) | thread | observer<T>) -> connection<T, U...>,

	--[==[
        Подождать, пока не произойдет указанное уведомление.
    ]==]
	read wait: (self: event<T, U...>, on: T) -> U...,

	--[==[
        Вызывает ивент с указанным уведомлением и аргументами, которые попадают релевантным соединениям в работу.
    ]==]
	read invoke: (self: event<T, U...>, on: T, U...) -> (),

	--[==[
        Вызывает ивент с указанным уведомлением и аргументами, которые попадают релевантным соединениям в работу.
    ]==]
    read invoke_deferred: (self: event<T, U...>, on: T, U...) -> (),

    --[==[
        Возвращает все релевантные
    ]==]
    read get_all_connections: (self: event<T,U...>, which_is_a: enumitem_connection_variant?) -> ...connection<T, U...>,

    --[==[
        Копирует соединения из одного ивента в другой.
    ]==]
    read copy_connections_from: (self: event<T, U...>, which_is_a: enumitem_connection_variant?, ...event) -> (),

    --[==[
        Удаляет соединение из ивента, если оно конечно есть.
    ]==]
    read disconnect_connection: (self: event<T,U...>, ...connection) -> (),

    --[==[
        Удаляет все соединения из ивента, если они конечно есть. Может удалить соединения определенного типа.
    ]==]
    read disconnect_all_connections: (self: event<T,U...>, which_is_a: enumitem_connection_variant?) -> (),
}, observer<T>>

--[==[
    Универсальный объект-соединение, который используется в ситуациях когда требуется поддержка полноценной системы
    доставки уведомлений и управления соединениями.

    Стандартный `observer` покрывает практически любую ситуацию связанную с подписчиками и уведомлениями, но
    этот класс специально разбит на несколько элементов и частей, которые почти не зависят друг от друга и
    предоставляют более явные инструменты управления.
]==]
export type connection<T = enumitem, U... = ()> = extend<{
	--[==[
        В данном случае это сколько раз вызывать работника, которого представляет это соединение
    ]==]
	count: number,

	--[==[
        Возвращает режим работы соединения.
    ]==]
	read get_mode: (self: connection<T, U...>) -> enumitem_connection_variant,
	--[==[
        Устанавливает режим работы соединения.
    ]==]
	read set_mode: (self: connection<T, U...>, mode: enumitem_connection_variant) -> (),

	--[==[
        Подключено ли соединение?
    ]==]
	read is_connected: (self: connection<T, U...>) -> boolean,

	--[==[
        Если это возможно, отключит соединение.
    ]==]
	read disconnect: (self: connection<T, U...>) -> (),
} & invokeable<connection<T, U...>, U...> & expected_calltype<T?>, observer<enumitem_setup_notification>>

--[==[
    Представляет любой сигнал. Может иметь источник сигнала.
]==]
export type signal<T... = ...unknown> = extend<{
    --[==[
        Сигналы будут срабатывать в параллельной фазе
    ]==]
    use_parallel_signals: boolean,

    --[==[
        Возвращает ивент, который активируется только при поступлении этого сигнала. Работает на все `enumitem`,
        привязанные к этому ивенту.
    ]==]
	read get_signal_event: (self: signal<T...>) -> event<enumitem_default_variant, T...>,

	--[==[
        Возвращает источник сигнала, функцию которая вызывает этот сигнал.
    ]==]
	read get_signal_source: (self: signal<T...>) -> (() -> ())?,

	--[==[
        Дает возможность установить источник сигнала или убрать его вовсе.
    ]==]
	read set_signal_source: (self: signal<T...>, to: (() -> ())?) -> (),

    --[==[
        Функция, которую будут дергать эти сигналы
    ]==]
    read apply_as_source: (self: signal<T...>, ...RBXScriptSignal) -> ()
}, luaobject>

--[==[
    Аналог `variable`. Не имеет истории, однако уведомляет об операциях с ним.

    Этот объект представляется как именно значение с getter/setter, а не как `variable` в полном смысле.
    Да они по сути выполняют одну и ту же роль. Используйте `variable` в случаях когда вы передаете что-то наружу,
    что по сути является ссылочным типом данных (ака &var name)
]==]
export type value<T = unknown> = extend<{
	--[==[
        Получить хранимое значение.
    ]==]
	read get_value: (self: value<T>) -> T?,

	--[==[
        Установить хранимое значение.

        Если указан `default`, то при `nil` будет возвращаться значение, с которым был `default`. Это можно
        перезаписать.
    ]==]
	read set_value: (self: value<T>, new: T?, default: boolean?) -> (),
}, observer<enumitem_operation_variant>>

--[==[
    Объект, представляющий собой таймер. Он работает через планировщик.
]==]
export type timer = extend<{
	--[==[
        Получает пройденное время с начала работы таймера.
    ]==]
	read get_elapsed: (self: timer) -> number,

	--[==[
        Получает оставшееся время с начала работы таймера.
    ]==]
	read get_remaining: (self: timer) -> number,

	--[==[
        Получает время которое таймеру нужно работать.
    ]==]
	read get_duration: (self: timer) -> number,

	--[==[
        Получает шаг, с которым таймер записывает пройденное время.
    ]==]
	read get_step: (self: timer) -> number,

	--[==[
        Указать время, которое нужно отработать таймеру.
    ]==]
	read set_duration: (self: timer, to: number) -> (),

	--[==[
        Указать шаг, с которым таймер записывает пройденное время.
    ]==]
	read set_step: (self: timer, to: number) -> (),

	--[==[
        Работает ли сейчас таймер?
    ]==]
	read is_running: (self: timer) -> boolean,

	--[==[
        Завершился ли таймер?
    ]==]
	read is_finished: (self: timer) -> boolean,
} & iterations<number> & modifier<number> & controllable<timer>, observer<enumitem_tick_notification>>

--[==[
    Объект, представляющий динамический доступ к требуемому объекту.

    Он не гарантирует наличие объекта, безопасность подключения к его сигналам или всего
    остального. Он контроллируется внешними управляющими механизмами
]==]
export type reference<T = unknown> = extend<{
	--[==[
        Выполнит эту функцию синхронно.
    ]==]
	read call_function: (self: reference<T>, name: any, ...any) -> ...any,

	--[==[
        Выполнит этот метод синхронно.

        Вызов в формате метода существует потому что существует `__namecall` метаметод. Не все
        платформы разрешают вызывать методы объекта через обычный вызов функции, поскольку
        часть кода может быть специально разбита под этот метаметод
    ]==]
	read call_methode: (self: reference<T>, name: any, ...any) -> ...any,

	--[==[
        Пробует прочитать это поле и вернуть значение оттуда.
    ]==]
	read read_field: (self: reference<T>, name: any) -> unknown,

	--[==[
        Пробует записать это поле.
    ]==]
	read write_field: (self: reference<T>, name: any, to: any) -> (),

	--[==[
        Пробует узнать, существует ли у объекта то или иное поле.

        Проверяет это через pcall
    ]==]
	read has_field: (self: reference<T>, name: any, type: string?) -> boolean,
} & instanceable<reference<T>, T>, observer<enumitem_reference_notification>>

--[==[
    Объект, привязывающий класс к каждому инстансу с тегом `tag`

    Объект создается через `maker`, когда тег появился на инстансе внутри `ancestors`
    (по умолчанию workspace), и освобождается, когда тег сняли, инстанс удалили или
    он ушел из `ancestors`. `maker` - функция `(instance) -> T` или класс: тогда
    вызывается `maker:new()`, а инстанс передается в `set_instance`, если он есть

    О привязке и отвязке сообщает через `BinderNotification.Bound` / `Unbound`
    с аргументами `(instance, luaobject)`

    ```luau
    const doors = Binder:new({ tag = "Door", maker = Reference }) :: binder<reference>
    doors:subscribe(BinderNotification.Bound, ConnectionVariant.Ever, function(instance, door) end)
    doors:start()
    ```
]==]
export type binder<T = unknown> = extend<{
	--[==[
        То, к чему выполняется привязка
    ]==]
	tag: string,

	--[==[
        Функция вида `(instance) -> T` или класс. Если это класс, то тогда
        вызывается `maker:new()`, а инстанс передается в `set_instance`, если он есть.
    ]==]
	maker: binder_maker<T>?,

	--[==[
        Объект создается через `maker`, когда тег появился на инстансе внутри `ancestors`
        (по умолчанию workspace), и освобождается, когда тег сняли, инстанс удалили или
        он ушел из `ancestors`.
    ]==]
	ancestors: { Instance }?,

	--[==[
        Начать отслеживание.
    ]==]
	read start: (self: binder<T>) -> (),

	--[==[
        Остановить отслеживание.
    ]==]
	read stop: (self: binder<T>) -> (),

	--[==[
        Работает ли биндер сейчас?
    ]==]
	read is_started: (self: binder<T>) -> boolean,

	--[==[
        Попробует вытащить `luaobject` привязанный к экземпляру.
    ]==]
	read get_object: (self: binder<T>, instance: Instance) -> T?,

	--[==[
        Возвращает словарь в котором описана вся цепь привязей `luaobject` к экземпляру.
    ]==]
	read get_objects: (self: binder<T>) -> { [Instance]: T },
}, observer<enumitem_binder_notification>>

export type binder_maker<T = unknown> = ((instance: Instance) -> T) | { read new: (self: any) -> T }

--[==[
    Таблица, которая на самом деле уходит через remote
]==]
export type netpack_flat = {
	loaded: { any },
	count: number,
	to: { number },
	from: string,
	sender: number?,
	rpc: boolean,
}

--[==[
    Сетевой пакет: полезная нагрузка, кому он отправлен и типо откуда пришел

    `to` - ID получателей. На сервере он пустой, - значит никому. На сервере `sender`
    всегда выставляет SharedNet по настоящему отправителю, клиент его не подделает

    ```luau
    SharedNet:emit_event(event, NetPack:pack({ player }, "snapshot", data))
    event:connect(NetNotification.Received, function(pack: netpack)
        const action, value = pack:payload()
    end)
    ```
]==]
export type netpack = extend<{
	read loaded: { any },
	read count: number,
	read to: { number },
	read from: string,
	read sender: number?,
	read rpc: boolean,

	read pack: (self: netpack, to: { Player | number }?, ...any) -> netpack,
	read from_flat: (self: netpack, flat: unknown) -> netpack?,
	read payload: (self: netpack) -> ...any,
	read get_flat: (self: netpack) -> netpack_flat,
	read get_players: (self: netpack) -> { Player },
	read get_source: (self: netpack) -> enumitem_net_source?,
	read is_me_sender: (self: netpack) -> boolean,
}, struct>

--[==[
    Единственное место, где создаются remote. Канал (SharedNetLink, SharedNetVariant):

    Safe: RemoteEvent,
    Unsafe: UnreliableRemoteEvent,
    Internal: BindableEvent

    Сервер создает их в `ReplicatedStorage.sharednet`, клиент ждет их `timeout` секунд,
    поэтому на клиенте `get_event` блокирует поток. Пакеты приходят через
    `NetNotification.Received` Клиент приславший пакет с пометкой FromServer, кикается ez
]==]
export type sharednet_env = {
	max_network_packages: number,
	deploy_placement_name: string,
	rate_limit: number,
	rate_burst: number,
	rate_kick: number,
}

export type sharednet_env_patch = {
	max_network_packages: number?,
	deploy_placement_name: string?,
	rate_limit: number?,
	rate_burst: number?,
	rate_kick: number?,
}

export type sharednet = extend<{
		timeout: number,
		emitted: number,
		errors: number,

		read get_event: (
			self: sharednet,
			link: enumitem,
			variant: enumitem_shared_net_variant?
		) -> event<enumitem_net_notification, netpack>,
		read register_links: (self: sharednet, ...enumobject) -> (),
		read has_link: (self: sharednet, link: enumitem) -> boolean,
		read emit_event: (self: sharednet, event: event<enumitem_net_notification, netpack>, pack: netpack) -> (),
		read set_env: (self: sharednet, env: sharednet_env_patch | (env: sharednet_env) -> sharednet_env) -> sharednet_env,
		read get_env: (self: sharednet) -> sharednet_env,
	},
	service
>

--[==[
    Путь внутри данных игрока: `"settings/music"` или `{ "settings", "music" }`
]==]
export type data_path = string | { string }
export type data_snapshot = { [string]: any }

--[==[
    Серверная сторона данных игрока на ProfileStore, шаблон в `ServerStorage.prefs.data`

    Клиенту уходят только ключи из `data.replicated`. Менять данные через `set_value` /
    `update_value`, чтобы репликация не разошлась. События через `get_data_event()`:
    `DataNotification.DataLoaded` / `DataReleased` (player, data), `DataStateChanged` (player, state),
    `DataMessage` (player, message, processed)
]==]
export type dataserver_env = {
	store: string?,
	key: (id: number) -> string,
	template: data_snapshot,
	replicating: { [string]: boolean },
	studio: { mock: boolean },
}

export type dataserver_env_patch = {
	store: string?,
	key: ((id: number) -> string)?,
	template: data_snapshot?,
	replicating: { [string]: boolean }?,
	studio: { mock: boolean? }?,
}

export type dataserver = extend<{
	read start: (self: dataserver) -> (),
	read set_env: (self: dataserver, env: dataserver_env_patch | (env: dataserver_env) -> dataserver_env) -> dataserver_env,
	read get_env: (self: dataserver) -> dataserver_env,
	read get_state: (self: dataserver, player: Player) -> enumitem_data_state,
	read get_data: (self: dataserver, player: Player) -> data_snapshot?,
	--[==[
        Ждёт, пока данные игрока не загрузятся, и возвращает их (`get_data`).

        Ждёт, пока состояние игрока ещё не выставлено (DataServer не успел начать загрузку) или равно
        `DataState.ProfileLoading`. Просыпается только на `DataStateChanged` своего игрока.

        Возвращает `nil` сразу, без ожидания:
        - если DataServer не запущен (`start` не вызван), с предупреждением `std:check`;
        - если игрок уже не в игре;
        - если состояние `DataState.ProfileReleased` (профиль не загрузился или уже освобождён);
        - если поток нельзя приостановить, а данные ещё не готовы.

        Если игрок выходит во время ожидания, возвращает `nil`.
    ]==]
	read wait_data: (self: dataserver, player: Player) -> data_snapshot?,
	read get_value: <T>(self: dataserver, player: Player, path: data_path) -> T,
	read set_value: (self: dataserver, player: Player, path: data_path, to: unknown) -> (),
	read update_value: <T>(self: dataserver, player: Player, path: data_path, f: (current: T) -> T) -> T,
	read reset: (self: dataserver, player: Player) -> boolean,
	read send_message: (self: dataserver, user_id: number, message: { [string]: any }) -> boolean,
	read get_data_event: (self: dataserver) -> event<enumitem_data_notification, ...any>,
}, service>

--[==[
    Клиентская сторона данных игрока: копия реплицируемых ключей только для чтения.
    События через `get_data_event()`: `DataNotification.DataLoaded`, `DataChanged` (path, value)
]==]
export type dataclient = extend<{
	read start: (self: dataclient) -> (),
	read get_state: (self: dataclient) -> enumitem_data_state,
	read get_value: <T>(self: dataclient, path: data_path) -> T,
	read wait_loaded: (self: dataclient) -> (),
	read get_data_event: (self: dataclient) -> event<enumitem_data_notification, ...any>,
}, service>

--[==[
    Объект, представляющий небольшой самостоятельный контроллер.

    Классы побольше могут иметь его в качестве небольшого управляющего элемента.
]==]
export type controller = extend<{
	--[==[
        Это текущее состояние контроллера.
    ]==]
	state: enumitem_controller_state,
} & operatable<controller>, observer<enumitem_controller_state>>

--[==[
    Объект, представляющий типичнейший stack.
]==]
export type stack<T = unknown> = extend<{
	--[==[
        Максимальная глубина.
    ]==]
	max: number,

	--[==[
        Забрать сверху стопки.
    ]==]
	read pick: (self: stack<T>) -> T?,

	--[==[
        Положить на верх стопки.
    ]==]
	read put: (self: stack<T>, value: T) -> (),

	--[==[
        Выдать количество элементов в стопке.
    ]==]
	read count: (self: stack<T>) -> number,
}, luaobject>

--[==[
    Объект, представляющий типичнейшую очередь.
]==]
export type queue<T = unknown> = extend<{
	--[==[
        Максимальная длина.
    ]==]
	max: number,

	--[==[
        Забрать из начала очереди.
    ]==]
	read pick: (self: queue<T>) -> T?,

	--[==[
        Положить в конец очереди.
    ]==]
	read put: (self: queue<T>, value: T) -> (),

	--[==[
        Выдать количество элементов в очереди.
    ]==]
	read count: (self: queue<T>) -> number,
}, luaobject>

--[==[
    Объект, представляющий собой канонический способ очистки вообще кого угодно
]==]
export type maid = extend<list_operations<maid, Instance|disposable|path|reference|RBXScriptConnection|connection|event>, disposable>

--[==[
    Объект, представляющий ленивое шаблонное хранилище
]==]
export type template <T = unknown, U = unknown> = extend<{
    --[==[
        Возвращает установочный шаблон, применяемый для всех новых значений в хранилище
    ]==]
	read get_template: (self: template) -> { [unknown]: unknown } & T,

    --[==[
        Устанавливает новый шаблон. Не меняет старые данные. Некорректный шаблон отбрасывается и не меняется.
    ]==]
	read set_template: (self: template, to: {[unknown]: unknown} & T) -> (),

    --[==[
        Принудительно освобождает ключ от значения.
    ]==]
	read free_for: (self: template, key: U) -> (),

    --[==[
        Создает по текущему шаблону новое значение, либо возвращает его если оно есть
    ]==]
	read allocate_for: (self: template, key: U) -> { [unknown]: unknown } & T,

    --[==[
        Проверяет, существует ли значение или нет в хранилище
    ]==]
    read exist_for: (self: template, key: U) -> boolean
}, observer<enumitem_operation_variant>>

--[==[
    Объект, представляющий ленивое хранилище
]==]
export type maybe<T = unknown, U = unknown> = extend<{

	--[==[
        Выполяет переданную функцию только 1 раз, далее возвращает кэшированный
        результат работы функции
    ]==]
	read extract: (self: maybe<T, U>, it: U, make: () -> T) -> T,

	--[==[
        Создает наследника переданного объекта, а затем возвращает его как кэшированный
        результат работы
    ]==]
	read enactment: (self: maybe<T, U>, it: U, of: luaobject) -> T,

	--[==[
        Для указанного `it` удаляет значение
    ]==]
	read erase: (self: maybe<T, U>, it: U) -> (),

	--[==[
        Проверяет, существует ли значение для указанного `it`
    ]==]
	read exist: (self: maybe<T, U>, it: U) -> boolean,
}, observer<enumitem_operation_variant>>


--[==[
    Класс, предназначенный для содержания экземпляров с параллельным хранилищем.
]==]
export type quant <T = unknown> = extend<{
    read get_quantized_class: (self: quant<T>) -> string?,
    read set_quantized_class: (self: quant<T>, to: string?) -> ()
} & list_operations<quant<T>, T> & list_checks<quant<T>>, observer<enumitem_operation_variant>>

--[==[
    Объект, представляющий машину состояний.

    Это не конечный автомат, потому что она может сводиться не только к одному лишь состоянию в моменте. По сути
    этот объект представляет из себя реестр состояний, которые могут быть активны в данный момент. Это не мешает
    превратить его в конечный автомат.
]==]
export type stateregistry<T = enumitem> = extend<{

	--[==[
        Получает текущее состояние для указанных элементов. Если хотя бы один отсутствует, то вернется ложь.

        Элементы которые никогда не были в машине, то есть `nil` в ней, - учитываются как `false` состояния.
    ]==]
	read get_state: (self: stateregistry<T>, ...T) -> boolean,

	--[==[
        Поставить состояние на указанные элементы. Можно даже удалить их из объекта.
    ]==]
	read set_state: (self: stateregistry<T>, to: boolean?, ...T) -> (),

	--[==[
        Черный список состояний, элементы в котором никогда не будут становиться тем, что указали
        через `stateregistry:set_state(to, ...)`. Объект будет игнорировать эти операции.

        Работает как `toggle`. Добавляет если не было, удаляет если был.
    ]==]
	read blacklist: (self: stateregistry<T>, ...T) -> (),
}, observer<enumitem_statemachine_notification>>

-- Physics

--[==[
    Общий абстрактный тип для пропорционально-интегрально-дифференциальных регуляторов,
    работающих с векторами или числами.
    
    Используется в физических контроллерах (entity, движение/высота/вращение) для превращения «ошибки» 
    (насколько текущее состояние отличается от желаемого) в «управляющее воздействие» (ускорение, лифт, угловая скорость).
]==]
export type kinematiccontroller<T = number> = extend<{
	--[==[ 
        Пропорциональный коэффициент: выход += proportional * error.
        Определяет «жёсткость» реакции на ошибку.
	]==]
	proportional: number,

	--[==[ 
        Ограничение модуля выхода. Контроллер клиппит результат в [-output_limit, output_limit].
        Защищает физику от рывков при больших ошибках.
	]==]
	output_limit: number,

	--[==[ 
        Подаёт на вход уже готовую ошибку `error` (setpoint - measurement) и возвращает управляющее воздействие.
        Вызывается раз в кадр с `delta` — контроллер использует его для интеграла/производной.
	]==]
	read apply_error: (self: kinematiccontroller<T>, error: T, delta: number) -> T,

	--[==[ 
        Удобная обёртка над `apply_error`: принимает `setpoint` и `measurement`, считает ошибку внутри.
        Возвращает то же управляющее воздействие.
	]==]
	read apply_measurement: (self: kinematiccontroller<T>, setpoint: T, measurement: T, delta: number) -> T,

	--[==[ 
	    Последнее вычисленное управляющее воздействие. `nil` если контроллер ещё не вызывался или был сброшен.
	]==]
	read get_output: (self: kinematiccontroller<T>) -> T?,

	--[==[ 
	    Последняя ошибка (setpoint - measurement) с момента последнего вызова. `nil` до первого вызова или после `reset`.
	]==]
	read get_error: (self: kinematiccontroller<T>) -> T?,

	--[==[ 
        Сбрасывает внутреннее состояние контроллера (накопленный интеграл, предыдущую ошибку, выход).
        Нужно вызывать при телепортации, респавне или смене цели, чтобы не тащить «историю» в новый режим.
	]==]
	read reset: (self: kinematiccontroller<T>) -> (),
}, luaobject>

--[==[ 
    Только пропорциональная составляющая: output = clamp(proportional * error, ±output_limit).
    Простой и предсказуемый; может давать «перелёт» без демпфирования.
]==]
export type pcontroller<T = number> = extend<{}, kinematiccontroller<T>>

--[==[ 
    Пропорционально-интегральный контроллер. Дополнительно накапливает ошибку во времени —
    компенсирует постоянное внешнее сопротивление (трение, скольжение).
]==]
export type picontroller<T = number> = extend<{
	--[==[ 
        Коэффициент интегральной составляющей: накопленная ошибка * integral.
        Устраняет статическую ошибку, но легко «разгоняется» при долгой ошибке одного знака.
	]==]
	integral: number,

	--[==[ 
	    Ограничение модуля накопленного интеграла. Защищает от windup — «залип��ния» интеграла после насыщения.
	]==]
	integral_limit: number,
}, kinematiccontroller<T>>

--[==[ 
    Пропорционально-дифференциальный контроллер. D-составляющая реагирует на скорость изменения ошибки —
    гасит колебания и перелёт, делает отклик более «вязким».
]==]
export type pdcontroller<T = number> = extend<{
	--[==[ 
        Коэффициент дифференциальной составляющей: derivative * (error - previous_error) / delta.
        Чем выше — тем сильнее демпфирование, но и чувствительнее к ��уму/низкому FPS.
	]==]
	derivative: number,
}, kinematiccontroller<T>>

--[==[ 
    Полный PID-контроллер: пропорциональная + интегральная + дифференциальная составляющие.
    Максимальная гибкость настройки, но и больше параметров, которые надо подбирать.
]==]
export type pidcontroller<T = number> = extend<{
	--[==[ 
	    Коэффициент интегральной составляющей. Устраняет статическую ошибку.
	]==]
	integral: number,

	--[==[ 
	    Ограничение модуля накопленного интеграла. Защита от windup.
	]==]
	integral_limit: number,

	--[==[ 
	    Коэффициент дифференциальной составляющей. Демпфирует колебания и перелёт.
	]==]
	derivative: number,
}, kinematiccontroller<T>>

-- Component

export type profile<T = enumitem> = extend<{
	read uid: number,

	--[==[ 
        Возвращает инстанс профиля по `uid`, создавая его при необходимости (inline-кэш).
	    На клиенте для нового `uid` автоматически отправляет запрос на сервер. 
    ]==]
	read get_inlined: (self: profile<T>, uid: number) -> profile<T>,

	--[==[ 
        Возвращает `Player` с этим `uid`, если он сейчас в сервере, иначе `nil`. 
    ]==]
	read get_player: (self: profile<T>) -> Player?,

	--[==[ 
        Возвращает сохранённое значение пользовательской настройки по `of`. `nil` если не задано. 
    ]==]
	read get_configurated: <Y>(self: profile<T>, of: enumitem) -> Y?,

	--[==[ 
        Unix-время первого захода пользователя. `0` если данных нет. 
    ]==]
	read get_joined_at: (self: profile<T>) -> number,

	--[==[ 
        Unix-время последнего онлайна. `0` если данных нет. 
    ]==]
	read get_last_seen_at: (self: profile<T>) -> number,

	--[==[ 
        Unix-время онлайна перед последним (предыдущая сессия). `0` если данных нет. 
    ]==]
	read get_previous_seen_at: (self: profile<T>) -> number,

	--[==[ 
        Количество полных дней между предыдущей и последней сессиями. `0` если данных нет. 
    ]==]
	read get_days_since_previous_seen: (self: profile<T>) -> number,

	--[==[ 
        ID последнего сервера, где был пользователь. `nil` если неизвестен. 
    ]==]
	read get_last_server_id: (self: profile<T>) -> string?,

	--[==[ 
        Суммарное время в игре в секундах, включая текущую сессию если пользователь онлайн. 
    ]==]
	read get_played_time: (self: profile<T>) -> number,

	--[==[ 
        Количество сессий (заходов) пользователя. 
    ]==]
	read get_sessions: (self: profile<T>) -> number,

	--[==[ 
        Возвращает список выданных permissions из перечисления `of`. 
    ]==]
	read get_permissions: (self: profile<T>, of: enumobject) -> { T },

	--[==[ 
        Возвращает список активных restrictions из перечисления `of`. 
    ]==]
	read get_restrictions: (self: profile<T>, of: enumobject) -> { T },

	--[==[ 
        Устанавливает пользовательскую настройку. Только на сервере; на клиенте — no-op. 
    ]==]
	read set_configurated: (self: profile<T>, of: enumitem, to: unknown) -> (),

	--[==[ 
        Включает (`to = true`) или выключает указанные permissions. Только на сервере. 
    ]==]
	read set_permissions: (self: profile<T>, to: boolean, ...T) -> (),

	--[==[ 
        Включает (`to = true`) или выключает указанные restrictions. Только на сервере. 
    ]==]
	read set_restrictions: (self: profile<T>, to: boolean, ...T) -> (),

	--[==[ 
        Включает (`to = true`) или выключает указанные платформы (machine variant). Только на сервере. 
    ]==]
	read set_platform: (self: profile<T>, to: boolean, ...enumitem_user_machine_variant) -> (),

	--[==[ 
        Запрашивает данные с сервера. На сервере — no-op. 
    ]==]
	read request_data: (self: profile<T>) -> (),

	--[==[ 
        Ждёт загрузки профиля (yield). Возвращает сразу, если уже загружен или нельзя yield'ить. 
    ]==]
	read wait_loaded: (self: profile<T>) -> (),

	--[==[ 
        `true`, если у пользователя включены **все** указанные платформы. 
    ]==]
	read has_platform: (self: profile<T>, ...enumitem_user_machine_variant) -> boolean,

	--[==[ 
        По одному `boolean` на каждый аргумент: включён ли соответствующий restriction.
    ]==]
	read has_restrictions: (self: profile<T>, ...T) -> ...boolean,

	--[==[ 
        По одному `boolean` на каждый аргумент: включён ли соответствующий permission.
    ]==]
	read has_permissions: (self: profile<T>, ...T) -> ...boolean,

	--[==[ 
        `true`, если данные профиля загружены (сервер или снапшот с клиента).
    ]==]
	read is_loaded: (self: profile<T>) -> boolean,

	--[==[
        `true`, если пользователь сейчас в сервере.
    ]==]
	read is_in_server: (self: profile<T>) -> boolean,
} & referenceable<profile<T>, Player?>, observer<enumitem_user_notification>>

-- Game

--[==[
    Объект, представляющий доменную логику раунда и дающий возможность структурно управлять игрой
]==]
export type round = extend<{
	--[==[
        Возвращает специальную фракцию текущих персонажей в игре,
        она должна исчезнуть вместе с пропажей этого экземпляра
        объекта `round`
    ]==]
	read get_members: (self: round) -> faction,

	--[==[
        Возвращает настоящие зарегистрированные в раунде фракции
    ]==]
	read get_faction: (self: round) -> ...faction,

	--[==[
        Добавляет указанную фракцию в раунд, если ее не было
    ]==]
	read add_faction: (self: round, ...faction) -> (),

	--[==[
        Удаляет указанную фракцию из раунда, если она была в нем
    ]==]
	read rem_faction: (self: round, ...faction) -> (),

	--[==[
        Проверяет, есть ли данная фракция в этом раунде или нет
    ]==]
	read has_faction: (self: round, ...faction) -> boolean,

	--[==[
        Для всех указанных участников возвращаются те фракции, в которых они
        состоят в этом раунде

        Не возвращается фракция members, это техническая фракция
    ]==]
	read find_member: (self: round, ...character) -> { [character]: { faction }? },
} & stateable<round, enumitem_round_state>, timer>

--[==[
    Объект, хранящий в себе список персонажей, которые к этой
    фракции принадлежат на данный момент

    Фракция представляет собой не сколько фракцию, сколько аналог
    объекта `Team`, перенесенного в логику

    Используются объекты `character` как участники, поскольку доменная
    сущность которая управляет `character` независима от них и наоборот:
    `character` может существовать и сам по себе, его не интересует
    кто им управляет и управляет ли
]==]
export type faction = extend<{
	--[==[
        Возвращает всех участников персонажей для этой фракции

        Узнать какой персонаж к какому игроку или машине принадлежит
        можно через сервисы, фракция не занимается этим
    ]==]
	read get_member: (self: faction) -> ...character,

	--[==[
        Добавить нового участника в фракцию, если его нет
    ]==]
	read add_member: (self: faction, ...character) -> (),

	--[==[
        Удалить участника из фракции, если он в ней был
    ]==]
	read rem_member: (self: faction, ...character) -> (),

	--[==[
        Проверить является ли персонаж участником этой фракции
    ]==]
	read is_member: (self: faction, ...character) -> ...boolean,
} & nameable, observer<enumitem_faction_notification>>

--[==[
    Объект, представляющий собой логическую сущность "персонаж"

    У этого объекта нет ответа на вопрос как именно этот персонаж работает,
    он отвечает прежде всего на вопрос: "что сейчас делает игра с персонажем"

    Поскольку он не является фактическим состоянием персонажа, его связанность
    с рантаймом почти нулевая и завязана в основе исключительно на том как
    система интерпретирует эту логическую сущность

    Дальнейшие операции и работа с ними производится исключительно
]==]
export type character = extend<
	{
		--[==[
        Получить текущий токен персонажа

        Токен - специальный ключ, по которому для этого персонажа могут быть
        подобраны подходящие ему предметы, способности, снаряжение или
        модели

        Это используется в сервисах, которым необходимо выдавать релевантные
        данные к этому объекту, при этом не давая ему право обладать этими
        данными
    ]==]
		read get_token: (self: character) -> enumitem,

		--[==[
        Установить новый токен персонажа

        Токен - специальный ключ, по которому для этого персонажа могут быть
        подобраны подходящие ему предметы, способности, снаряжение или
        модели

        Это используется в сервисах, которым необходимо выдавать релевантные
        данные к этому объекту, при этом не давая ему право обладать этими
        данными
    ]==]
		read set_token: (self: character, to: enumitem) -> (),

		--[==[
        У персонажа как такового определенных констант параметров нет, они создаются
        динамически при обращении. В ситуации когда они не были созданы будут предпочитаться
        стандартные данные от `characterinfo`, иначе динамические

        Это создано для того чтобы не определять десятки тысяч параметров персонажа, которых
        у него могут быть чуть ли не бесконечно много

        В этом конструкторе по умолчанию `всегда` создается релевантный по типу `value`
    ]==]
		read get_parameter: (self: character, ...enumitem_character_parameter_variant) -> ...value<number>,

		--[==[
        Был ли данный параметр создан когда-либо для этого персонажа?
    ]==]
		read has_parameter: (self: character, ...enumitem_character_parameter_variant) -> boolean,

		--[==[
        Использует `self.token` для доступа в хранилище способностей,
        после чего самостоятельно выбирает нужный пакет и возвращает его
    ]==]
		read get_abilities: (self: character) -> ...ability,

		--[==[
        Возвращает инвентарь конкретного персонажа и то чем он сейчас
        обладает
    ]==]
		read get_inventory: (self: character) -> inventory,
		read get_equipped: (self: character) -> iteminstance?,
		read set_equipped: (self: character, to: iteminstance?) -> (),
		read take_item: (self: character, ...iteminstance) -> (),
		read drop_item: (self: character, ...iteminstance) -> (),
		read use_item: (self: character, context: enumitem_item_context, delta: number) -> (),

		--[==[
        Возвращает референс на модель персонажа
    ]==]
		read get_model_reference: (self: character) -> reference<Model?>,
	} & informable<character, characterinfo>,
	observer
>

--[==[
    Объект, представляющий физические свойства для живой сущности. Воздействует на физические силы, тем самым
    и реализует самого себя.

    По крайней мере используется в качестве основного способа контроля передвижения, заменяя тем самым Humanoid.
    Формально не контроллирует ничего, это простой исполнитель для физического поведения.
]==]
export type entity = extend<{
    --[==[
        Направление в котором сущность совершает движение относительно своей скорости
    ]==]
	move_direction: vector,

    --[==[
        Переключение этого свойства в true вызывает прыжок.
    ]==]
	jump: boolean,

    --[==[
        Скорость с которой сущность движется
    ]==]
	walk_speed: number,

    --[==[
        Сила с которой сущность прыгает
    ]==]
	jump_power: number,

    --[==[
        Целевая высота «бедра» над полом — расстояние от root-парта персонажа до земли, которое PD-контроллер пытается удержать.
    ]==]
	hip_height: number,

    --[==[
        Направление вверх, определенное для этой сущности.
    ]==]
    up_direction: vector,


    --[==[
        Дополнительная длина луча ниже hip_height для поиска пола.
        То есть floor_reach — это допуск по «зазору» между корнем и полом, в пределах которого пол ещё «виден».
    ]==]
	floor_reach: number,

    --[==[
        Автоматический поворот персонажа в сторону движения
    ]==]
	auto_rotate: boolean,

    --[==[
        Флаг для какой оси угловой скорости контроллер имеет право перезаписывать данные.
    ]==]
	lock_rotation_x: boolean,

    --[==[
        Флаг для какой оси угловой скорости контроллер имеет право перезаписывать данные.
    ]==]
	lock_rotation_y: boolean,

    --[==[
        Флаг для какой оси угловой скорости контроллер имеет право перезаписывать данные.
    ]==]
	lock_rotation_z: boolean,


    
    --[==[ Возвращает `true`, если персонаж в текущем кадре считается стоящим на полу.

    Флаг вычисляется в `private.step` по результатам рейкаста вниз длиной `hip_height + floor_reach`:
    `grounded = distance ~= nil and not state.rising`.

    Особенности:
    - Работает как «coyote»-подобный допуск: пол детектируется даже если он чуть ниже `hip_height` (в пределах `floor_reach`).
    - Сбрасывается в `false` на время прыжка (`state.rising = true`) и при выключенном `enabled`, отсутствии `root`/`instance` или `delta <= 0`.
    - Возвращает `false` при приземлении только после того, как `velocity.y <= 0` (т.е. пока персонаж летит вверх — пол игнорируется).
    - Не учитывает реальную геометрию стояния — только результат последнего луча.
    ]==]
    read is_grounded: (self: entity) -> boolean,

    --[==[ Возвращает нормаль поверхности, на которой стоит персонаж.

    Вектор берётся из последнего успешного рейкаста вниз. Если луч не попал (`distance == nil`) или контроллер отключён — возвращается `of.up_direction` (по умолчанию `(0,1,0)`).

    Используется, например, для наклона персонажа по склону (см. `get_tilt` в `private.rotate`) и внешними системами для ориентации по рельефу.

    Важно: нормаль — это нормаль *поверхности*, а не ориентация персонажа. При отключённом `enabled` может содержать устаревшее значение из предыдущего успешного шага.
    ]==]
    read get_floor_normal: (self: entity) -> vector,

    --[==[ Возвращает расстояние от `root`-парта до пола по последнему рейкасту вниз.

    Значение в диапазоне `[0, hip_height + floor_reach]`, либо `nil`, если луч не попал (персонаж в воздухе дальше `floor_reach` от пола, или контроллер отключён / нет `instance` / `delta <= 0`).

    Служит measurement-сигналом для PD-контроллера высоты (`get_height_controller`) — setpoint там `hip_height`. Разница между ними и определяет вертикальный импульс:
    - `distance < hip_height` → lift вверх;
    - `distance > hip_height` → lift обрезается до `0`, работает только гравитация.

    Значение обновляется каждый `private.step`, в том числе в воздухе (где может быть `nil`).
    ]==]
    read get_floor_distance: (self: entity) -> number?,

    --[==[ Возвращает PI-контроллер горизонтального движения (`PIController<vector>`).

    Параметры по умолчанию (см. `private.new_movement`):
    - `proportional = 12`
    - `integral = 1`
    - `integral_limit = 8`
    - `output_limit = 250`

    Используется в `private.step` как `apply_measurement(direction * walk_speed, planar_velocity, delta)` — на вход идёт целевая горизонтальная скорость и текущая спроецированная на XZ-плоскость скорость; на выходе — ускорение, которое превращается в импульс через `mass * delta`.

    I-составляющая компенсирует постоянное сопротивление (трение, скольжение), поэтому важно вызывать `reset()` при телепортации/респавне — иначе накопленный интеграл даст «рывок».

    Можно заменить через `set_movement_controller`.
    ]==]
    read get_movement_controller: (self: entity) -> kinematiccontroller<vector>,

    --[==[ Возвращает PD-контроллер вертикальной высоты (`PDController<number>`).

    Параметры по умолчанию (см. `private.new_height`):
    - `proportional = 300`
    - `derivative = 35`
    - `output_limit = 1000`

    Используется в `private.step` только когда `state.grounded == true`:
    `lift = apply_measurement(hip_height, distance, delta)`.

    D-составляющая гасит колебания у целевой высоты — иначе высокий P (300) давал бы «пружинный» баунс. `output_limit = 1000` ограничивает максимальный вертикальный импульс.

    При прыжке, в воздухе и при отключённом `enabled` вызывается `height:reset()` — интегратор/производная сбрасываются, чтобы избежать накопленных артефактов при следующем приземлении.

    Можно заменить через `set_height_controller`.
    ]==]
    read get_height_controller: (self: entity) -> kinematiccontroller<number>,

    --[==[ Возвращает P-контроллер вращения (`PController<vector>`), работающий покомпонентно в осях мира.

    Параметры по умолчанию (см. `private.new_rotation`):
    - `proportional = 12`
    - `output_limit = 25`

    Используется в `private.rotate`: на вход идёт вектор ошибки `(tilt.x, yaw, tilt.z)`, где X/Z — наклон корня к `up_direction`, Y — угол между текущим `facing` и `state.look`. На выходе — целевая угловая скорость, которая напрямую пишется в `set_angular_velocity` (с пропуском осей, где соответствующий `lock_rotation_* = false`).

    Обратите внимание: это **P**, не PD — при резких разворотах yaw возможен «перелёт»/колебание. При необходимости замените на PD через `set_rotation_controller`.

    Можно заменить через `set_rotation_controller`.
    ]==]
    read get_rotation_controller: (self: entity) -> kinematiccontroller<vector>,

    --[==[ Устанавливает пользовательский контроллер горизонтального движения.

    Ожидаемый тип — `kinematiccontroller<vector>` (обычно `PIController<vector>`, но подойдёт любой совместимый). Заменяет дефолтный контроллер, созданный в `private.new_movement`.

    Требования/рекомендации к замене:
    - `apply_measurement(setpoint, measurement, delta)` должен принимать целевую и текущую скорость в плоскости XZ и возвращать ускорение (не импульс — умножение на `mass * delta` делает `private.step`).
    - Выход ограничивайте по модулю — большие значения дадут резкий рывок.
    - При смене контроллера на «живом» персонаже стоит вызвать `reset()` у нового, чтобы не тащить накопленный интеграл.

    Устанавливает значение по ключу `private.movement_key`. Тип контроллера не проверяется — при несовпадении сигнатуры будет runtime-ошибка в `private.step` (которая отключит entity через pcall-обёртку).
    ]==]
    read set_movement_controller: (self: entity, to: kinematiccontroller<vector>) -> (),

    --[==[ Устанавливает пользовательский контроллер высоты (`kinematiccontroller<number>`).

    Ожидаемый тип — `PDController<number>` или совместимый. Заменяет дефолтный контроллер, созданный в `private.new_height`.

    Требования/рекомендации к замене:
    - `apply_measurement(setpoint, measurement, delta)` должен принимать `hip_height` (setpoint) и текущую дистанцию до пола (measurement) и возвращать **лифт** (ускорение/силу), который затем прибавляется к `gravity` и превращается в импульс `mass * delta`.
    - Контроллер вызывается **только при `state.grounded == true`**; в воздухе и при прыжке — `reset()`.
    - Наличие D-составляющей крайне желательно: чистый P при высоком коэффициенте даст баунс.
    - `output_limit` должен быть с запасом больше `-gravity`, иначе персонаж не сможет удержать высоту.

    Устанавливает значение по ключу `private.height_key`. При несовпадении сигнатуры — runtime-ошибка в `private.step` (entity будет отключён через pcall).
    ]==]
    read set_height_controller: (self: entity, to: kinematiccontroller<number>) -> (),

    --[==[ Устанавливает пользовательский контроллер вращения (`kinematiccontroller<vector>`).

    Ожидаемый тип — `PController<vector>` или `PDController<vector>`. Заменяет дефолтный контроллер, созданный в `private.new_rotation`.

    Требования/рекомендации к замене:
    - `apply_error(error, delta)` (не `apply_measurement`!) должен принимать вектор ошибки `(tilt.x, yaw, tilt.z)` в осях мира и возвращать целевую угловую скорость.
    - `private.rotate` пишет результат покомпонентно, пропуская оси с `lock_rotation_* = false` (там сохраняется текущая `angular` скорость).
    - `output_limit` разумно держать небольшим (дефолт — 25): большие угловые скорости легко «срывают» физику и приводят к jitter.
    - Для стабильного yaw при быстрых разворотах лучше использовать PD, а не P.

    Устанавливает значение по ключу `private.rotation_key`. При несовпадении сигнатуры — runtime-ошибка в `private.step` (entity будет отключён через pcall).
    ]==]
    read set_rotation_controller: (self: entity, to: kinematiccontroller<vector>) -> (),
} & switchable & referenceable<entity, PVInstance?>, disposable>

--[==[
    Объект инвентаря, хранящий в себе `ItemInstance` элементы.

    Данные внутри этого объекта хранятся как попало, поэтому никакого порядка через него нельзя добиться.
    Единственное, что гарантируется, — это лимит `max` на количество элементов. Один элемент инвентаря
    может быть как `itemstack` (количество внутри одного предмета), так и `itemobject` (уникальный экземпляр).
]==]
export type inventory = extend<{
	--[==[
        Это размер инвентаря. Сюда влезет только столько элементов, сколько указано в этом поле.

        Если внезапно размер инвентаря поменяется и старые предметы уже не смогут влезть, то инвентарь лишь
        уведомит об этом событии.
    ]==]
	max: number,

	--[==[
        Возвращает все элементы, которые есть в этом инвентаре. Порядок не гарантируется.
    ]==]
	read get_stacks: (self: inventory) -> ...iteminstance,

	--[==[
        Возвращает суммарное количество указанного предмета во всех элементах инвентаря.
        Для `itemobject` один экземпляр считается за единицу.
    ]==]
	read count_item: (self: inventory, of: item) -> number,

	--[==[
        Проверяет, есть ли в инвентаре хотя бы один экземпляр указанного предмета.
    ]==]
	read has_item: (self: inventory, of: item) -> boolean,

	--[==[
        Включает репликацию этого инвентаря под указанным ключом для перечисленных игроков.
        Передача `nil` в качестве ключа выключает репликацию. Работает только на сервере.
    ]==]
	read set_replication: (self: inventory, key: string?, ...Player) -> (),

	--[==[
        Возвращает реплицированный инвентарь по ключу. На сервере это исходный инвентарь,
        на клиенте — read-only реплика.
    ]==]
	read get_replicated: (self: inventory, key: string) -> inventory?,

	--[==[
        Является ли этот инвентарь клиентской репликой? Реплики нельзя изменять.
    ]==]
	read is_replica: (self: inventory) -> boolean,
} & list_checks<inventory> & list_operations<inventory, iteminstance>, observer<enumitem_list_notification>>

--[==[
    Базовый элемент инвентаря. Сам по себе поведение не реализует: он лишь ссылается на описание
    предмета и может иметь собственное переопределение поведения.

    Если `get_behavior()` возвращает `nil`, используется `item.behavior` из описания предмета.
    Так уникальные экземпляры (`itemobject`) могут иметь поведение, отличное от поведения стека.
]==]
export type iteminstance = extend<{
	--[==[
        Возвращает описание предмета, на который ссылается этот объект.
    
        Если описания не будет, то будет fallback на `NullItem`
    ]==]
	read get_item: (self: iteminstance) -> variable<item>,

	--[==[
        Возвращает поведение, переопределённое для этого конкретного элемента, либо `nil`,
        если нужно использовать поведение из `item.behavior`.
    ]==]
	read get_behavior: (self: iteminstance) -> itembehavior?,

	--[==[
        Устанавливает поведение для этого конкретного элемента. `nil` возвращает наследование
        поведения из описания предмета.
    ]==]
	read set_behavior: (self: iteminstance, to: itembehavior?) -> (),
}, observer<enumitem_list_notification>>

--[==[
    Уникальный экземпляр предмета. Проект поддерживает как майнкрафт-подобные стеки (`itemstack`),
    так и уникальные экземпляры (`itemobject`), у которых могут быть собственные поля и поведение.

    Для данного класса дочерние пользователи реализуют свои поля.
]==]
export type itemobject = extend<{

}, iteminstance>

--[==[
    Объект стопки для хранения неуникального `item`. По сути это эстетика майнкрафт-подобного вида предметов.

    `length` у стопки — это максимальный размер стопки, а `count` — текущее количество.
]==]
export type itemstack = extend<
	{
		--[==[
        Возвращает максимальный размер этой стопки, определяемый описанием предмета.
    ]==]
		read get_max: (self: itemstack) -> number,
	}
	& list_checks<itemstack>
	& list_operations<itemstack, itemstack>,
	iteminstance
>

--[==[
    Контекст вызова поведения предмета в текущий момент времени. Для `itembehavior`.

    Контекст — единственный аргумент, который получает поведение, поэтому новые виды поведения
    не требуют изменения сигнатур функций: достаточно добавить новый `enumitem_item_notification`.
]==]
export type itemcontext = extend<{
	--[==[
        Экземпляр, на который ссылается контекст — с чем работать.
    ]==]
	read related: iteminstance,

	--[==[
        Пользователь, который вызвал эту операцию — с кем работать.
    ]==]
	read user: luaobject?,

	--[==[
        Контекст вызова, описывающий подробности о типе вызова — как работать.
    ]==]
	read context: enumitem_item_context,

	--[==[
        Дельта времени для действий, которые выполняются в цикле. Для мгновенных операций равно `0`.
    ]==]
	read delta: number,
}, struct>

--[==[
    Поведение для предметов. Это не структура данных, а шина событий: поведение подписывается
    на `enumitem_item_notification` и получает `itemcontext` при вызове.

    Такая форма позволяет добавлять новые виды поведения без изменения функций: новый вид
    поведения — это новый `enumitem_item_notification`, а не новое поле или метод у этого типа.
]==]
export type itembehavior = extend<{

}, event<enumitem_item_notification, itembehavior, itemcontext>>

--[==[
    Описание предмета в программе. Это синглтон, который указывает стандартные параметры предмета.
]==]
export type item = extend<{
	--[==[
        Максимальное количество, которое предмет может иметь в `itemstack` или в инвентаре для
        объектов вида `itemobject`.
    ]==]
	read max: number,

	--[==[
        Количество, которое выдается пользователю когда он поднимает предмет с пола. Это может использоваться
        для дюпов, поэтому проверяйте поведение отдельно.
    ]==]
	read count: number,

	--[==[
        Описание предмета для интерфейса.
    ]==]
	read description: string,

	--[==[
        Стандартное поведение для всех `iteminstance` этого предмета.
    ]==]
	read behavior: itembehavior,

    --[==[
        Специальный синглтон, выделенный для обозначения неверного объекта.
    ]==]
    read get_null_item: (self: item) -> item,

	--[==[
        Сразу создает `itemstack` этого предмета с указанным количеством.
        Если количество не указано, используется `item.count`.
    ]==]
	read get_stack: (self: item, count: number?) -> itemstack,

	--[==[
        Создает уникальный `itemobject` этого предмета с унаследованным поведением.
    ]==]
	read get_object: (self: item) -> itemobject,

	--[==[
        Возвращает зарегистрированный предмет по имени, либо `nil`.
    ]==]
	read get_by_name: (self: item, name: string) -> item?,

	--[==[
        Возвращает все зарегистрированные предметы.
    ]==]
	read get_all: (self: item) -> ...item,
} & nameable, struct>

--[==[
    Объект, представляющий собой игровую способность с возможностью определения
    собственного поведения

    У данного объекта нет публичных методов для настройки кроме легко изменяемой
    информации балансировки. Сам объект не представляет их потому что этим должен
    заниматься код, который создает объект способности: подразумевается, что
    код создаст саму способность и настроит ее, а уже остальной код будет наследоваться
    от этой новосозданной способности и будет являться ее экземплярами

    Для реализации этого принципа используйте то, что способность провайдит собственные
    енамайтемы и сигнализирует о начальной фазе работы, после чего вручную управляйте ее
    конечным автоматом и уведомлениями прямо из функции способности
]==]
export type ability<T... = ...unknown> = extend<
	{
		--[==[
        Активирует способность от перспективы указанного персонажа

        Перспектива персонажа используется в качестве источника первоначальной информации,
        она отвечает на вопрос: "что мы вообще пытаемся сделать прямо сейчас?"
    ]==]
		read activate: (self: ability<T...>, on: character, T...) -> (),

		--[==[
        Таймер, контроллирующий текущее состояние кулдауна способности
    ]==]
		read cooldown: (self: ability<T...>) -> timer,
	}
	& informable<ability<T...>, abilityinfo>
	& stateable<ability<T...>, enumitem_round_state>,
	observer<enumitem_ability_notification>
>

-- Game IK

--[==[
    Объект, предоставляющий несамостоятельную базу для IK R6 решателей
]==]
export type ikr6solver = extend<{
	--[==[
        Текущее время ожидания хотя-бы какого-либо движения
    ]==]
	current_idle_time: number,

	--[==[
        Последний раз когда этот объект был обработан был N время назад
    ]==]
	last_work_time: number,

	--[==[
        Референс на `Humanoid`, из которого берутся `move_direction` и некоторые
        другие дополнительные данные для выборки поведения решателя
    ]==]
	read get_humanoid: (self: ikr6solver) -> reference<Humanoid?>,

	--[==[
        Референс на торс, от которого работают `ikr6foot`
    ]==]
	read get_torso: (self: ikr6solver) -> reference<BasePart?>,
} & informable<ikr6solver, ikr6info> & switchable, disposable>

--[==[
    Объект, представляющий самостоятельный buildin ik решатель для ног r6 рига

    Он полностью предоставляет собственное поведение и автоматизирован относительно
    алгоритмической сложности для пользователей
]==]
export type ikr6legs = extend<{
	--[==[
        Объект правой ноги, которым управляет этот решатель на автоматическом
        уровне
    ]==]
	read get_right_leg: (self: ikr6legs) -> ikr6foot,

	--[==[
        Объект левой ноги, которым управляет этот решатель на автоматическом
        уровне
    ]==]
	read get_left_leg: (self: ikr6legs) -> ikr6foot,

	--[==[
        Вернет текущую обрабатываемую ногу, которая находится в рабочей фазе,
        а также текущую неактивную ногу, которая ждет своей фазы
    ]==]
	read get_active_cycle_leg_pair: (self: ikr6legs) -> (ikr6foot, ikr6foot),

	--[==[
        Объект не обрабатывается если не подходит по условиям, таким как отсутствие `Humanoid`
        или `Torso`

        В общем случае это состояние активности работы объекта за текущий кадр, - был ли он
        обработан?
    ]==]
	read is_active: (self: ikr6legs) -> boolean,
} & initiable<ikr6legs>, ikr6solver>

--[==[
    Объект, представляющий самостоятельный buildin ik решатель для рук r6 рига.

    Решатель полностью предоставляет собственное поведение и автоматизирован относительно алгоритмической
    сложности для пользователей
]==]
export type ikr6arms = extend<{

	--[==[
        Возвращает правую руку
    ]==]
	read get_right_arm: (self: ikr6arms) -> ikr6arm,

	--[==[
        Возвращает левую руку
    ]==]
	read get_left_arm: (self: ikr6arms) -> ikr6arm,
} & initiable<ikr6arms>, ikr6solver>

--[==[
    Объект, представляющий одну руку для `ikr6arms`.
]==]
export type ikr6arm = extend<{
	--[==[
        Если цель является абсолютной в пространстве, то рука устремится к этой позиции в любой точке пространства:
        она будет смотреть в цель отовсюду. Иначе эта точка принимается как относительная позиция, тогда рука будет
        стремиться смотреть в цель относительно.

        Например, при абсолютных координатах `0,100,0` рука находясь на `1000, 0, 0` будет смотреть влево-вверх. При
        относительных координатах рука будет просто смотреть вверх.
    ]==]
	absolute: boolean,
} & I_targetable<ikr6arm, vector>, ikr6limb<ikr6arminfo>>

--[==[
    Объект, представляющий реализацию односуставной IK конечности, будь бы это нога,
    рука, или иной вид конечности

    Построен на фейках.
]==]
export type ikr6limb<T = enumitem, U = ikr6limbinfo> = extend<
	{
		--[==[
        Для этой конечности решатель может выполнять некоторые общие операции.
    ]==]
		mode: enumitem_iklimb_mode,

		--[==[
        Исходная точка от которой проводятся вычисления,
        по умолчанию является bottom torso позицией
    ]==]
		from: vector,

		--[==[
        Позиция конечности, вычисленная на основании `from` с учетом `leginfo.leg_diff`
    ]==]
		lateral_position: vector,

		--[==[
        Аккумулированное движение конечности

        Используется в качестве способа противостоять бесконечной ориентации или случаев,
        когда положение обрабатывается физически некорректно из-за игнорирования всего
        пути конечности
    ]==]
		accumulated_distance: number,

		--[==[
        Целевая координата к которой должна стремиться конечность
    ]==]
		target: basis,

		--[==[
        Вычисленная точка попадания, куда должна по идее встать конечность, то есть
        контактная поверхность

        Вычисляется на стороне управляющего кода, пусть эта точка и принадлежит
        объекту `ikr6limb`
    ]==]
		hit_position: vector,

		--[==[
        Метка для решателя, обозначающая что сейчас обрабатывается шаг этой ноги
    ]==]
		current: boolean,

		--[==[
        Вычисленная нормаль по точке попадания, определяющая как именно должна стать конечность

        Вычисляется на стороне управляющего кода, пусть эта точка и принадлежит
        объекту `ikr6limb`
    ]==]
		hit_normal: vector,

		--[==[
        Направление вверх, ориентирующее положение и поворот в пространстве для методов объекта
    ]==]
		up_direction: vector,

		--[==[
        Если операции для подсчета положения ноги не пройдут успешно, то конечность встанет
        в указанный `basis`
    ]==]
		fallback_basis: basis,

		--[==[
        Если конкретно эта конечность не смогла получить свои `hit_position` и `hit_normal`, то она вернется
        к `fallback_basis`. Старая информация не будет затерта до следующего раза, только успешные операции
        затирают старые данные
    ]==]
		fallback: boolean,

		--[==[
        Кэшируемый результат предыдущего подсчета положения конечности
    ]==]
		current_basis: basis,

		--[==[
        Будет ли показываться фейковая конечность заместо настоящей? Не влияет на расчеты
    ]==]
		read is_visible: (self: ikr6limb<T, U>) -> boolean,

		--[==[
        Установить видимость для фейковой конечность
    ]==]
		read set_visible: (self: ikr6limb<T, U>, to: boolean) -> (),

		--[==[
        Успела ли переместиться конечность к указанной цели или все еще находится в процессе движения?
    ]==]
		read is_moving_finished: (self: ikr6limb<T, U>) -> boolean,

		--[==[
        Успела ли повернуться конечность в ориентацию указанной цели или все еще находится в процессе поворота?
    ]==]
		read is_orientation_finished: (self: ikr6limb<T, U>) -> boolean,

		--[==[
        Возвращает `self.hit_position` с учетом отката во времени

        Это нужно для `solver_fallback` операций
    ]==]
		read get_limb_contact: (self: ikr6limb<T, U>) -> vector,

		--[==[
        Метод рассчитывает положение сустава в пространстве для конечности, чтобы в будущем она
        была наклонена относительно этого сустава и `from` при дальнейших операциях
    ]==]
		read get_limb_pole: (self: ikr6limb<T, U>, with_move_direction: vector, with_face_direction: vector) -> vector,

		--[==[
        Получает направление куда должна смотреть конечность с учетом направления движения и направления,
        куда смотрит остальное тело

        Если третьего аргумента нет, то направление конечности будет совпадать с направлением движения
    ]==]
		read get_limb_facing: (
			self: ikr6limb<T, U>,
			with_move_direction: vector,
			with_main_look_direction: vector?
		) -> vector,

		--[==[
        Вычисляет целевой `basis` конечности в состоянии planted/settling, то есть куда она должна быть поставлена,
        когда её низ уже находится в точке контакта с поверхностью.
    ]==]
		read get_limb_target: (self: ikr6limb<T, U>) -> basis,

		--[==[
        Метод рассчитывает положение самой конечности в пространстве
    ]==]
		read get_limb_basis: (
			self: ikr6limb<T, U>,
			coordinate: basis,
			knee: vector,
			foot_facing_direction: vector
		) -> basis,

		--[==[
        У этого объекта поведением задано управлять ненастоящей конечностью, чтобы не мешать
        другим операциям и объектам и не вызывать какие-либо другие эффекты
    ]==]
		read get_fake: (self: ikr6limb<T, U>) -> reference<BasePart>,

		--[==[
        Принудительно пересоздать `fake`
    ]==]
		read rebuild_fake: (self: ikr6limb<T, U>) -> (),

		--[==[
        Устанавливает режим для конечности.
    ]==]
		read set_mode: (self: ikr6limb<T, U>, mode: enumitem_iklimb_mode) -> (),
	}
	& initiable<ikr6limb<T, U>>
	& switchable
	& referenceable<ikr6limb<T, U>, BasePart>
	& stateable<ikr6limb<T, U>, T>
	& informable<ikr6limb<T, U>, U>
	& I_targetable<ikr6limb<T, U>, basis>,
	disposable
>

--[==[
    Объект, представляющий одну ногу для `ikr6legs`.
]==]
export type ikr6foot = extend<{}, ikr6limb<enumitem_iklegs_state, ikr6leginfo>>

--[==[
    Объект, представляющий самостоятельный buildin ik решатель для головы r6 рига

    Для головы r6 рига строится шея. Верхняя часть торса р6 является основанием шеи. Далее строится
    меридиана между шеей и головой, после чего получается полный цикл IK. Решатель смотрит на максимальные
    углы поворота как самой головы, так и шеи. Относительно целевой точки в пространстве выстраивается путь
    и положение головы. Самой шеи не существует, она вычисляется математически.

    Решатель полностью предоставляет собственное поведение и автоматизирован относительно алгоритмической
    сложности для пользователей
]==]
export type ikr6heads = extend<{

	--[==[
        Возвращает голову.
    ]==]
	read get_head: (self: ikr6heads) -> ikr6head,
} & initiable<ikr6heads>, ikr6solver>

export type ikr6head = extend<{}, ikr6limb>

export type ikr6headinfo = extend<{}, ikr6limbinfo>

-- Game Struct

--[==[
    Объект, представляющий балансную информацию о способности

    Его можно менять, создавать новые варианты баланса или редактировать
    на лету, а поскольку способность использует каждый раз те данные,
    что ей доступны на момент вызова, то и применяется это всегда
]==]
export type abilityinfo = extend<{

	--[==[
        Имеет ли способность время перезарядки после вызова?
    ]==]
	read has_cooldown: boolean,

	--[==[
        Имеет ли способность стан, в течении которого пораженная сущность не может выполнять
        активные или какие-либо другие действия?
    ]==]
	read has_stun: boolean,

	--[==[
        Есть ли у способности отброс для пораженной сущности, в которую способность попала?

        Может быть отрицательным, тогда пораженная сущность должна полететь в сторону откуда прилетел в нее снаря
    ]==]
	read has_kickback: boolean,

	--[==[
        Есть ли у способности отдача в персонажа, от лица которого она вызывается?
    ]==]
	read has_recoil: boolean,

	--[==[
        Применяется ли к пораженной сущности модификатор замедления передвижения?

        Может быть больше 1, тогда будет ускорять
    ]==]
	read has_slow: boolean,

	--[==[
        В зависимости от состояния полей `can_move_on_...` в указанной фазе способности
        будет применяться модификатор `slow` на персонажа, от лица которого вызвана
        эта способность
    ]==]
	read has_self_slow: boolean,

	--[==[
        Время перезарядки самой способности, в течении которого способность будет недоступна
    ]==]
	read cooldown: number,

	--[==[
        Время стана, в течении которого пораженный персонаж не может передвигаться или
        использовать что-либо, включая свои способности
    ]==]
	read stun: number,

	--[==[
        Сила отдачи, которая применяется на персонажа, от лица которого выполнена эта способность
    ]==]
	read recoil: number,

	--[==[
        Сила отдачи, которая применяется к тому, во что врежется эта способность, будь бы это предмет
        или другой персонаж
    ]==]
	read kickback: number,

	--[==[
        Применяемый модификатор замедления на пораженную цель, если он вообще указан
    ]==]
	read slow: number,

	read can_move_on_prepare_time: boolean,
	read can_move_on_action_time: boolean,
	read can_move_on_post_action_time: boolean,

	read prepare_action_time: number,
	read work_action_time: number,
	read post_action_time: number,
}, struct>

--[==[
    Объект, представляющий информацию о поведении IK решателя и диктующий ему
    условия его работы
]==]
export type ikr6info = extend<{
	--[==[
		Время отсутствия движения перед переходом в idle-логику.

		После достижения этого времени выполняется обновление
		целевых положений через `stand`.
	]==]
	read idle_time: number,

	--[==[
        Время между которыми `world_solver` IK проводит обновление этого конкретного
        решателя

        Недостаточное время будет пропущено, а указывается свойство в герцах. Рассчет
        нужного времени будет проведен самостоятельно
    ]==]
	read update_hertz: number,

	--[==[
        Игнорировать `ikr6info.update_hertz`?
    ]==]
	read ignore_hertz_limit: boolean,

	--[==[
        IK решатель сделает пребилд конечностей от полученного humanoid
    ]==]
	read prebuild_fake: boolean,
}, struct>

--[==[
    Объект, представляющий общую информацию о конечности для IK решателя
]==]
export type ikr6limbinfo = extend<{
	--[==[
        Величина смещения от края `torso` к его центру
    ]==]
	read limb_diff: number,

	--[==[
        Размер конечности, под который будут проводиться вычисления
    ]==]
	read limb_size: vector,

	--[[
		Максимальное расстояние вперед от точки постановки конечности,
		на котором проверяется наличие препятствия.

		Если препятствие находится ближе этого расстояния,
		оно может заблокировать обычный шаг.
	]]
	read limb_block_distance: number,

	--[==[
        Скорость с которой нога переходит к состоянию `fallback` при невозможности
        построения корректного шага
    ]==]
	read limb_fallback_speed: number,

	--[==[
        При пересечении этого порога через `accumulated_motion` будет вызван метод
        для решения шага, так как фактическая дистанция движения конечности уже слишком
        большая чтобы игнорировать ее
    ]==]
	read limb_distance_trigger_at: number,

	--[[
		Минимальная скорость перемещения конечности во время фазы
		`stepping`.

		Используется как нижняя граница интерполяционной
		скорости при минимальной скорости персонажа.
	]]
	read limb_movement_speed_min: number,

	--[[
		Максимальная скорость перемещения конечности во время фазы
		`stepping`.

		Используется как верхняя граница интерполяционной
		скорости при достижении максимальной учитываемой
		горизонтальной скорости персонажа.
	]]
	read limb_movement_speed_max: number,

	--[[
		Минимальная горизонтальная скорость персонажа,
		соответствующая `step_speed_min`.

		Скорость ниже этого значения не уменьшает скорость
		шага дальше установленного минимума.
	]]
	read limb_movement_velocity_min: number,

	--[[
		Максимальная горизонтальная скорость персонажа,
		соответствующая `step_speed_max`.

		Скорость выше этого значения не увеличивает скорость
		шага дальше установленного максимума.
	]]
	read limb_movement_velocity_max: number,

	--[[
		Минимальная скорость интерполяции конечности в фазе
		`settling`.

		Используется при минимальном коэффициенте скорости
		персонажа.
	]]
	read limb_orientation_speed_min: number,

	--[[
		Максимальная скорость интерполяции конечности в фазе
		`settling`.

		Используется при максимальном коэффициенте скорости
		персонажа.
	]]
	read limb_orientation_speed_max: number,

	--[[
		Скорость, с которой нога продолжает следовать за
		рассчитанной опорной точкой в состоянии `planted`.

		Определяет скорость сглаживания текущего положения
		конечности относительно нового `plant target`.
	]]
	read limb_planted_speed: number,

	--[[
		Порог скалярного произведения между направлением движения
		и направлением корпуса, после которого ориентация конечности
		переключается обратно на направление корпуса.

		При меньшем значении считается, что персонаж движется
		достаточно сильно в сторону, противоположную направлению
		корпуса, поэтому направление конечности берется от корпуса.

		При значении `0.5` порог соответствует углу примерно 60°.
	]]
	read limb_rotation_inverse_coefficient: number,

	--[[
		Минимальное время предсказания положения основания конечности
		по горизонтальной скорости персонажа.

		Применяется при вычислении предсказанной позиции перед
		raycast для шага.
	]]
	read limb_prediction_time_min: number,

	--[[
		Максимальное время предсказания положения основания конечности
		по горизонтальной скорости персонажа.

		При увеличении скорости персонажа значение стремится
		к этому пределу.
	]]
	read limb_prediction_time_max: number,

	--[[
		Показатель степени кривой интерполяции времени предсказания.

		Коэффициент скорости сначала вычисляется в диапазоне
		`0..1`, после чего возводится в эту степень перед
		интерполяцией между `leg_prediction_time_min` и
		`leg_prediction_time_max`.

		Значение больше `1` смещает рост предсказания в сторону
		более высоких скоростей.
	]]
	read limb_prediction_curve: number,

	--[[
		Максимально допустимая угловая ошибка между текущей
		ориентацией конечности и нормалью/ориентацией рассчитанной
		опорной поверхности во время `settling`.

		Когда ошибка становится меньше этого значения,
		фаза `settling` завершается и конечность переходит в
		состояние `planted`.
	]]
	read limb_orientation_mistake_angle: number,

	--[[
		Величина смешивания направления движения/ориентации конечности
		с направлением корпуса.

		Используется при вычислении forward-направления конечности:
		`0` — полностью используется направление, в котором должна
		смотреть стопа; `1` — полностью используется локальное
		направление корпуса.
	]]
	read limb_torso_relative_alpha: number,

	--[==[
        Если нет, то будет использоваться `Part` с обычными параметрами `r6` конечности

        Поле сработает только 1 раз при создании `fake_leg` части
    ]==]
	read limb_preffer_to_origin_clone: boolean,
}, struct>

--[==[
    Объект, предоставляющий информацию для IK решателя, в частности для поведения рук.
]==]
export type ikr6arminfo = extend<{}, ikr6limbinfo>

--[==[
	Объект, предоставляющий информац������������ю для IK решателя `char6`,
	в частности информацию для поведения IK ног.
]==]
export type ikr6leginfo = extend<{
	--[==[
        Насколько выше предполагаемой точки положения ноги начать поиск поверхности?
        Это позволяет не промахнуться, если персонаж находится над землёй, ступенькой или другой поверхностью
    ]==]
	read leg_raycast_up: number,

	--[==[
        Насколько н��же предполагаемой точки положения ноги продолжить поиск поверхности?
        Это позволяет находить землю под ногой, даже если она находится заметно ниже ожидаемого положения
    ]==]
	read leg_raycast_down: number,

	--[[
		Максимальная высота препятствия, которую нога может
		перешагнуть.

		Если найденная верхняя поверхность находится выше
		этого значения относительно основания корпуса,
		обычный шаг считается невозможным.
	]]
	read leg_step_max_height: number,

	--[[
		Высота над основанием ноги, с которой выполняется
		первичный raycast для обнаружения вертикального
		препятствия перед ногой.

		Используется только для проверки блокирующей стены,
		а не для непосредственного поиска поверхности стопы.
	]]
	read leg_step_obstacle_height: number,

	--[[
		Расстояние вперед по направлению движения, на которое
		смещается raycast при обычном шаге.

		Используется для поиска новой поверхности постановки стопы.
	]]
	read leg_step_forward: number,

	--[[
		Расстояние вперед, на которое смещается raycast при
		поиске поверхности для установки ноги в состоянии покоя.

		Используется процедурой `stand`.
	]]
	read leg_stand_forward: number,

	--[[
		Расстояние вперед для специального шага в idle-режиме.

		Используется, когда обычный шаг заблокирован препятствием
		и система пытается переставить свободную ногу через
		`begin_idle_step`.

		Значение `0` означает поиск опоры непосредственно под
		ногой без дополнительного смещения вперед.
	]]
	read leg_idle_step_forward: number,
}, ikr6limbinfo>

--[==[
    Объект, представляющий собой пул информации о персонаже, который
    встраивается в него каждый раз когда к части рантайма персонажа
    обращается кто-либо, при этом эта часть у персонажа не была активной
    ранее или не была создана в другом моменте

    Эта информация применяется постепенно и может быть передана на разных
    персонажей, а также она не зависит от токенов или любых других данных

    Предоставленная информация может быть проигнорирована в разных случаях,
    поскольку она декларирует поведение относительно стандартного сценария,
    когда не вызываются никакие способности или выполняется что-либо еще
]==]
export type characterinfo = extend<{
	read has_health: boolean,
	read has_stamina: boolean,
	read has_stamina_use: boolean,
	read has_stamina_regen: boolean,
	read has_health_regen: boolean,
	read has_stamina_runspeed_related_mod: boolean,
	read has_health_runspeed_related_mod: boolean,
	read has_jump_cooldown: boolean,
	read has_run_cooldown: boolean,

	read can_run: boolean,
	read can_jump: boolean,
	read can_move: boolean,
	read can_die: boolean,
	read can_revived: boolean,

	read health: number,
	read stamina: number,
	read speed: number,
	read runspeed: number,
	read run_cooldown: number,
	read jump_cooldown: number,
	read revives: number,
	read inventory_max: number,
}, struct>




























--[==[
    Объект, представляющий унифицированный результат выполнения той или иной операции
]==]
export type result<T = unknown, U... = ...unknown> = extend<{

	--[==[
        Статус выполнения этой операции
    ]==]
	read state: boolean,

	--[==[
        Результат, который был получен за эту операцию

        Он не обязан быть корректным, если `self.state` является `false`
    ]==]
	read result: T,

	--[==[
        Применяется строго в случаях, когда значение результа по типу является
        либо `table`, либо `function`, иначе ничего не вернет
    ]==]
	read unpack: (self: result<T, U...>) -> U...,
}, struct>

--[==[
    Объект, представляющий кубическую, неповорачиваемую и при этом
    проверяемую область в пространстве.

    Специфичный случай `cubevolume`.
]==]
export type aabbvolume = extend<
	{
		--[==[
        Часть куба, которая участвует в определении области пространства,
        которую занимает этот объект. Указывает на крайний угол противположной
        стороны куба
    ]==]
		read min: vector,

		--[==[
        Часть куба, которая участвует в определении области пространства,
        которую занимает этот объект. Указывает на крайний угол противположной
        стороны куба
    ]==]
		read max: vector,
	}
	& geometry_half
	& geometry_control<aabbvolume>
	& geometry_check<aabbvolume>
	& geometry_convertation<aabbvolume, geometry_supported>,
	cubevolume<aabbvolume>
>

--[==[
    Объект, представляющий кубическую поворачиваемую и проверяемую
    область в пространстве.

    Специфичный случай `cubevolume`.
]==]
export type obbvolume = extend<
	geometry_rotatable
	& geometry_convertation<obbvolume, geometry_supported>
	& geometry_control<obbvolume>
	& geometry_half
	& geometry_check<obbvolume>,
	cubevolume<obbvolume>
>

--[===[ TODO

--[==[
    Объект, представляющий собой сферическую область в пространстве
]==]
export type spherevolume = extend<{
    radius: number,
} & centerable<spherevolume> &
    math_operations<spherevolume, spherevolume>,
struct>

--[==[
    Объект, представляющий собой конусную область в пространстве

    Основание этого объекта является окружностью
]==]
export type conevolume = extend<{

    --[==[
        Кончик конуса будет выставлен на указанную точку в пространстве, при этом
        база (платфома, тупая часть конуса, то есть низ) будет повернута в сторону
        куда смотрит кончик конуса

        Переданный дополнительный аргумент смещает основание базы на указанную позицию
    ]==]
    read edge_point: (self: conevolume, to: vector, base: vector?) -> conevolume,

} & centerable<conevolume> &
    geometry_convertation<conevolume, geometry_supported> &
    geometry_rotatable &
    geometry_control<conevolume> &
    geometry_check<conevolume>,
geovolume<conevolume>>

--[==[
    Объект, представляющий собой капсульную область в пространстве
]==]
export type capsulevolume = extend<{

}
& centerable<capsulevolume> &
    geometry_convertation<capsulevolume, geometry_supported> &
    geometry_rotatable &
    geometry_control<capsulevolume> &
    geometry_check<capsulevolume>,
geovolume<capsulevolume>>

--[==[
    Объект, представляющий собой область в пространстве с `N` количеством
    опорных вертексов, с которыми проводятся вычисления

    Операции с этим объектом могут быть ресурсозатратными
]==]
export type tetavolume = extend<{

    --[==[
        Возвращает все опорные вертексы этой области
    ]==]
    read get_vertex: (self: tetavolume) -> ...vector,

    --[==[
        Добавляет опорный вертекс к этой области
    ]==]
    read add_vertex: (self: tetavolume, ...vector) -> (),

    --[==[
        Удаляет опорный вертекс из этой области, если он есть

        Если таких векторов несколько, будет удален первый попавшийся
    ]==]
    read rem_vertex: (self: tetavolume, ...vector) -> (),
}
& centerable<tetavolume> &
    geometry_convertation<tetavolume, geometry_supported> &
    geometry_rotatable &
    geometry_control<tetavolume> &
    geometry_check<tetavolume, geometry_supported>,
geovolume<tetavolume>>

]===]

--[==[
    Объект, представляющий собой треугольник из 3 векторов в пространстве,
    образующий таким образом часть полигона
]==]
export type triangle = extend<{
	--[==[
        Утилитарная функция по созданию стандартного `triangle` объекта,
        фактически ничем не отличающаяся от примера:

        ```luau
        self:new {
            right = right,
            up = up,
            front = front
        }
        ```
    ]==]
	read from_vector: (self: triangle, right: vector?, up: vector?, front: vector?) -> triangle,
} & centerable<triangle> & axisable<vector> & normals<triangle>, geovolume<triangle>>

--[==[
    Объект, представляющий собой полигон из двух треугольников.
]==]
export type quad = extend<{
	--[==[
        Левый треугольник, часть полигона
    ]==]
	read left: triangle,

	--[==[
        Правый треугольник, часть полигона
    ]==]
	read right: triangle,
} & centerable<quad> & normals<quad> & math_operations<quad, quad>, struct>

--[==[
    Объект, использующийся для определения осей пространства.

    Просто предоставляет порядок в котором идут оси.
]==]
export type directions = extend<vector_operations<directions, directions> & axisable<vector>, geovolume<directions>>

--[==[
    Объект, представляющий собой геометрический аналог координаты `CFrame`.

    Хранит в себе информацию о повороте и положении в пространстве.

    Причина его существования - `over-engineering`. Он м��г бы быть спокойно заменен на `CFrame`,
    однако в таком виде он не только обеспечивает удобство работы с данными Luau, но и модифицируемый.
    Если бы потребовалось, то его можно было бы и никогда не создавать, но поскольку проект однажды застрял
    в трясине в виде "code recode", то это вполне естественное решение.
]==]
export type basis = extend<
	{
		--[==[
        Нормализует `basis`
    ]==]
		read orthonormalize: (self: basis) -> basis,

		--[==[
        Возвращает углы Эйлера.

        (*) Дополнить какой порядок возвращает реализация.
    ]==]
		read euler_angles: (self: basis) -> ...number,

		--[==[
        Разбивает этот `basis` на компоненты, которые может переварить `CFrame`.
    ]==]
		read get_components: (
			self: basis
		) -> (number, number, number, number, number, number, number, number, number, number, number, number),

		--[==[
        Собирает `basis` из компонентов. Они соответствуют компонентам `CFrame`, поэтому
        собрать этот тип можно прямо из `CFrame`.
    ]==]
		read from_components: (
			self: basis,
			position_x: number?,
			position_y: number?,
			position_z: number?,
			rotation_right_x: number?,
			rotation_right_y: number?,
			rotation_right_z: number?,
			rotation_up_x: number?,
			rotation_up_y: number?,
			rotation_up_z: number?,
			rotation_front_x: number?,
			rotation_front_y: number?,
			rotation_front_z: number?
		) -> basis,

		--[==[
        Собирает `basis` из отдельных компонентов.
    ]==]
		read from_matrix: (
			self: basis,
			position: vector?,
			rotation_right: vector?,
			rotation_up: vector?,
			rotation_front: vector?
		) -> basis,

		read basis_to_world: (self: basis, ...basis) -> ...basis,
		read basis_to_local: (self: basis, ...basis) -> ...basis,
		read direction_to_world: (self: basis, ...vector) -> ...vector,
		read direction_to_local: (self: basis, ...vector) -> ...vector,
		read point_to_world: (self: basis, ...vector) -> ...vector,
		read point_to_local: (self: basis, ...vector) -> ...vector,

		read multiple_basis: (self: basis, ...basis) -> basis,
		read divide_basis: (self: basis, ...basis) -> basis,
		read append_basis: (self: basis, ...basis) -> basis,
		read substract_basis: (self: basis, ...basis) -> basis,
		read slerp: (self: basis, to: basis, alpha: number) -> basis,

        read to_basis: (self: basis, ...CFrame) -> ...basis,
        read to_cframe: (self: basis, ...basis) -> ...CFrame,

		--[==[
        Особый случай инвертирования `basis` относительно его компонентов,
        то есть с учетом афинного преобразования
    ]==]
		read inverse_basis: (self: basis) -> basis,
	}
	& positioned
	& rotateable,
	geovolume<basis>
>

--[==[
    Объект, представляющий собой область пространства в форме восьмиугольника
]==]
export type cubevolume<T = cubevolume> = extend<{
	--[==[
        Направление `+Y`, эквивалетное как `UpVector`
    ]==]
	read up: vector,

	--[==[
        Направление `-Y`, эквивалетное как `-UpVector`
    ]==]
	read bottom: vector,

	--[==[
        Направление `-X`, эквивалетное как `-RightVector`
    ]==]
	read left: vector,

	--[==[
        Направление `+X`, эквивалетное как `RightVector`
    ]==]
	read right: vector,

	--[==[
        Направление `-Z`, эквивалетное как `LookVector`
    ]==]
	read front: vector,

	--[==[
        Направление `Z`, эквивалентное как `-LookVector`
    ]==]
	read back: vector,

	--[==[
        Возвращает все вершины куба в их абсолютном виде
    ]==]
	read get_corners: (self: cubevolume<T>) -> { vector },

	--[==[
        Возвращает направление согласно полученному `enumitem`
    ]==]
	read get_direction: (self: cubevolume<T>, direction: enumitem_direction_variant) -> vector,

	--[==[
        Вовзращает `XYZ` направления, то есть основные оси по которым распределен этот
        конкретный `cubevolume`
    ]==]
	read get_axises: (self: cubevolume<T>) -> directions,

	--[==[
        Возвращает нормализованные направления, подогнанные для работы `SAT`
    ]==]
	read get_sat_axises: (self: cubevolume<T>) -> { vector },

	--[==[
        Из указанного направления построит `Quad` (фейс) из 2 треугольников на
        основании вершин куба
    ]==]
	read get_quad: (self: cubevolume<T>, direction: enumitem_direction_variant) -> quad,
} & centerable<cubevolume<T>> & vector_operations<cubevolume<T>, T>, geovolume<cubevolume<T>>>

--[==[
    Базовый абстрактный класс для части геометрии, использующийся в качестве
    общего математического и утилитарного api

    Его используют все `volume` объекты, представляющие хоть какую-то область
    в пространстве

    Сам по себе не имеет смысла
]==]
export type geovolume<T = any> = extend<math_operations<T, T>, struct>

-- Service

--[==[
    Сервис для удаленного запуска функционала на другой машине.
]==]
export type remotecall = extend<{}, service>

-- Enums

--[[

    На данный момент внутри системы типизации Luau существует забавный хардкод. Для ИМЕННО Enum дата-типа, вернее
    даже только для этого типа импорт его полей идет как модуль. По сути вы видите Enum тип именно как импортированный
    модуль в системе типизации.

    Сделано это намеренно. Однако, данная тулза не предоставляется ни одному другому разработчику. Ищите в исходниках
    это чудо самостоятельно.


    ---

    Все енамы по сути повторяют такую же тему как и роблоксовские енамы. Они также объявляются и также обрабатываются системой
    типов.

    look: https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.LocalUserSecurity.d.luau


]]

--[==[
    Стандартный и наиболее универсальный `enumitem`, который можно пихать на замену неизвестности.
]==]
export type enumitem_default_variant = enumitem<enum_default_variant>
--[==[
    Объект енамов, содержащий `enumitem_default_variant`.
]==]
export type enum_default_variant = extend<{
	--[==[
        Это неизвестный енам. Он представляет собой енам который не удалось определить, либо отсутствие
        енама в общем смысле. Обычно программа полностью игнорирует его, потому что он по сути ничего
        не представляет и на него нет callback-ов. Это потому что части проекта реализуют собственные енамы,
        на которые ссылаются.
    ]==]
	read Unknown: enumitem_default_variant,

	--[==[
        Это универсальный енам. Он представляет собой енам который отвечает на любой вид енамов. Обычно код не реализует
        его и специально ведет поведе��ие как и с `.Unknown`. Но если все таки поведение реализовано, то оно может привести
        к вообще любым последствиям. Контракт объявляет сам объект.
    ]==]
	read Any: enumitem_default_variant,
}, enumobject>

--[==[
    Экземпляры енамов для описания режима работы IKLimb.
]==]
export type enumitem_iklimb_mode = enumitem<enum_iklimb_mode>
--[==[
    Объект енам, содержащий в себе `enumitem_iklimb_mode`.
]==]
export type enum_iklimb_mode = extend<{
	--[==[
        Решатель ведет себя стандартно.
    ]==]
	read FakeIK: enumitem_iklimb_mode,

	--[==[
        Решатель выполняет fallback к текущему положению реальной конечности,
        вместо того чтобы выполнять какую-либо работу с ним связанную.
    ]==]
	read RealFK: enumitem_iklimb_mode,
}, enumobject>

export type enumitem_list_notification = enumitem<enum_list_notification>
export type enum_list_notification = extend<{
	read AddedElement: enumitem_list_notification,
	read RemovedElement: enumitem_list_notification,
	read ListFull: enumitem_list_notification,
	read ListEmpty: enumitem_list_notification,
	read ListHalf: enumitem_list_notification,
}, enumobject>

export type enumitem_input_notification = enumitem<enum_input_notification>
export type enum_input_notification = extend<{
	read CodeAdded: enumitem_input_notification,
	read CodeRemoved: enumitem_input_notification,
	read Pressed: enumitem_input_notification,
	read Clamped: enumitem_input_notification,
	read Stopped: enumitem_input_notification,
	read RelatedChanged: enumitem_input_notification,
	read RelatedNullified: enumitem_input_notification,
	read NetworkEnabled: enumitem_input_notification,
	read NetworkDisabled: enumitem_input_notification,
}, enumobject>

export type enumitem_ability_notification = enumitem<enum_ability_notification>
export type enum_ability_notification = extend<{
	read CastAbility: enumitem_ability_notification,
	read WaitingDataAbility: enumitem_ability_notification,
	read ActiveAbility: enumitem_ability_notification,
	read CancelAbility: enumitem_ability_notification,
	read EndingAbility: enumitem_ability_notification,
	read CooldownAbility: enumitem_ability_notification,
}, enumobject>

export type enumitem_item_context = enumitem<enum_item_context>
export type enum_item_context = extend<{
	read Primary: enumitem_item_context,
	read Secondary: enumitem_item_context,
	read Cycle: enumitem_item_context,
	read Special: enumitem_item_context,
}, enumobject>

--[==[
    События поведения предмета. Новый вид поведения добавляется как новый элемент этого перечисления,
    а не как новое поле или метод в `itembehavior`. Подписчики получают `itemcontext`.
]==]
export type enumitem_item_notification = enumitem<enum_item_notification>
export type enum_item_notification = extend<{
	--[==[
        Предмет экипирован пользователем. Вызывается до фактического применения эффектов.
    ]==]
	read Equip: enumitem_item_notification,

	--[==[
        Предмет убран из рук пользователя.
    ]==]
	read Unequip: enumitem_item_notification,

	--[==[
        Предмет поднят пользователем с пола.
    ]==]
	read Take: enumitem_item_notification,

	--[==[
        Предмет выброшен пользователем из инвентаря или рук.
    ]==]
	read Drop: enumitem_item_notification,

	--[==[
        Основное действие предмета, выполняемое в цикле. `itemcontext.delta` содержит дельту времени.
    ]==]
	read Action: enumitem_item_notification,
}, enumobject>

export type enumitem_state = enumitem<enum_state>
export type enum_state = extend<{
	read Failure: enumitem_state,
	read Loading: enumitem_state,
	read Successful: enumitem_state,
	read Nothing: enumitem_state,
}, enumobject>

export type enumitem_user_machine_variant = enumitem<enum_user_machine_variant>
export type enum_user_machine_variant = extend<{
	read Computer: enumitem_user_machine_variant,
	read Mobile: enumitem_user_machine_variant,
	read Console: enumitem_user_machine_variant,
	read AnotherDevice: enumitem_user_machine_variant,
}, enumobject>

export type enumitem_controller_state = enumitem<enum_controller_state>
export type enum_controller_state = extend<{
	read Continue: enumitem_controller_state,
	read Pause: enumitem_controller_state,
	read Reset: enumitem_controller_state,
}, enumobject>

export type enumitem_iklegs_state = enumitem<enum_iklegs_state>
export type enum_iklegs_state = extend<{
	read Planted: enumitem_iklegs_state,
	read Stepping: enumitem_iklegs_state,
	read Settling: enumitem_iklegs_state,
}, enumobject>

export type enumitem_operation_variant = enumitem<enum_operation_variant>
export type enum_operation_variant = extend<{
	read New: enumitem_operation_variant,
	read Change: enumitem_operation_variant,
	read Remove: enumitem_operation_variant,
}, enumobject>

export type enumitem_reference_notification = enumitem<enum_reference_notification>
export type enum_reference_notification = extend<{
	read NewInstance: enumitem_reference_notification,
	read ChangedInstance: enumitem_reference_notification,
	read DestroyedInstance: enumitem_reference_notification,
	read NullifiedInstance: enumitem_reference_notification,
}, enumobject>

export type enumitem_binder_notification = enumitem<enum_binder_notification>
export type enum_binder_notification = extend<{
	read Bound: enumitem_binder_notification,
	read Unbound: enumitem_binder_notification,
}, enumobject>

export type enumitem_net_notification = enumitem<enum_net_notification>
export type enum_net_notification = extend<{
	read Received: enumitem_net_notification,
}, enumobject>

export type enumitem_data_notification = enumitem<enum_data_notification>
export type enum_data_notification = extend<{
	read DataStateChanged: enumitem_data_notification,
	read DataLoaded: enumitem_data_notification,
	read DataReleased: enumitem_data_notification,
	read DataChanged: enumitem_data_notification,
	read DataMessage: enumitem_data_notification,
}, enumobject>

export type enumitem_data_internal_variant = enumitem<enum_data_internal_variant>
export type enum_data_internal_variant = extend<{
    read DataSnapshot: enumitem_data_internal_variant,
    read DataSet: enumitem_data_internal_variant,
    read DataReady: enumitem_data_internal_variant,
    read DataRequest: enumitem_data_internal_variant,
    read DataExit: enumitem_data_internal_variant,
}, enumobject>

export type enumitem_data_state = enumitem<enum_data_state>
export type enum_data_state = extend<{
	read ProfileLoading: enumitem_data_state,
	read ProfileLoaded: enumitem_data_state,
	read ProfileReleased: enumitem_data_state,
}, enumobject>

export type enumitem_shared_net_link = enumitem<enum_shared_net_link>
export type enum_shared_net_link = extend<{
	read Data: enumitem_shared_net_link,
	read Profile: enumitem_shared_net_link,
	read Inventory: enumitem_shared_net_link,
}, enumobject>

export type enumitem_shared_net_variant = enumitem<enum_shared_net_variant>
export type enum_shared_net_variant = extend<{
	read Unsafe: enumitem_shared_net_variant,
	read Safe: enumitem_shared_net_variant,
	read Internal: enumitem_shared_net_variant,

	read get_variant: (self: enum_shared_net_variant, of: enumitem_shared_net_variant) -> string,
}, enumobject>

export type enumitem_net_source = enumitem<enum_net_source>
export type enum_net_source = extend<{
	read UnknownSource: enumitem_net_source,
	read FromServer: enumitem_net_source,
	read FromMe: enumitem_net_source,
	read FromClient: enumitem_net_source,

	read get_enum_by_current_machine: (self: enum_net_source) -> enumitem_net_source,
}, enumobject>

export type enumitem_executor_notification = enumitem<enum_executor_notification>
export type enum_executor_notification = extend<{
	read Process: enumitem_executor_notification,
	read Simulation: enumitem_executor_notification,
}, enumobject>

export type enumitem_character_parameter_variant = enumitem<enum_character_parameter_variant>
export type enum_character_parameter_variant = extend<{
	read Health: enumitem_character_parameter_variant,
	read Stamina: enumitem_character_parameter_variant,
	read Speed: enumitem_character_parameter_variant,
	read RunSpeed: enumitem_character_parameter_variant,
	read RunCooldown: enumitem_character_parameter_variant,
	read JumpCooldown: enumitem_character_parameter_variant,
	read Revives: enumitem_character_parameter_variant,
}, enumobject>

export type enumitem_attribute_notification = enumitem<enum_attribute_notification>
export type enum_attribute_notification = extend<{
	read Added: enumitem_attribute_notification,
	read Changed: enumitem_attribute_notification,
	read Removed: enumitem_attribute_notification,
}, enumobject>

export type enumitem_setup_notification = enumitem<enum_setup_notification>
export type enum_setup_notification = extend<{
	read Install: enumitem_setup_notification,
	read Installed: enumitem_setup_notification,
	read Require: enumitem_setup_notification,
	read Disconnected: enumitem_setup_notification,
}, enumobject>

export type enumitem_tick_notification = enumitem<enum_tick_notification>
export type enum_tick_notification = extend<{
	read Started: enumitem_tick_notification,
	read Stepped: enumitem_tick_notification,
	read Paused: enumitem_tick_notification,
	read Resumed: enumitem_tick_notification,
	read Finished: enumitem_tick_notification,
}, enumobject>

export type enumitem_round_state = enumitem<enum_round_state>
export type enum_round_state = extend<{
	read Preparing: enumitem_round_state,
	read Begining: enumitem_round_state,
	read AtWork: enumitem_round_state,
	read Ending: enumitem_round_state,
	read Ended: enumitem_round_state,
}, enumobject>

export type enumitem_asset_type_variant = enumitem<enum_asset_type_variant>
export type enum_asset_type_variant = extend<{
	read Model: enumitem_asset_type_variant,
	read Sound: enumitem_asset_type_variant,
	read Image: enumitem_asset_type_variant,
}, enumobject>

export type enumitem_faction_notification = enumitem<enum_faction_notification>
export type enum_faction_notification = extend<{
	read MemberJoined: enumitem_faction_notification,
	read MemberRemoved: enumitem_faction_notification,
}, enumobject>

export type enumitem_user_data_require = enumitem<enum_user_data_require>
export type enum_user_data_require = extend<{
	read UserProfile: enumitem_user_data_require,

	read UserLastDataSave: enumitem_user_data_require,
	read UserLastDataRequest: enumitem_user_data_require,
	read UserPlayedTime: enumitem_user_data_require,
	read UserLastEnter: enumitem_user_data_require,
	read UserPreviousKick: enumitem_user_data_require,
	read UserPreviousBan: enumitem_user_data_require,
}, enumobject>

export type enumitem_user_notification = enumitem<enum_user_notification>
export type enum_user_notification = extend<{
	read ServerJoin: enumitem_user_notification,
	read ServerExit: enumitem_user_notification,
	read ServerDataRequest: enumitem_user_notification,
	read ServerDataChanged: enumitem_user_notification,
}, enumobject>

export type enumitem_action_map_variant = enumitem<enum_action_map_variant>
export type enum_action_map_variant = extend<{
	read MoveForward: enumitem_action_map_variant,
	read MoveBackward: enumitem_action_map_variant,
	read MoveLeft: enumitem_action_map_variant,
	read MoveRight: enumitem_action_map_variant,
	read MoveJump: enumitem_action_map_variant,
	read MoveCrounch: enumitem_action_map_variant,
	read MoveLying: enumitem_action_map_variant,
	read MoveRun: enumitem_action_map_variant,
	read MoveSlow: enumitem_action_map_variant,
}, enumobject>

export type enumitem_statemachine_notification = enumitem<enum_statemachine_notification>
export type enum_statemachine_notification = extend<{
	read ChangedState: enumitem_statemachine_notification,
	read NewState: enumitem_statemachine_notification,

	read BlacklistAdded: enumitem_statemachine_notification,
	read BlacklistRemoved: enumitem_statemachine_notification,
}, enumobject>

--[==[
    Экземпляры енамов на соединения и подписки. Описывает режимы работы.
]==]
export type enumitem_connection_variant = enumitem<enum_connection_variant>
--[==[
    Объект енамов, который содержит `enumitem_connection_variant`.
]==]
export type enum_connection_variant = extend<
	{
		--[==[
        Обычная постоянная подписка. Срабатывает на те уведомления, которые она отслеживает.
    ]==]
		read Ever: enumitem_connection_variant,

		--[==[
        Одноразовая подписка. Сработает один раз и удалится, либо перестанет далее работать, если получит
        уведомление по тому типу который она отслеживает.
    ]==]
		read Once: enumitem_connection_variant,

		--[==[
        `Attention`, зарезервированный режим. Возможно может быть удален в будущих патчах.
    ]==]
		read Hold: enumitem_connection_variant, -- reserved

		--[==[
        Переключает режим работы подписки. Пропускается первое уведомление на которое реагирует подписка,
        на следующее уведомление подписка сработает один раз и дальше удалится.
    ]==]
		read Skip: enumitem_connection_variant, -- -> Once

		--[==[
        Переключает режим работы подписки. Пропускается первое уведомление на которое реагирует подписка,
        на следующее уведомление подписка уже будет постоянно работать.
    ]==]
		read Next: enumitem_connection_variant, -- -> Ever
	},
	enumobject
>

export type enumitem_internal_channel_variant = enumitem<enum_internal_channel_variant>
export type enum_internal_channel_variant = extend<{
	read UserData: enumitem_internal_channel_variant,
}, enumobject>

export type enumitem_physx_mode_variant = enumitem<enum_physx_mode_variant>
export type enum_physx_mode_variant = extend<{
	read Local: enumitem_physx_mode_variant,
	read Global: enumitem_physx_mode_variant,
}, enumobject>

--[==[
    Экземпляры енамов на уведомление по поводу освобождения объекта.
]==]
export type enumitem_disposable_notification = enumitem<enum_disposable_notification>
--[==[
    Объект енамов, содержащий `enumitem_disposable_notification`.
]==]
export type enum_disposable_notification = extend<{
	--[==[
        Это предрелизное уведомление о том, что объект освобождается. В этот момент еще ничего не
        произошло с объектом.
    ]==]
	read OnRelease: enumitem_disposable_notification,

	--[==[
        Это пострелизное уведомление о том, что объект освобожден. Поведение объекта не гарантированно,
        и то что он вообще будет или не будет работать тоже.
    ]==]
	read Released: enumitem_disposable_notification,
}, enumobject>

--[==[
    Экземпляры енамов на вариант направления.
]==]
export type enumitem_direction_variant = enumitem<enum_direction_variant>
--[==[
    Объект енамов, содержащий `enumitem_direction_variant`.
]==]
export type enum_direction_variant = extend<{
	--[==[
        Это направление вверх. Оно соответствует `+Y`.
    ]==]
	read Up: enumitem_direction_variant,

	--[==[
        Это направление вниз. Оно соответствует `-Y`.
    ]==]
	read Bottom: enumitem_direction_variant,

	--[==[
        Это направление влево. Оно соответствует `-X`.
    ]==]
	read Left: enumitem_direction_variant,

	--[==[
        Это направление вправо. Оно соответствует `+X`.
    ]==]
	read Right: enumitem_direction_variant,

	--[==[
        Это направление вперед. Оно соответс��вует `-Z`.
    ]==]
	read Front: enumitem_direction_variant,

	--[==[
        Это направление назад. Оно соответствует `+Z`.
    ]==]
	read Back: enumitem_direction_variant,
}, enumobject>

export type enumitem_collision_variant = enumitem<enum_collision_variant>
export type enum_collision_variant = extend<{
	read DefaultGroup: enumitem_collision_variant,
	read ItemGroup: enumitem_collision_variant,
	read CharacterGroup: enumitem_collision_variant,
	read DebrisGroup: enumitem_collision_variant,
}, enumobject>

-- Interface

--[==[
    Объект реализует механизм, в котором он ссылается на существующий инстанс роблокса.
]==]
export type instanceable<T = {}, U = unknown> = {
	read set_instance: (self: T, to: U) -> (),
	read get_instance: (self: T) -> U,
	read is_instance_exists: (self: T) -> boolean,
}
--[==[
    Зависит от контекста.
]==]
export type expected_calltype<T = unknown> = {
	--[==[
        Ожидаемый вариант. Зависит от контекста.
    ]==]
	on: T,
}
--[==[
    Объект имеет имя.
]==]
export type nameable<T = string> = {
	name: T | string,
}
--[==[
    Объектом мо��но хотя-��ы как-то упр��влять
]==]
export type operatable<T = unknown> = {
	read continue: (self: T) -> (),
	read pause: (self: T) -> (),
	read reset: (self: T) -> (),
}
--[==[
    У объекта есть контроллер
]==]
export type controllable<T = unknown> = {
	--[==[
        Возвращает контроллер, который ��правляет п��ведением объ��кта.
    ]==]
	read get_control: (self: T) -> controller,
}
--[==[
    У объекта есть модификатор. Зависит от контекста.
]==]
export type modifier<T = unknown> = {
	--[==[
        Вариант модификатора для объекта. Зависит от контекста
    ]==]
	modifier: T,
}
--[==[
    Зависит от контекста.
]==]
export type iterations<T = unknown> = {
	--[==[
        Зависит от контекста.
    ]==]
	iterate: T,
}
--[==[
    У объекта есть какой-то цикл, в котором он работает.
]==]
export type loopable<T = unknown> = {
	--[==[
        Возвращает рабочий цикл объекта, в котором он работает.
    ]==]
	read get_loop: (self: T) -> timer,
}
--[==[
    Объект ссылается через `reference` на какой-либо роблокс экземпляр.
]==]
export type referenceable<T = unknown, U = unknown> = {
	--[==[
        Получить референсную ссылку, которая прикреплена к этому объекту. За��исит от контекста.
    ]==]
	read get_reference: (self: T) -> reference<U>,
}
--[==[
    Объект реализует перезарядку. Зависит от контекста
]==]
export type reloadable<T = unknown, U... = ()> = {

	--[==[
        Перезаряжает объект указанными данными. Зависит от контек��та
    ]==]
	read reload: (self: T, U...) -> (),
}
--[==[
    Объект реализует механизм приватного хранилища, в котором хранит метаданные того или иного
    рода и вида.
]==]
export type private_storage<T = unknown> = {

	--[==[
            Получить из внутреннего приватного хранилища объекта какое-либо значение по `label`
        ]==]
	read get: <Y>(self: T, label: any) -> Y,

	--[==[
            Установить во внутреннее приватное хранилище объекта какое-либо значение по `label`
        ]==]
	read set: <Y>(self: T, label: any, to: Y) -> (),
}

--[==[
    Объект реализует состояние вкл/выкл
]==]
export type switchable = {
	--[==[
        Включает или выключает работу объекта
    ]==]
	enabled: boolean,
}

--[==[
    Объект можно вызывать
]==]
export type invokeable<T = unknown, U... = (), E... = ()> = {
	--[==[
        Вызывае�� в объ��кте какую-ли��о операцию с переданными данными. З��висит от контекста.
    ]==]
	read invoke: (self: T, U...) -> E...,
}
--[==[
    Объект реализует немного параметров для асинхронных операций и попыток. Зависит от контекста. Не очень очевидный
    интерфейс.
]==]
export type asyncable = {
	--[==[
        Время на ожидание перед началом новой попытки
    ]==]
	time_to_hold: number,

	--[==[
        Время на ожидание ответа от опрашиваемой части. Обычно это касается только сетевых объектов и
        всего что с этим ��вя����но.
    ]==]
	time_to_response: number,

	--[==[
        Количество попыток, которые необходимо выполнить объекту перед получением конечного результата.
    ]==]
	attempts: number,
}

--[==[
    Все виды геометрического объема.
]==]
export type geometry_volume = aabbvolume | obbvolume | cubevolume -- TODO | spherevolume | trianglevolume | capsulevolume
--[==[
    Геометрический приметив, - минимальная фигура которая используется для описаний той или иной части геометрии
]==]
export type geometry_primetive = triangle | quad | vector | cubevolume
--[==[
    Общее доступное и поддерживаемое пространство для транскрипции. То, что переваривает геометрия, грубо говоря.
]==]
export type geometry_supported = geometry_volume | Model | BasePart | PVInstance

--[==[
    Интерфейс предоставляет объекту операции геометрических проверок для
    уточнения факта коллизий
]==]
export type geometry_check<T = unknown> = {

	--[==[
        Переданные данные охвачены диапазоном объекта, из которого вызывается этот метод,
        либо нет, что в итоге приведет к `false`
    ]==]
	read is_inside: (self: T, ...unknown) -> boolean,

	--[==[
        Переданные данные вообще как-либо взаимодействуют с объектом, из которого
        вызван ��тот метод

        Аналогичен:

        ```luau
            const interacts = self:is_inside(val) and self:is_intersection(val)
        ```
    ]==]
	read is_interacts: (self: T, ...unknown) -> boolean,

	--[==[
        Переданные данные, хотя-бы один из них, пересекается с объектом, из которого
        вызван этот метод. Даже если пересечение совсем небольшое
    ]==]
	read is_intersection: (self: T, ...unknown) -> boolean,
}

export type geometry_half = {
	--[==[
        Полуразмер представляет собой удобный способ проводить вычисления через центр
        и полуоси, через `min | max` или прямые конвертации | сравнения
    ]==]
	half: vector,
}

--[==[
    Управляющие контроллеры над самой геометрической фигурой типа смотри туда, делай то
    и тому подобного
]==]
export type geometry_control<T = unknown> = {
	--[==[
        Заставляет геометрическую фигуру направиться лицевой стороной на указанную
        в пространстве точку
    ]==]
	read look_at: (self: T, that: vector, up: vector?) -> T,
}

export type geometry_rotatable<T = unknown> = {
	--[==[
        Поворачивает объект относительно его текущего локального поворота,
        путем прибавления или убавления радиан

        В пространстве определяется центр объекта, и относительно него и идет
        поворот объекта
    ]==]
	read rotate_radian: (self: obbvolume, rad_vector: vector) -> obbvolume,

	--[==[
        Возвращает абсолютный угол поворота по радианам относительно
        мирового стандартного угла (0 0 0)
    ]==]
	read get_rotation_radian: (self: obbvolume) -> vector,
}

--[==[
    Операции конвертаций геометрических структур из 1 вида в другой, то есть
    трансформация информации
]==]
export type geometry_convertation<T = unknown, U... = ...unknown> = {
	--[==[
        Входящие данные должны быть переведены в тот же тип что и объект, откуда
        вызывается данный метод. При этом сами сконвертированные данные после
        не должны быть как-либо связаны с начальным объектом
    ]==]
	read from: (self: T, U...) -> T,

	--[==[
        Между всеми полученными значениями вычисляется состояние,
        которое охватывает хотя-бы какую-то часть всех переданных элементов
        и сводит все к среднему арифметическому варианту
    ]==]
	read middle: (self: T, U...) -> T,

	--[==[
        Новое значение должно гарантированно захватывать такое состояние,
        которое удовлетворяет условиям всех переданных данных. Результат должен
        захватывать все данные в себе

        Например:

        ```luau
            if volume.size == 49 then -- not OK
                -- ...
            end

            const result = volume:cover(BasePart, BasePart, Model, obbvolume, volume)

            if result.size == 595 then -- OK
                -- ...
            end
        ```
    ]==]
	read cover: (self: T, U...) -> T,
}

--[==[
    Объекты с этим интерфейсом обладают легко изменяемой логической реализацией,
    данные которой никак не влияют на саму функцию, которая работает с ними

    Это могут быть объекты баланса, объекты описывающие поведение того или иного
    элемента системы или нечто иное, что только декларирует что можно, что нельзя,
    насколько и по какому принципу
]==]
export type informable<T = unknown, U = unknown> = {
	--[==[
        Возвращает доступный пакет информации о способности
    ]==]
	read get_info: (self: T) -> U,

	--[==[
        Устанавливает новый пакет информации о способности
    ]==]
	read set_info: (self: T, info: U) -> (),
}

--[==[
    Объект реализует некоторые математические операции с собой.
]==]
export type math_operations<T = unknown, U... = ()> = {
	--[==[
        Операция умножения на указанное число.
    ]==]
	read multiple: (self: T, to: number) -> U...,
	--[==[
        Операция деления на указанное число.
    ]==]
	read divide: (self: T, to: number) -> U...,

	--[==[
        Операция прибавления на указанное число.
    ]==]
	read append: (self: T, to: number) -> U...,

	--[==[
        Операция вычисления на указанное число.
    ]==]
	read substract: (self: T, to: number) -> U...,

	--[==[
        Объект сравнивается с другим объектом на основании допуска, который
        указывает максимальную границу различий между `A` и `B`
    ]==]
	read fuzzy_eq: (self: T, to: T, epsilon: number?) -> boolean,

	--[==[
        Все значения объекта, с учетом `alpha` аргумента, "перетекут" к цели
        насколько это позволяет `alpha` от `0` - начала, до `1` - конечной
    ]==]
	read lerp: (self: T, to: T, alpha: number) -> U...,

	--[==[
        Все значения объекта инвертируют свой знак
    ]==]
	read invert: (self: T) -> U...,

	--[==[
        Все значения объекта сводятся в положительную сторону
    ]==]
	read absolute: (self: T) -> U...,

	--[==[
        Все значения объекта сводятся в отрицательную сторону
    ]==]
	read negation: (self: T) -> U...,

	--[==[
        Все значения объекта сводятся к `-1 | 1` через `clamp()`
    ]==]
	read normalize: (self: T) -> U...,

	--[==[
        Все значения объекта сводятся в `0`
    ]==]
	read null: (self: T) -> U...,

	--[==[
        Все значения объекта сводятся в `math.huge`
    ]==]
	read infinity: (self: T) -> U...,
}

--[==[
    Объект гарантирует преобразование в некоторые геометрические примитивы
]==]
export type vector_operations<T = unknown, U... = ()> = {
	--[==[
        Трансформирует объект в `basis`.
    ]==]
	read to_basis: (self: T) -> basis,

	--[==[
        Трансформирует объект в `vector`.
    ]==]
	read to_vector: (self: T) -> vector,
}

--[==[
    Интерфейс гарантирует наличие позиции как поля
]==]
export type positioned<T = vector> = {

	--[==[
        Позиция, представляющая собой центр геомтрического объекта

        Статически известна, либо вычисляется так, что вычислить информацию о ней
        динамически не представляется возможным. Например, для `Vertex`
    ]==]
	position: T,
}

--[==[
    Интерфейс гарантирует наличие нормали как поля
]==]
export type normal<T = vector> = {
	--[==[
        Направление, указывающее в сторону куда смотрит фейс (полигон) относительно
        геометрии, в которую попадает рейкаст или для которой нормаль была сформирована
    ]==]
	normal: T,
}

export type axisable<T = unknown> = {
	--[==[
        Направление оси по `X`
    ]==]
	right: T,

	--[==[
        Направление оси по `Y`
    ]==]
	up: T,

	--[==[
        Направление оси по `-Z`
    ]==]
	front: T,
}

export type centerable<T = unknown> = {
	--[==[
        Вычисляет геометрический центр объекта исходя из доступной информации
    ]==]
	read get_center: (self: T) -> vector,
}
export type rotateable<T = unknown> = {
	--[==[
        Определяет локальный поворот объекта относительной мировой сцены, что позволяет
        внезапно менять, например, гравитацию персонажа, если она рассчитывается вручную
        в обход движка, на котором исполняется код
    ]==]
	rotation: directions,
}


--[==[
    Этот объект может преобразовывать данные в нормали
]==]
export type normals<T = unknown, U = vector> = {
	--[==[
        Возвращает геометрическую нормаль

        Геометрическая нормаль получается из геометрии описываемой геометрической фигуры,
        за счет чего обладает свойством повторять ее поверхность и направление относительно
        взгляда этой поверхности

        Это обычная нормаль поверхности
    ]==]
	read get_normal_geometric: (self: T) -> U,

	--[==[
        Возвращает интерполированную (световую) нормаль

        Интерполированная нормаль получается исходя из общей интерполяции геометрической фигуры,
        как если бы доступные нормали участка 1 `Quad`, который представляет из себя острый угол
        под 90 градусов, внезапно усреднили и получили бы 45 градусное направление

        Это световая нормаль поверхности, она используется в основном для сглаженного шейдинга,
        однако подходит и под другие задачи
    ]==]
	read get_normal_interpolated: (self: T) -> U,
}

--[==[
    У объекта есть инициализация смотря по его контексту
]==]
export type initiable<T = unknown> = {

	--[==[
        Объект готов к работе и имеет все зависимости подключенными,
        либо нет
    ]==]
	read is_initiated: (self: T) -> boolean,
}

--[==[
    У этого объекта есть автомат состояний.
]==]
export type stateable<T = unknown, U = enumitem> = {
	--[==[
        Возвращает автомат состояний у этого объекта, с которым он неразрывно связан

        Используется для внутренней логики через декомпозицию, в основном
    ]==]
	read get_states: (self: T) -> stateregistry<U>,
}

--[==[
    Участники интерфейса реализуют базовые листовые проверки
]==]
export type list_checks<T = unknown> = {
	--[==[
        Является ли этот объект полностью заполненным?
    ]==]
	read is_full: (self: T) -> boolean,

	--[==[
        Является ли этот объект полностью пустым?
    ]==]
	read is_empty: (self: T) -> boolean,

	--[==[
        Превышает ли количество элементов в этом объекте половину
        или около?
    ]==]
	read is_half: (self: T) -> boolean,
}

--[==[
    Участники интерфейса реализуют базовые листовые операции
]==]
export type list_operations<T = unknown, U... = ...unknown> = {
	--[==[
        Очищает объект, делая его пустым
    ]==]
	read clear: (self: T) -> (),

	--[==[
        Возвращает количество элементов в объекте по факту.
    ]==]
	read count: (self: T) -> number,

	--[==[
        Возвращает общий размер всего объекта. Это нужно, чтобы узнать точное количество элементов
        в объекте, даже если там могут быть дыры.
    ]==]
	read length: (self: T) -> number,

	--[==[
        Изменяет количество элементов в объекте с учетом переданного значения.
    ]==]
	read adjust: (self: T, count: number) -> (),

	--[==[
        Вставляет в объект указанные элементы, если их никогда не было
    ]==]
	read insert: (self: T, U...) -> (),

	--[==[
        Удаляет из объекта указанные элементы, если они были
    ]==]
	read remove: (self: T, U...) -> (),

	--[==[
        Объект ищет и возвращает из себя объекты с указанным типом.
    ]==]
	read collect: <T, E>(self: T, utype: string) -> ...E,

	--[==[
        Ищет в объекте указанные элементы, возвращает были ли они или нет?
    ]==]
	read find: (self: T, U...) -> ...boolean,
}

--[==[
    Объект имеет цели ради которых выполняет какую-либо работу. Это общий интерфейс для таких объектов.
]==]
export type I_targetable<T = unknown, U = unknown> = {
	--[==[
        Устанавливает цель. Невалидные цели игнорирует.
    ]==]
	read set_target: (self: T, target: U) -> (),

	--[==[
        Получает цель объекта в зависимости от предоставляемого им контракта.
    ]==]
	read get_target: (self: T) -> U,
}
