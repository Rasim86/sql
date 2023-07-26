CREATE OR REPLACE PACKAGE M_TTK."IRBIS_IS" is
/*
Назначение программы: Пакет процедур и функций для взаимодействия с системой "Ирбис"
Версия: 0.0.0.2
Версия модуля RM: 1.6.2.262
Версия модуля OM (eAbonent): 1.6.3.222
Дата изменения: 05.03.2019 г.

Дата создания: 26.03.2009 г.
Автор: Мухамеев Т.Н.
Контактный e-mail: tmuhameev@kazan.amfitel.ru
Поддержка: Рахматуллин А.И., Абросимова И.С.
Контактный e-mail: arakhmatullin@kazan.amfitel.ru
*/

  TYPE service_info IS RECORD(service_name VARCHAR2(255), service_info VARCHAR2(255), state NUMBER);
  TYPE service_info_table IS TABLE OF service_info INDEX BY BINARY_INTEGER;
  TYPE line_info IS RECORD(line_id NUMBER, Services service_info_table, line_length NUMBER(10,5));
  TYPE line_info_table IS TABLE OF line_info INDEX BY BINARY_INTEGER;

  -- структуры для процедуры GetTKInfo
  TYPE tk_info IS RECORD(tk_id NUMBER, line_id NUMBER, service VARCHAR(255), client_name VARCHAR2(255), tel VARCHAR2(30));
  TYPE tk_info_table IS TABLE OF tk_info INDEX BY BINARY_INTEGER;

PROCEDURE GetTechnicalFeasibility
(
   HouseID   IN  NUMBER,
   Apartment IN  VARCHAR2,
   Info      OUT line_info_table
);

PROCEDURE GetTechnicalFeasibility
(
   HouseID   IN  NUMBER,
   Apartment IN  VARCHAR2,
   Info      OUT line_info_table,
   TextInfo  OUT VARCHAR2
);

-- Процедура определения технической возможности по номеру телефону.
-- Процедура идентична GetTechnicalFeasibility, но вместо адреса должен передаваться
--    номер телефона (в полном 10-значном виде), который используется для определения
--    адреса установки.
PROCEDURE GetTechnicalFeasibilityByPhone
(
   aPhone IN     VARCHAR2,
   aInfo     OUT line_info_table
);

--Передача текущего значения поля комментарий в атрибут документа в системе тех. учета
PROCEDURE SetDocComment(
   RequestID  IN NUMBER,    -- идентификатор заявки в IRBiS
   DocComment IN VARCHAR2   -- комментарий из заявки Ирбис
);

FUNCTION GetCurrentRequestStatus (
   RequestID IN NUMBER
) RETURN VARCHAR2;

-- Моментальная проверка наличия свободной номерной емкости
PROCEDURE GetAvailableFreeNums
(
   Num         IN  VARCHAR2,   -- старый номер телефона
   Res         OUT VARCHAR2    -- результат, есть/нет свободная номерная емкость на АТС
);

-- процедура вызывается из Ирбис в случае
-- 1. когда после успешно обработанной техсправки на определение техвозможности
--    абонент отказался подписывать договор и оплачивать установку
-- 2. когда не удалось забронировать ресурсы и заявка осталась в подвешенном
--    состоянии - ожидать
-- т.е. создания наряда в итоге не произойдет и необходимо завершить работу с
-- документами и техкартой
PROCEDURE AnnulTC
(
   RequestID IN NUMBER
);

-- процедура аналогично AnnulTC,
-- но для существующих услуг и отменяет изменения, сделанные в техкарте
PROCEDURE AnnulRevisionTC
(
   RequestID IN NUMBER
);

-- Процедура запуска процесса установки СПД
PROCEDURE CreateTC
(
    pRequestID          IN NUMBER,      -- идентификатор заявки в IRBiS
    pLineID             IN NUMBER,      -- идентификатор первичного ресурса (линии), на который следует произвести подключение
                                            -- если 0 - то организовать новую линию
                                            -- если -1 - значит технической возможности на данный момент нет, но заявку на подключение нужно сформировать
                                        -- если идентификатор ресурса не относится к передаваемому адресу подключения, значит это подключение на <соседскую> линию
    pEquipmentModel     IN VARCHAR2,    -- модель оборудования
    pConnectionType     IN VARCHAR2,    -- тип подключения (ADSL, SHDSL и т.п.)
    pAuthenticationType IN VARCHAR2,    -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
    pTarifficationType  IN VARCHAR2,    -- тип тарификации (NetFlow поip, SNMP и т.п.)
    pEquipmentNumber    IN VARCHAR2,    -- серийный номер оборудования
    MainParam           IN VARCHAR2     -- набор XML-данных, содержащий универсальные параметры
);

-- вариант функции для БП "Установка телефона"
PROCEDURE CreatePSTNTC
(
   RequestID         IN NUMBER,    -- идентификатор заявки в IRBiS
   LineID            IN NUMBER,    -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение, если null - то организовать новую линию
   PhoneNumber       IN VARCHAR2,  -- опциональный параметр, если оператор вручную назначает номер телефона для тех.справки (например он был забронирован)
   PhoneCategory     IN NUMBER,    -- категория оператора дальней связи
   CallBarringState  IN NUMBER,    -- статус исходящей связи
   ConnectionType    IN VARCHAR2,  -- тип подключения (voip, аналог и т.п.)
   MainParam         IN VARCHAR2   -- набор XML-данных, содержащий универсальные параметры
);

-- Процесс создание Тех.Карты  на установку охранной сигнализации
PROCEDURE ProcessPlantAlarm (
   RequestID   IN NUMBER,    -- идентификатор заявки в IRBiS
   Num         IN VARCHAR2,  -- номер телефона, на который производится установка охранной сигнализации
   AlarmKey    IN VARCHAR2,  -- значение ключа охраны, в виде текста
   MainParam   IN VARCHAR2   -- набор XML-данных, содержащий универсальные параметры
);


-- Процесс перекроссировки охранной сигнализации
PROCEDURE ProcessReCrossAlarm
(
   RequestID    IN NUMBER,   -- идентификатор заявки в IRBiS
   NewAlarmKey  IN VARCHAR2, -- значение старого ключа охраны, в виде текста
   MainParam    IN VARCHAR2   -- XML с общей информацией
);

/*
 * Смена технологии подключения (21-й БП)
 * Создание техсправки - перегруженная процедура
 */
PROCEDURE CreateChangeTechTC
(
   RequestID          IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID         IN NUMBER,   -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение
   oldConnectionType  IN VARCHAR2, -- текущий тип подключения (voip, аналог и т.п.)
   newConnectionType  IN VARCHAR2, -- выбранный тип подключения (voip, аналог и т.п.)
   PhoneNumber        IN VARCHAR2, -- заполняется, если оператор вручную назначает номер телефона для тех.справки (например он был забронирован)
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   TarifficationType  IN VARCHAR2, -- тип тарификации (NetFlow поip, SNMP и т.п.)
   EquipmentNumber    IN VARCHAR2, -- серийный номер оборудования
   DeviceType         IN VARCHAR2,-- тип устройства
   MainParam          IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

/*
 * Смена технологии подключения (21-й БП)
 * Создание наряда
 */
PROCEDURE CreateChangeTechOrder
(
   RequestID           IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish        IN DATE,     -- желаемая дата подключения
   DateMontComment     IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment      IN VARCHAR2, -- комментарий оператора к наряду
   NewContractCommonID IN NUMBER, -- идентификатор  нового абонемента
   MainParam           IN VARCHAR2 DEFAULT NULL  -- набор XML-данных, содержащий универсальные параметры
);

-- Создание наряда на замену номера
PROCEDURE CreateCommutationTelNumOrder
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   MainParam       IN VARCHAR2,  -- XML с общей информацией
   DVOList         IN VARCHAR2   -- XML с услугами ДВО
);

-- Создание заявления, ТС на замену номера, используется коллекция MainParam
PROCEDURE CreateNumTS
(
   RequestID     IN NUMBER,    -- идентификатор заявки в IRBiS
   Num           IN VARCHAR2,  -- выбранный номер телефона (10 знаков)
   EхpDate       IN DATE,      -- Ожидаемая абонентом дата изменения телефонного номера
   MainParam     IN VARCHAR2   -- XML с общей информацией
);

-- Процедура запуска процесса переноса
-- Создать заявление
-- Создать техкарту
-- Привязать техкарту к заявлению
PROCEDURE CreateTransferTC
(
   RequestID          IN NUMBER,   -- идентификатор заявки в IRBiS
   LineID             IN NUMBER,   -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение,
                                   -- OBSOLETE: если null - то организовать новую линию
                                   -- 0  = выбран вариант установки на новую линию (ТВ есть),
                                   -- -1 = ТВ не определяется, выбран вариант установки без ТВ, с обследованием
   NewHouseID         IN NUMBER,   -- идентификатор дома, адрес на которой происходит перенос
   NewApartment       IN VARCHAR2, -- номер квартиры (офиса),  адрес на которой происходит перенос
   ConnectionType     IN VARCHAR2, -- тип подключения (ADSL, SHDSL и т.п.)
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   TarifficationType  IN VARCHAR2, -- тип тарификации (NetFlow поip, SNMP и т.п.)
   BegEndPP           IN NUMBER,   -- при переносе прямого провода указание переносимого конца прямого провода (1 - начало ПП, 0 ? конец)
   MainParam          IN VARCHAR2  -- XML с общей информацией
);

-- Запуск наряда по процессу переноса
PROCEDURE CreateTransferOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment IN VARCHAR2, -- комментарий к дате назначения монтера
   DateMontWish    IN DATE,     -- желаемая дата прихода монтера
   MainParam       IN VARCHAR2, -- XML с общей информацией
   DVOList         IN VARCHAR2  -- XML с услугами ДВО
);

-- Создание наряда на отключение КТВ
PROCEDURE CreateKTVConnDisconnOrder
(
   RequestID    IN NUMBER,   -- идентификатор заявки в IRBiS
   ChangeType   IN NUMBER,   -- тип изменения: 1 ? отключение по задолженности; 2 ? включение после откл. по задолженности, 3- смена ТП
   --TCID         IN NUMBER,   -- идентификатор технической карты
   --AbonementID  IN NUMBER,   -- идентификатор абонемента
   --ClientID     IN NUMBER,   -- номер клиента в IRBiS
   --ContactPhone IN VARCHAR2, -- контактный телефон абонента
   --OperatorName IN VARCHAR2, -- ФИО оператора создавшего заявление
   CurTP        IN VARCHAR2, -- текущий ТП КТВ
   NewTP        IN VARCHAR2, -- новый ТП КТВ
   DateMontWish IN DATE DEFAULT SYSDATE,     -- желаемая дата подключения
   MainParam    IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

-- Процесс переоформления
PROCEDURE RenewalTC
(
   RequestID      IN NUMBER,               -- идентификатор заявки в IRBiS
   TKID           IN NUMBER,               -- идентификатор Тех карты
   oldAbonementID IN NUMBER,               -- идентификатор старого абонемента
   newAbonementID IN NUMBER,               -- идентификатор нового абонемента
   MainParam      IN VARCHAR2 DEFAULT NULL -- набор XML-данных, содержащий универсальные параметры
);

-- Создание наряда на установку параллельного аппарата
PROCEDURE CreateParallelAppTK
(
   RequestID         IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish      IN DATE,     -- желаемая дата прихода специалиста
   DateMontComment   IN VARCHAR2, -- комментарий к дате прихода специалиста
   NewHouseID        IN NUMBER,   -- идентификатор дома, адрес на который устанавливается параллельный аппарат
   NewApartment      IN VARCHAR2, -- номер квартиры (офиса), адрес на которой устанавливается параллельный аппарат
   MainParam         IN VARCHAR2  -- XML с общей информацией
);

--Создание наряда на снятие параллельного аппарата
PROCEDURE DeleteParallelAppTK
(
   RequestID         IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish      IN DATE,     -- желаемая дата снятия
   DateMontComment   IN VARCHAR2, -- комментарий к дате назначения монтера
   OldHouseID        IN NUMBER,   -- идентификатор дома, адрес c которого снимается параллельный аппарат
   OldApartment      IN VARCHAR2, -- номер квартиры (офиса), адрес c которого снимается параллельный аппарат
   MainParam         IN VARCHAR2  -- XML с общей информацией
);

-- Установка параллельного аппарата
PROCEDURE ModificationParallelAppTK
(
   RequestID   IN NUMBER,  -- идентификатор заявки в IRBiS
   TC          IN NUMBER,  -- идентификатор Тех карты
   AbonementID IN NUMBER,  -- идентификатор абонемента
   ExpDate     IN DATE     -- ожидаемая клиентом дата установки параллельного аппарата
);

-- Создание технической карты на бронирование тел номера
PROCEDURE CreateResNumTC (
   RequestID   IN NUMBER,    -- идентификатор заявки в IRBiS
   AbonementId IN NUMBER,    -- идентификатор абонемента
   PhoneNumb   IN VARCHAR2   -- бронируемый номер телефона (10-знаков)
);

-- Фиксирование бронирования ТК
PROCEDURE FixResNumTC
(
   RequestID IN NUMBER   -- идентификатор заявки в IRBiS
);

-- Процесс снятия брони телефонного номера
PROCEDURE ProcessExResNum
(
   RequestID   IN NUMBER,  -- идентификатор заявки в IRBiS
   TC          IN NUMBER,  -- идентификатор Тех. Карты
   AbonementID IN NUMBER,  -- идентификатор абонемента
   ExpDate     IN DATE     -- ожидаемая абонентом дата бронирования телефонного номера
);

-- Создание заявления и технической карты для БП "Установка IPTV"
PROCEDURE CreateIPTVTC
(
   RequestID      IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID     IN NUMBER,   -- идентификатор первичного ресурса (ЛД в случае xDSL, порт в случае Ethernet) на который следует произвести подключение. Если 0 ? то IPTV устанавливается без интернета
   ConnectionType IN VARCHAR2, -- тип подключения (IP TV xDSL, IP TV Ethernet)
   MainParam      IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

  PROCEDURE CreatePrimaryConnectionOrder (
     RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
     DateMontComment IN VARCHAR2, -- комментарий к дате назначения монтера
     RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
     DateMontWish    IN DATE,     -- желаемая дата подключения
     MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
  );

  PROCEDURE CreatePrimaryConnectionOrder (
     RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
     DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
     RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
     DateMontWish     IN DATE,     -- желаемая дата подключения
     PFloor           IN VARCHAR2, -- Этаж расположения точки WiFi Sagem
     MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
  );

  PROCEDURE CreatePrimaryConnectionOrder (
     RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
     DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
     RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
     DateMontWish     IN DATE,     -- желаемая дата подключения
     PhoneCategory    IN NUMBER,   -- категория оператора дальней связи
     CallBarringState IN NUMBER,   -- статус исходящей связи
     MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
  );

  PROCEDURE CreatePrimaryConnectionOrder (
     RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
     DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
     RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
     DateMontWish     IN DATE,     -- желаемая дата подключения
     PhoneCategory    IN NUMBER,   -- категория оператора дальней связи
     CallBarringState IN NUMBER,   -- статус исходящей связи
     EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
     PFloor           IN VARCHAR2, -- этаж расположения точки WiFi Sagem
     MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
  );

  --Создание заявление и наряда на снятие услуг (старая)
  -- Тип снимаемой услуги определятся по критериям справочника "Выбор вида".
  PROCEDURE CloseTC
  (
     RequestID    IN NUMBER,     -- идентификатор заявки на расторжение в IRBiS
     CloseReason  IN VARCHAR2,   -- причина отказа от услуг
     AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.) --НОВОЕ
     MainParam          IN VARCHAR2  -- XML с общей информацией --НОВОЕ
  );

 --Создание заявление и наряда на снятие услуг
  PROCEDURE CloseTC
  (
     RequestID          IN NUMBER,    -- идентификатор заявки на расторжение в IRBiS
     CloseReason        IN VARCHAR2,  -- причина отказа от услуг
     AuthenticationType IN VARCHAR2,  -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
     DateMontWish       IN DATE,      -- желаемая дата подключения --WifiStreet
     DateMontComment    IN VARCHAR2,  -- комментарий к дате назначения монтера --WifiStreet
     MainParam          IN VARCHAR2   -- XML с общей информацией --НОВОЕ
  );

  -- смена категории исходящей связи
  PROCEDURE SetPhoneCategory (
     RequestID       IN NUMBER,
     TCID            IN NUMBER,
     PhoneCategory   IN NUMBER,
     ClientID       IN NUMBER    -- номер клиента в IRBiS
  );

  -- смена статуса исходящей связи
  PROCEDURE SetCallBarringState (
     RequestID          IN NUMBER,
     TCID               IN NUMBER,
     CallBarringState   IN NUMBER,
     ClientID       IN NUMBER    -- номер клиента в IRBiS
  );

-- Обработка одного документа М2000: отправка уведомления в систему IRBiS
-- Функция НЕ обрабатывает исключения
-- Функция НЕ проверяет текущее состояние документа в списке соответствий, т.е.
--    пытается отправить уведомление, даже если оно уже было отправлено ранее.
-- Функция изменяет текущее состояние документа в списке соответствий
--    документов и заявок IRBiS
-- Возвращаемые значения:
--    0 = уведомление не было отправлено
--    1 = уведомление было отправлено
--    Кроме того, разумеется, возможны исключительные ситуации - это забота вызывающего
FUNCTION SendToIrbis (
   aPAPER      IN NUMBER,    -- ID документа M2000
   aIS_SUCCESS IN NUMBER     -- 1 - отправить уведомление об успехе / 0 - отправить о неуспехе
) RETURN NUMBER;

-- Выделение сетевого ресурса - Создание заявления и технической карты
PROCEDURE CreateTCDirWire
(
   RequestID      IN NUMBER,   -- идентификатор заявки в IRBiS
   ConnectionType IN VARCHAR2, -- тип сетевого ресурса (прямой провод, поток Е1, SIP-транк)
   BgnHouseID     IN NUMBER,
   BgnApartment   IN VARCHAR2,
   EndHouseID     IN NUMBER,   -- идентификатор дома, адрес подключения которого интересует (2 конец при установке прямого провода)
   EndApartment   IN VARCHAR2, -- номер квартиры (офиса), адрес подключения которого интересует (2 конец при установке прямого провода)
   Direction      IN VARCHAR2, -- направление прямого провода
   KolChannel     IN NUMBER,   -- количество каналов
   Capacity       IN VARCHAR2, -- пропускная способность
   MainParam      IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

-- Выделение сетевого ресурса - Запуск наряда
PROCEDURE CreateDirWireConnectOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста на 1 конец ПП
   DateMontWishEnd IN DATE,     -- желаемая дата прихода специалиста на 2 конец ПП
   DateMontComment IN VARCHAR2, -- комментарий к дате прихода специалиста
   RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
   DateActivation  IN DATE,     -- дата заявленной активации
   MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

-- Замена СРЕ(модема WiFi Guest, Sip-адаптера, оборудования ЦКТВ)
PROCEDURE CreateChangeModemTS
(
   RequestID          IN     NUMBER,   -- идентификатор заявки в IRBiS
   EquipmentNumberOld IN     VARCHAR2, -- серийный номер старого оборудования
   EquipmentNumber    IN     VARCHAR2, -- серийный номер оборудования
   MainParam          IN     VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   LineID             OUT    NUMBER,    -- идентификатор базового ресурса (оборудования)
   EquipmentLicense  OUT    VARCHAR2  -- внутренний номер устройства ЦКТВ
);

-- Замена СРЕ(модема WiFi Guest или Sip-адаптера) - Запуск наряда
PROCEDURE CreateChangeModemOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment IN VARCHAR2, -- комментарий к дате прихода специалиста
   RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
   MainParam       IN VARCHAR2,  -- набор XML-данных, содержащий универсальные параметры
   OfficeId        IN NUMBER,   --идентификатор  выбранного офиса/склада
   Сonditions      IN NUMBER    --условия выдачи оборудования: 112  - Покупка оборудования(выкуп) , 111  -  Аренда, 113 - Оборудование клиента (продажа)
);

-- MVNO

-- Создание заявления и техкарты для БП "Установка MVNO"
PROCEDURE CreateMVNOTC
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   PhoneNumber     IN  VARCHAR2, -- обязательный параметр, содержит номер телефона в формате DEF
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   TC              OUT NUMBER,   -- номер тех.карты
   ResourceID      OUT NUMBER    -- идентификатор ресурса
);

-- Создание заявления и техсправки для БП "Замена номера MVNO"
PROCEDURE CreateMVNOZmn
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   TKID            IN  NUMBER,   -- идентификатор Тех Карты
   PhoneNumber     IN  VARCHAR2, -- выбранный номер телефона
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   ResourceID      OUT NUMBER    -- идентификатор ресурса
);

-- Закрытие MVNO
PROCEDURE TCCloseMVNO
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   TKID            IN  NUMBER,   -- идентификатор Тех Карты
   MainParam       IN  VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

PROCEDURE CreateSIPTC
(
   RequestID        IN  NUMBER,
   LineID           IN  NUMBER,
   PhoneNumber      IN  VARCHAR2,
   PhoneCategory    IN  NUMBER,
   CallBarringState IN  NUMBER,
   ConnectionType   IN  VARCHAR2,
   EquipmentNumber  IN  VARCHAR2,
   Login            IN  VARCHAR2,
   Password         IN  VARCHAR2,
   DeviceType       IN  VARCHAR2,
   MainParam        IN  VARCHAR2
);

PROCEDURE GetAddressID
(
   aIRBIS_HOUSE  IN  NUMBER,              -- идентификатор дома в Ирбис
   aAPARTMENT    IN  VARCHAR2,            -- наименование помещения (квартиры)
   aADDRESS_ID   OUT NUMBER,              -- возвращаемое значение (в случае успешного нахождения)
   aHOUSEONLY    IN OUT NUMBER,           -- возвращаемый признак, что дом содержит квартиры (но не был указан номер квартиры)
   aPRIVATEHOUSE IN OUT NUMBER,           -- возвращаемый признак, что дом не имеет квартир
   aCAN_RAISE    IN  NUMBER DEFAULT 0,    -- определяет, должна ли процедура сама генерировать исключение, когда адрес не найден (1=надо генерировать)
   aSTATE        OUT NUMBER               -- возвращаемое состояние (0=успешно, 1=ошибки)
);

-- Создание заявления и ТС на подключение КТВ и ЦКТВ
PROCEDURE CreateKTVTC
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID      IN NUMBER,   -- идентификатор первичного ресурса (порта), на который следует произвести подключение
   EquipmentNumber IN VARCHAR2, -- серийный номер устройства
   DeviceType      IN VARCHAR2, -- тип устройства
   MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

-- Получение внутреннего номера оборудования по его серийному номеру
-- Возвращает внутренний номер или -1, если оборудование не найдено
FUNCTION GetEquipmentLicense
(
   EquipmentNumber IN  VARCHAR2  -- серийный номер оборудования
) RETURN VARCHAR2;

-- Создание повторного наряда на установку SIP РТУ, ЦКТВ в случае замены неисправного оборудования
PROCEDURE CreateConnOrderChangeEquip(
   RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish     IN DATE,     -- желаемая дата подключения
   EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
   DeviceType       IN VARCHAR2, -- тип оборудования
   MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
);

-- <02.07.2015-Точкасова М.А.> Определение оборудования в данной ТК:
function GetEquipParam(ContractTCID IN NUMBER) return varchar2;

-- <02.02.2016-Точкасова М.А.> Добавление в связанные ТК оборудования СРЕ (R-0005078)
PROCEDURE AddCPEtoTK
(
   TKID          IN   NUMBER,               --идентификатор тк, для которой ищем связанные тк
   EquipID       IN   NUMBER,               --идентификатор добавляемого оборудовния
   OldEquipID    IN   NUMBER DEFAULT NULL,   --идентификатор базового ресурса
   xRMDocID      IN   NUMBER DEFAULT NULL   --документ RM
);

-- <02.02.2016-Точкасова М.А.> Заявка на замену/выдачу паспортизированного клиентского оборудования (СРЕ):
PROCEDURE CreateChangeModemTS
(
   RequestID          IN     NUMBER,   -- идентификатор заявки в IRBiS
   ActionType         IN     NUMBER,   -- тип операции: 10 ? Замена паспортизированного клиентского оборудования, 11 ? Выдача паспортизированного клиентского оборудования
   EquipmentNumberOld IN     VARCHAR2, -- серийный номер старого оборудования
   EquipmentNumber    IN     VARCHAR2, -- серийный номер оборудования
   LineID             IN     NUMBER,    -- идентификатор базового ресурса (оборудования)
   MainParam          IN     VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   EquipmentLicense   OUT    VARCHAR2,  -- внутренний номер устройства ЦКТВ
   EquipmentTIP       OUT    NUMBER     -- тип оборудования
);
-- <24.05.2016-Точкасова М.А.> Заявка на усановку/снятие доп.номера сотовой связи
PROCEDURE CreateDocChangeAddNumber
(
   AttainAddNumberFlag IN BOOLEAN,--тип операции (true – подключение доп. номера, false – отключение доп.номера)
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   MobileNumber    IN  VARCHAR2, -- выбранный номер телефона (10 знаков)
   MainParam       IN  VARCHAR2 -- набор XML-данных, содержащий универсальные параметры
);
PROCEDURE CreateOrderCall
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
   mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
   Servicetypes    IN VARCHAR2,    -- услуга
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   mPNumber        OUT VARCHAR2
);
   PROCEDURE CreateSpeedChange
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   DateSpeed       IN DATE,     -- желаемая дата изменения скорости
   mNEW_SREED      IN VARCHAR2,
   mSPEED          IN VARCHAR2,
   mNAS            IN VARCHAR2,
   mVLAN           IN VARCHAR2,
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   mPNumber        OUT VARCHAR2
);
    -- <13.04.2020 - Хузин А.Ф.> - Создание заявления и техсправки на смену скорости 100+
    PROCEDURE CreateSpeedChange
    (
        RequestID       IN NUMBER,      -- идентификатор заявки в IRBiS
        RequestComment  IN VARCHAR2,    -- комментарий оператора к наряду
        DateMontWish    IN DATE,        -- желаемая дата прихода специалиста
        mContactPhone   IN VARCHAR2,    -- контактный телефон абонента
        Servicetypes    IN VARCHAR2,    -- услуга
        MainParam       IN VARCHAR2,    -- набор XML-данных, содержащий универсальные параметры
        mPNumber        OUT VARCHAR2    -- результат
    );

    -- <13.04.2020 - Хузин А.Ф.> - Создание наряда на смену скорости 100+
    PROCEDURE CreateSpeedChangeOrder
    (
       RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
       RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
       DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
       mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
       Servicetypes    IN VARCHAR2,    -- услуга
       MainParam       IN VARCHAR2,   -- набор XML-данных, содержащий универсальные параметры
       mPNumber        OUT VARCHAR2
    );

    -- <17.12.2020 - Хузин А.Ф.> - Создание заявления и техсправки на выдачу и удаление номеров ВАТС
    PROCEDURE CreateNumberVATS
    (
        RequestID       IN NUMBER,      -- идентификатор заявки в IRBiS
        RequestComment  IN VARCHAR2,    -- комментарий оператора к наряду
        mContactPhone   IN VARCHAR2,    -- контактный телефон абонента
        NumberType      IN VARCHAR2,    -- тип номера: 1 - Внешний номер; 2 - Номер DIZA; 3 - Внутренний номер
        Conditions      IN NUMBER,      -- условие: 1 - добавление 2 - удаление номера
        mPhone          IN VARCHAR2,    -- номера
        MainParam       IN VARCHAR2,    -- набор XML-данных, содержащий универсальные параметры
        mPNumber        OUT VARCHAR2,   -- ТС
        mAccount        IN NUMBER,      -- ЛС
        mDomenVATS      IN VARCHAR2     -- наименование домена ВАТС
    );

    -- <17.12.2020 - Хузин А.Ф.> - Создание наряда на на выдачу и удаление номеров ВАТС
    PROCEDURE CreateNumbersVATSOrder
    (
        RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
        RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
        mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
        NumberType      IN VARCHAR2,  -- тип номера: 1 - Внешний номер; 2 - Номер DIZA; 3 - Внутренний номер
        Conditions      IN NUMBER,    -- условие: 1 - добавление 2 - удаление номера
        mPhone          IN VARCHAR2,  -- номера
        MainParam       IN VARCHAR2,  -- набор XML-данных, содержащий универсальные параметры
        mPNumber        OUT VARCHAR2, -- наряд
        mAccount        IN NUMBER,    -- ЛС
        mDomenVATS      IN VARCHAR2   -- наименование домена ВАТС
    );

    PROCEDURE ad_eq_logs
    (
        -- aLOG_ID  NUMBER,
        -- aLOG_DATE DATE,
        OPERATION VARCHAR2,
        REQUEST_ID NUMBER,
        equipmentNumberOld VARCHAR2,
        LOG_ERRORS    VARCHAR2
    );

    -- Получение текущей информации о коммутаторе по связанной техкарте с абонементом  КТВ GPON
    PROCEDURE GetCurrentEquipGpon
    (
        RequestID IN NUMBER,
        ContractTCID IN NUMBER,
        IPadr OUT VARCHAR2,
        OID OUT VARCHAR2,
        VirtPort OUT VARCHAR2,
        EquipmentNumber OUT VARCHAR2
    );

    -- Смена типа номера и типа ТК для переключения телефонии на SIP-VOIP
    PROCEDURE ChangeTypeTKAndNumber
    (
        pTK_ID  IN rm_tk_data.tkd_tk%TYPE,      -- ID ТК
        pNumber IN rm_numbers.num_number%TYPE   -- Номер телефона (не мобилка)
    );

    -- Создание ТС на перелючение телефонии на SIP VOIP
    PROCEDURE ChangeOnSIPVOIP
    (
        RequestID        IN  NUMBER,    -- ID заявки
        TK_ID            IN  NUMBER,    -- ID тех.карты
        PhoneNumber      IN  VARCHAR2,  -- номер телефона
        PhoneCategory    IN  NUMBER,    -- Оператор дальней связи
        CallBarringState IN  NUMBER,    -- ВЗ,МГ,МН
        ConnectionType   IN  VARCHAR2,  -- Тип подключения
        EquipmentNumber  IN  VARCHAR2,  -- Серийный номер fake-оборудования
        DeviceType       IN  VARCHAR2,  -- Модель оборудования
        MainParam        IN  VARCHAR2
    );

    -- Создание наряда на переключние телефонии на SIP VOIP
    PROCEDURE ChangeOrderOnSIPVOIP
    (
        RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
        EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
        MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
    );

    -- Транслит адреса установки
    FUNCTION GetTranslit(fValue IN VARCHAR2) RETURN VARCHAR2;

    -- Процедура логирования команд на OLT
    PROCEDURE Write_Activity_OLT_log
    (
        pOperation      VARCHAR2,
        pMetod          VARCHAR2,
        pRespCode       VARCHAR2,
        pRequest        VARCHAR2,
        pCommand        VARCHAR2,
        pPesponse_XML   CLOB,
        pPaper_id       NUMBER
    );

    -- Вкл/приостановление услуг на OLT
    PROCEDURE ChangeSettingOLT
    (
        pPaperID        IN NUMBER,
        pAction         IN NUMBER,      -- 0-приостановление; 1-включение;
        pService        IN VARCHAR2,
        pOLT_IP         IN VARCHAR2,
        pModul          IN VARCHAR2,
        pVirtPort       IN VARCHAR2,
        pResponseText   OUT CLOB,
        pMessage        OUT VARCHAR2,
        pCode           OUT VARCHAR2
    );

    -- Снятие услуги с OLT
    PROCEDURE DeleteSettingOLT
    (
        pPaperID        IN NUMBER,
        pOLT_IP         IN VARCHAR2,
        pModul          IN VARCHAR2,
        pVirtPort       IN VARCHAR2,
        pResponseText   OUT CLOB,
        pMessage        OUT VARCHAR2,
        pCode           OUT VARCHAR2
    );

    -- Настройка клиентского оборудования на OLT
    PROCEDURE ConnectionSettingOLT
    (
        pPaperID        IN NUMBER,  -- ID наряда
        pEquipNumber    IN VARCHAR2 DEFAULT NULL -- серийный номер клиентского оборудования
    );

    -- Создание заявления и наряда для облачного видеонаблюдения
    PROCEDURE CreateCloudVideo
    (
        RequestID       IN NUMBER,      -- ID заявки
        DateMontWish    IN DATE,        -- Желаемая дата прихода специалиста
        TK_ID           IN NUMBER,      -- ID тех.карты
        ConnectionType  IN VARCHAR2,    -- Тип подключения
        RequestComment  IN VARCHAR2,    -- Комментарии из Ирбиса
        MainParam       IN VARCHAR2
    );

    -- Создание заявления и наряда для расторжения облачного видеонаблюдения
    PROCEDURE CloseCloudVideo
    (
        RequestID       IN NUMBER,      -- ID заявки
        CloseReason     IN VARCHAR2,    -- Причина отказа от услуг
        DateMontWish    IN DATE,        -- Желаемая дата прихода специалиста
        TK_ID           IN NUMBER,      -- ID тех.карты
        ConnectionType  IN VARCHAR2,    -- Тип подключения
        RequestComment  IN VARCHAR2,    -- Комментарии из Ирбиса
        Dismantling     IN NUMBER,     -- Требуется демонтаж
        MainParam       IN VARCHAR2
    );
   
   -- Процедура логирования команд на xDSL
    PROCEDURE Write_Activity_xDSL_log
    (
        pOperation      VARCHAR2,
        pMetod          VARCHAR2,
        pRespCode       VARCHAR2,
        pRequest        VARCHAR2,
        pCommand        VARCHAR2,
        pPesponse_XML   CLOB,
        pPaper_id       NUMBER
    );

END IRBIS_IS;

CREATE OR REPLACE PACKAGE BODY M_TTK."IRBIS_IS" is

  -- фиктивный пользователь - система "Ирбис"
  irbis_user_id   CONSTANT NUMBER := 992;

  ------------------------------------------------------------------------------
  -- Соответствие ID технических отделов филиалам
  ------------------------------------------------------------------------------
/*
  -- Технический отдел филиала "Набережно-Челнинская (ГМТТС)" (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_22     CONSTANT NUMBER := 77;
  -- Технический отдел филиала "Менделеевский РУЭС"           (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_49     CONSTANT NUMBER := 120;
  -- Технический отдел филиала "Агрызский РУЭС"               (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_51     CONSTANT NUMBER := 52;
  -- Технический отдел филиала "Актанышский РУЭС"             (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_52     CONSTANT NUMBER := 57;
  -- Технический отдел филиала "Мензелинский РУЭС"            (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_55     CONSTANT NUMBER := 62;
  -- Технический отдел филиала "Елабужский РУЭС"              (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_57     CONSTANT NUMBER := 104;
  -- Технический отдел филиала "Елабужский ЛКЦ"               (Набережно-Челнинский ЗУЭС - 2)
  otdel_id_85     CONSTANT NUMBER := 409;
  -- Технический отдел филиала "Елабужский ЛКЦ"               (Набережно-Челнинский ЗУЭС - 2)
  --otdel_id_85     CONSTANT NUMBER := 409;

  -- Технический отдел филиала "Нижнекамский РУЭС"            (Нижнекамский ЗУЭС - 4)
  otdel_id_5      CONSTANT NUMBER := 99;

  -- Технический отдел филиала "Алексеевский РУЭС"            (Чистопольский ЗУЭС - 6)
  otdel_id_41     CONSTANT NUMBER := 212;
  -- Технический отдел филиала "Чистопольский РУЭС"           (Чистопольский ЗУЭС - 6)
  otdel_id_42     CONSTANT NUMBER := 207;
  -- Технический отдел филиала "Аксубаевский РУЭС"            (Чистопольский ЗУЭС - 6)
  otdel_id_44     CONSTANT NUMBER := 232;
  -- Технический отдел филиала "Нурлатский РУЭС"              (Чистопольский ЗУЭС - 6)
  otdel_id_45     CONSTANT NUMBER := 222;
  -- Технический отдел филиала "Алькеевский РУЭС"             (Чистопольский ЗУЭС - 6)
  otdel_id_46     CONSTANT NUMBER := 217;
  -- Технический отдел филиала "Спасский РУЭС"                (Чистопольский ЗУЭС - 6)
  otdel_id_47     CONSTANT NUMBER := 227;
  -- Технический отдел филиала "Новошешминский РУЭС"          (Чистопольский ЗУЭС - 6)
  otdel_id_48     CONSTANT NUMBER := 125;
  -- Технический отдел филиала "Рыбно-Слободский РУЭС"        (Чистопольский ЗУЭС - 6)
  otdel_id_61     CONSTANT NUMBER := 286;

  -- Технический отдел филиала "Тюлячинский РУЭС"             (Арский ЗУЭС - 7)
  otdel_id_60     CONSTANT NUMBER := 263;
  -- Технический отдел филиала "Сабинский РУЭС"               (Арский ЗУЭС - 7)
  otdel_id_62     CONSTANT NUMBER := 253;
  -- Технический отдел филиала "Мамадышский  РУЭС"            (Арский ЗУЭС - 7)
  otdel_id_63     CONSTANT NUMBER := 114;
  -- Технический отдел филиала "Кукморский РУЭС"              (Арский ЗУЭС - 7)
  otdel_id_64     CONSTANT NUMBER := 258;
  -- Технический отдел филиала "Арский РУЭС"                  (Арский ЗУЭС - 7)
  otdel_id_66     CONSTANT NUMBER := 238;
  -- Технический отдел филиала "Балтасинский РУЭС"            (Арский ЗУЭС - 7)
  otdel_id_68     CONSTANT NUMBER := 248;
  -- Технический отдел филиала "Атнинский РУЭС"               (Арский ЗУЭС - 7)
  otdel_id_69     CONSTANT NUMBER := 243;

  -- Технический отдел филиала "Кайбицкий РУЭС"               (Буинский ЗУЭС - 9)
  otdel_id_70     CONSTANT NUMBER := 191;
  -- Технический отдел филиала "Тетюшский РУЭС"               (Буинский ЗУЭС - 9)
  otdel_id_73     CONSTANT NUMBER := 201;
  -- Технический отдел филиала "Буинский РУЭС"                (Буинский ЗУЭС - 9)
  otdel_id_74     CONSTANT NUMBER := 176;
  -- Технический отдел филиала "Дрожжановский РУЭС"           (Буинский ЗУЭС - 9)
  otdel_id_75     CONSTANT NUMBER := 181;
  -- Технический отдел филиала "Апастовский РУЭС"             (Буинский ЗУЭС - 9)
  otdel_id_76     CONSTANT NUMBER := 186;
  -- Технический отдел филиала "Камско-Устьинский РУЭС"       (Буинский ЗУЭС - 9)
  otdel_id_77     CONSTANT NUMBER := 196;
  -- Технический отдел филиала "Верхнеуслонский РУЭС"         (Буинский ЗУЭС - 9)
  otdel_id_79     CONSTANT NUMBER := 284;

  -- Технический отдел филиала "Альметьевский РУЭС"           (Альметьевский ЗУЭС - 12)
  otdel_id_3      CONSTANT NUMBER := 144;
  -- Технический отдел филиала "Ютазинский РУЭС"              (Альметьевский ЗУЭС - 12)
  otdel_id_10     CONSTANT NUMBER := 168;
  -- Технический отдел филиала "Азнакаевский РУЭС"            (Альметьевский ЗУЭС - 12)
  otdel_id_11     CONSTANT NUMBER := 148;
  -- Технический отдел филиала "Бугульминский РУЭС"           (Альметьевский ЗУЭС - 12)
  otdel_id_14     CONSTANT NUMBER := 268;
  -- Технический отдел филиала "Лениногорский РУЭС"           (Альметьевский ЗУЭС - 12)
  otdel_id_15     CONSTANT NUMBER := 307;
  -- Технический отдел филиала "Черемшанский РУЭС"            (Альметьевский ЗУЭС - 12)
  otdel_id_16     CONSTANT NUMBER := 163;
  -- Технический отдел филиала "Бавлинский РУЭС"              (Альметьевский ЗУЭС - 12)
  otdel_id_19     CONSTANT NUMBER := 153;
  -- Технический отдел филиала "Муслюмовский РУЭС"            (Альметьевский ЗУЭС - 12)
  otdel_id_56     CONSTANT NUMBER := 67;
  -- Технический отдел филиала "Заинский РУЭС"                (Альметьевский ЗУЭС - 12)
  otdel_id_58     CONSTANT NUMBER := 109;
  -- Технический отдел филиала "Сармановский РУЭС"            (Альметьевский ЗУЭС - 12)
  otdel_id_59     CONSTANT NUMBER := 72;

  -- Технический отдел филиала "Казанский УЭС"                (Казанское УЭС - 100)
  otdel_id_100    CONSTANT NUMBER := 361  ;
  -- Технический отдел филиала "Высокогорский РУЭС"           (Казанское УЭС - 100)
  otdel_id_65     CONSTANT NUMBER := 331;
  -- Технический отдел филиала "Пестречинский РУЭС"           (Казанское УЭС - 100)
  otdel_id_67     CONSTANT NUMBER := 342;
  -- Технический отдел филиала "Зеленодольский РУЭС"          (Казанское УЭС - 100)
  otdel_id_71     CONSTANT NUMBER := 41;
  -- Технический отдел филиала "Лаишевский РУЭС"              (Казанское УЭС - 100)
  otdel_id_78     CONSTANT NUMBER := 337;
  -- Технический отдел филиала "Верхнеуслонский РУЭС"         (Казанское УЭС - 100)
  --otdel_id_79     CONSTANT NUMBER := 284;  -- см выше
*/
  -- Технический отдел филиала "" ()
  ------------------------------------------------------------------------------

  -- ID типа свойства абонента "ID услуги IRBIS"
  abonent_irbis_prp_type_id   CONSTANT  NUMBER := 7;   -- ao_attrib_types.id
  -- ID типа свойства абонента "Лицевой счет IRBIS"
  abonent_irbis_id_prp        CONSTANT  NUMBER := 19;  -- ao_attrib_types.id

  -- OBSOLETE: больше не используется, см. tk_type_dsl_new
  -- ID типа тех карты для услуги телефон + DSL
  --tk_type_dsl                 CONSTANT  NUMBER := 2;   -- rm_tk_type.tkt_id
  tk_type_dsl_old             CONSTANT  NUMBER := 2;   -- rm_tk_type.tkt_id

  -- ID типа тех карты для услуги прямой провод + DSL
  --tk_type_ppdsl               CONSTANT  NUMBER := 82;   -- rm_tk_type.tkt_id
  tk_type_dsl_new             CONSTANT  NUMBER := 82;   -- rm_tk_type.tkt_id

  -- ID типа тех карты для услуги телефон
  tk_type_tel                 CONSTANT  NUMBER := 1;   -- rm_tk_type.tkt_id
  -- ID типа тех карты для услуги прямой провод
  tk_type_pp                  CONSTANT  NUMBER := 22;   -- rm_tk_type.tkt_id

  -- ID типа тех карты для услуги IP TV
  tk_type_iptv                CONSTANT  NUMBER := 122;
  -- ID типа тех карты для услуги Охранная Сигнализация
  tk_type_oxr                 CONSTANT  NUMBER := 23;
  -- ID типа тех карты для услуги SIP-телефония
  tk_type_sip                 CONSTANT  NUMBER := 202;
  -- ID типа тех карты для услуги WiMAX
  tk_type_wimax               CONSTANT  NUMBER := 142;
  -- ID типа тех карты для услуги Кабельное ТВ
  tk_type_cable               CONSTANT  NUMBER := 242;
  -- ID типа тех карты для услуги Оптика в дом
  tk_type_etth                CONSTANT  NUMBER := 42;
  -- <nell 04 10 2010>
  -- ID типа тех карты для услуги VoIP-телефония
  tk_type_voip                CONSTANT  NUMBER := 183;
  -- </nell 04 10 2010>
  -- ID типа тех карты Дополн. ISDN телефон
  tk_type_isdn                CONSTANT  NUMBER := 222;
  -- ID типа тех карты для услуги ethernet
  tk_type_ethernet            CONSTANT  NUMBER := 282;
  -- ID типа тех карты для услуги GPON Ethernet
  tk_type_gpon                CONSTANT  NUMBER := 302;
  -- ID типа тех карты для услуги WiFi Guest
  tk_type_wifiguest           CONSTANT  NUMBER := 323;
  -- ID типа тех карты для услуги MVNO
  tk_type_mvno                CONSTANT  NUMBER := 366;
  -- ID типа тех карты для услуги Соединительная линия
  tk_type_sl                  CONSTANT  NUMBER := 102;
  -- ID типа тех карты для услуги WiFi ADSL
  tk_type_wifiadsl            CONSTANT  NUMBER := 374;
  -- ID типа тех карты для услуги WiFi MetroEthernet
  tk_type_wifimetroethernet   CONSTANT  NUMBER := 375;
  -- ID типа тех карты для услуги WiFi Street
  tk_type_wifistreet          CONSTANT  NUMBER := 462;
  -- ID типа тех карты для услуги ВАТС
  tk_type_vats                CONSTANT  NUMBER := 482;
  -- ID типа тех карты для услуги Цифровое Кабельное ТВ
  tk_type_digitalcable        CONSTANT  NUMBER := 522;
  -- ID типа тех карты для услуги СКПТ
  tk_type_ckpt                CONSTANT  NUMBER := 542;

  -- id вида техсправка (установка телефон)
  texspr_id_1_n   CONSTANT NUMBER := 1281;
  -- id вида наряд (установка телефон)
  order_id_1_n    CONSTANT NUMBER := 1282;

  -- id вида техсправка (установка прямой провод)
  texspr_id_2_n   CONSTANT NUMBER := 1283;
  -- id вида наряд (установка прямой провод)
  order_id_2_n    CONSTANT NUMBER := 1284;

  -- id вида техсправка (установка DSL)
  texspr_id_3_n   CONSTANT NUMBER := 1285;
  -- id вида наряд (установка DSL)
  order_id_3_n    CONSTANT NUMBER := 1286;


  -- id вида техсправка (изменение телефон)
  texspr_id_1_e   CONSTANT NUMBER := 6615;
  -- id вида наряд (изменение телефон)
  order_id_1_e    CONSTANT NUMBER := 6616;

  -- id вида техсправка (изменение прямой провод)
  texspr_id_2_e   CONSTANT NUMBER := 6617;
  -- id вида наряд (изменение прямой провод)
  order_id_2_e    CONSTANT NUMBER := 6618;

  -- id вида техсправка (перестановка DSL)
  texspr_id_3_e   CONSTANT NUMBER := 1362;
  -- id вида наряд (перестановка DSL)
  order_id_3_e    CONSTANT NUMBER := 1363;

  -- id вида наряд (снятие телефона)
  order_id_1_c    CONSTANT NUMBER := 6620;

  -- id вида наряд (снятие прямого провода)
  order_id_2_c    CONSTANT NUMBER := 6621;

  -- id вида наряд (снятие DSL)
  order_id_3_c    CONSTANT NUMBER := 1361;

  -- TODO: Виды нарядов для изменения тех данных (пока не предусмотрены)
  order_id_1_td   CONSTANT NUMBER := -1;
  order_id_2_td   CONSTANT NUMBER := -1;
  order_id_3_td   CONSTANT NUMBER := -1;

   -- бизнес процесс подключения к интернет
   BP_INTERNET    CONSTANT NUMBER := 3;

   CRLF           CONSTANT CHAR(2) := CHR(13)||CHR(10);

   CREATOR_WORK_ID CONSTANT NUMBER := 681;

   enc_key        CONSTANT VARCHAR2(16) := 'MTTC_SIP21012013';

/*******************************************************************************
 Внутренние вспомогательные типы:

 TCrossNode      - узел дерева
 TEndNode        - лист дерева - искомые и окончательные узлы
 TBL_CHILDS      - массив для хранения номеров дочерних веток дерева
 TBL_WIRES       - массив для хранения номеров жил, выделенных для линии
 TBL_CROSS       - основное дерево кроссировок
 TBL_CROSS_PATHS - массив для хранения листьев (искомых объектов в дереве)
 ******************************************************************************/

-- массив для хранение номеров дочерних элементов текущего элемента (узла дерава)
TYPE TBL_CHILDS IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

-- массив для хранения номеров жил, выделенных для линии (для текущего узла дерева)
TYPE TBL_WIRES IS TABLE OF rm_comm_wire.wir_id%Type INDEX BY BINARY_INTEGER;

-- тип для динамического дерева кроссировки
TYPE TCrossNode IS RECORD (
   ID            rm_comm_unit.uzl_id%Type,     -- ID узла
   PARENT_ID     BINARY_INTEGER,               -- ID родительского элемента в дереве
   OBJECT_ID     rm_comm_unit.uzl_obj%Type,    -- ID объекта, на котором размещен узел
   OBJECT_CLASS  rm_object.obj_class%Type,     -- класс объекта
   LINK_ID       rm_conn_unit.cuz_conid%Type,  -- ID линии
   LINK_L        rm_conn_info.cin_l%Type,      -- Длина линии
   IS_JACK       rm_comm_unit.uzl_jack%Type,   -- Признак (0 или 1)
   RANG          NUMBER,                       -- Ранг элемента в дереве = уровень вложенности
   CHILDS        TBL_CHILDS,                   -- Список номеров дочерних элементов (массив)
   WIRES         TBL_WIRES,                    -- Список жил
   WIRES_PARENT  TBL_WIRES                     -- Список жил узла, находящегося выше в иерархии
);

TYPE TEndNode IS RECORD (
   ID            rm_comm_unit.uzl_id%Type,     -- ID узла
   PARENT_ID     BINARY_INTEGER,               -- ID родительского элемента в дереве
   OBJECT_ID     rm_comm_unit.uzl_obj%Type,    -- ID объекта, на котором размещен узел
   OBJECT_CLASS  rm_object.obj_class%Type,     -- класс объекта
   LINK_ID       rm_conn_unit.cuz_conid%Type,  -- ID линии
   LINK_L        rm_conn_info.cin_l%Type,      -- Длина линии
   IS_JACK       rm_comm_unit.uzl_jack%Type,   -- Признак (0 или 1)
   RANG          NUMBER,                       -- Ранг элемента в дереве = уровень вложенности
   TREE_INDEX    BINARY_INTEGER                -- Ссылка на этот элемент в дереве
);

-- таблица для дерева кроссировок
TYPE TBL_CROSS IS TABLE OF TCrossNode INDEX BY BINARY_INTEGER;

-- таблица для хранения конечных элементов цепочек в дереве кроссировок
TYPE TBL_CROSS_PATHS IS TABLE OF TEndNode INDEX BY BINARY_INTEGER;

-- объекты
--TABLE_CROSS       TBL_CROSS;       -- основное дерево кроссировок
--TABLE_PATHS       TBL_CROSS_PATHS; -- массив для хранения листьев (искомых объектов в дереве)

PROCEDURE checkKeyParams
(
   aProcedure       IN VARCHAR2,   -- Процедура, из которой вызывается проверка
   aPaperID         IN NUMBER,     -- ID родительского документа для проверки
   aKeyParams       IN VARCHAR2    -- Строка ключевых параметров
)
IS
   vParentKeyParams irbis_activity_log.parameters%TYPE;
   CURSOR GetParentKeyParams IS
      SELECT substr(l.parameters, instr(l.parameters, '", ')+3)
        FROM irbis_activity_log l, irbis_request_papers p
       WHERE l.request_id = p.request_id
         AND p.paper_id = aPaperID
         AND l.operation = aProcedure
    ORDER BY l.id;
BEGIN
   OPEN GetParentKeyParams;
   FETCH GetParentKeyParams INTO vParentKeyParams;
   IF GetParentKeyParams%FOUND THEN
      IF NOT (UPPER(vParentKeyParams) = UPPER(aKeyParams)) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Изменились ключевые параметры, создание документа невозможно!');
      END IF;
   END IF;
   CLOSE GetParentKeyParams;
END checkKeyParams;

PROCEDURE GetTechnicalFeasibility
(
   HouseID   IN  NUMBER,
   Apartment IN  VARCHAR2,
   Info      OUT line_info_table
)
IS
mInfo irbis_is_core.line_info_table;
BEGIN
   irbis_is_core.GetTechnicalFeasibility(HouseID,
                                         Apartment,
                                         mInfo);
   IF mInfo.COUNT > 0 THEN
      FOR i IN mInfo.FIRST..mInfo.LAST LOOP
         Info(i).line_id := mInfo(i).line_id;
         IF mInfo(i).Services.COUNT > 0 THEN
            FOR j IN mInfo(i).Services.FIRST..mInfo(i).Services.LAST LOOP
               Info(i).Services(j).service_name := mInfo(i).Services(j).service_name;
               Info(i).Services(j).service_info := mInfo(i).Services(j).service_info;
               Info(i).Services(j).state        := mInfo(i).Services(j).state;
            END LOOP;
         END IF;
      END LOOP;
   END IF;
END;

PROCEDURE GetTechnicalFeasibility
(
   HouseID   IN  NUMBER,
   Apartment IN  VARCHAR2,
   Info      OUT line_info_table,
   TextInfo  OUT VARCHAR2
)
IS
mInfo irbis_is_core.line_info_table;
BEGIN
   irbis_is_core.GetTechnicalFeasibility(HouseID,
                                         Apartment,
                                         mInfo,
                                         TextInfo);
   IF mInfo.COUNT > 0 THEN
      FOR i IN mInfo.FIRST..mInfo.LAST LOOP
         Info(i).line_id := mInfo(i).line_id;
         IF mInfo(i).Services.COUNT > 0 THEN
            FOR j IN mInfo(i).Services.FIRST..mInfo(i).Services.LAST LOOP
               Info(i).Services(j).service_name := mInfo(i).Services(j).service_name;
               Info(i).Services(j).service_info := mInfo(i).Services(j).service_info;
               Info(i).Services(j).state        := mInfo(i).Services(j).state;
            END LOOP;
         END IF;
      END LOOP;
   END IF;
END;

-- Процедура определения технической возможности по номеру телефону.
-- Процедура идентична GetTechnicalFeasibility, но вместо адреса должен передаваться
--    номер телефона (в полном 10-значном виде), который используется для определения
--    адреса установки.
PROCEDURE GetTechnicalFeasibilityByPhone
(
   aPhone IN     VARCHAR2,
   aInfo     OUT line_info_table
)
IS
mInfo irbis_is_core.line_info_table;
BEGIN
   irbis_is_core.GetTechnicalFeasibilityByPhone(aPhone,
                                                mInfo);
   IF mInfo.COUNT > 0 THEN
      FOR i IN mInfo.FIRST..mInfo.LAST LOOP
         aInfo(i).line_id := mInfo(i).line_id;
         IF mInfo(i).Services.COUNT > 0 THEN
            FOR j IN mInfo(i).Services.FIRST..mInfo(i).Services.LAST LOOP
               aInfo(i).Services(j).service_name := mInfo(i).Services(j).service_name;
               aInfo(i).Services(j).service_info := mInfo(i).Services(j).service_info;
               aInfo(i).Services(j).state        := mInfo(i).Services(j).state;
            END LOOP;
         END IF;
      END LOOP;
   END IF;
END;

--Передача текущего значения поля комментарий в атрибут документа в системе тех. учета
PROCEDURE SetDocComment(
   RequestID  IN NUMBER,    -- идентификатор заявки в IRBiS
   DocComment IN VARCHAR2   -- комментарий из заявки Ирбис
)
IS
BEGIN
   irbis_is_core.SetDocComment(RequestID, DocComment);
END;

FUNCTION GetCurrentRequestStatus (
   RequestID IN NUMBER
) RETURN VARCHAR2
IS
BEGIN
   RETURN irbis_is_core.GetCurrentRequestStatus(RequestID);
END;

-- Моментальная проверка наличия свободной номерной емкости
PROCEDURE GetAvailableFreeNums
(
   Num         IN  VARCHAR2,   -- старый номер телефона
   Res         OUT VARCHAR2    -- результат, есть/нет свободная номерная емкость на АТС
)
IS
BEGIN
   irbis_is_core.GetAvailableFreeNums(Num, Res);
END;

-- процедура вызывается из Ирбис в случае
-- 1. когда после успешно обработанной техсправки на определение техвозможности
--    абонент отказался подписывать договор и оплачивать установку
-- 2. когда не удалось забронировать ресурсы и заявка осталась в подвешенном
--    состоянии - ожидать
-- т.е. создания наряда в итоге не произойдет и необходимо завершить работу с
-- документами и техкартой
PROCEDURE AnnulTC
(
   RequestID IN NUMBER
) IS
BEGIN
   irbis_is_core.AnnulTC(RequestID);
END AnnulTC;

-- процедура аналогично AnnulTC,
-- но для существующих услуг и отменяет изменения, сделанные в техкарте
PROCEDURE AnnulRevisionTC
(
   RequestID IN NUMBER
) IS
BEGIN
   irbis_is_core.AnnulRevisionTC(RequestID);
END AnnulRevisionTC;

-- Процедура запуска процесса установки СПД

-- Основные задачи:
--  1. Создание заявления и техсправки
--  2. Создание техкарты

-- Заявление, для создания необходимо вычислить:
--  1. вид
--  2. филиал
--  3. тип услуги
--  4. контрагент
--  5. абонент
--  6. адрес установки
--  7. пункт прохождения
--  8. номер документа
--  9. отдел, в котором заявление должно оказаться

-- Дополнительные действия
--  1. создание и заполнение атрибутов
--  2. направление в отдел

-- Техсправка, для создания необходимо вычислить:
--  1. вид дочернего документа
--  2. отдел, в котором техсправка должна оказаться
--  3. атрибуты
-- Дополнительные действия
--  1. направление в отдел

-- Техкарта, для создания необходимо вычислить:
--  1. Тип техкарты
--  2. Филиал
--  3. Номер техкарты
--  4. Адрес установки

-- Изменения
-- Person           Date        Comments
-- --------------   ----------  ------------------------------------------
-- Хузин А.Ф.       28.03.2022  Добавление БП - монтаж домофонной линии. Логика с типами подключения вынесена в таблицу rm_lst_conn_type для легкости сопровождения БП-ов.
--                              Убраны старые закомментированные части кода, которые давно не использовались и были заменены или не представляли сложной логики.

PROCEDURE CreateTC
(
    pRequestID          IN NUMBER,      -- идентификатор заявки в IRBiS
    pLineID             IN NUMBER,      -- идентификатор первичного ресурса (линии), на который следует произвести подключение
                                            -- если 0 - то организовать новую линию
                                            -- если -1 - значит технической возможности на данный момент нет, но заявку на подключение нужно сформировать
                                        -- если идентификатор ресурса не относится к передаваемому адресу подключения, значит это подключение на <соседскую> линию
    pEquipmentModel     IN VARCHAR2,    -- модель оборудования
    pConnectionType     IN VARCHAR2,    -- тип подключения (ADSL, SHDSL и т.п.)
    pAuthenticationType IN VARCHAR2,    -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
    pTarifficationType  IN VARCHAR2,    -- тип тарификации (NetFlow поip, SNMP и т.п.)
    pEquipmentNumber    IN VARCHAR2,    -- серийный номер оборудования
    MainParam           IN VARCHAR2     -- набор XML-данных, содержащий универсальные параметры
) IS
    CURSOR cGetTypeTK IS
        SELECT tk_type, dop_operation FROM rm_lst_conn_type
        WHERE LOWER(connection_type) = LOWER(pConnectionType)
            AND is_archive = 0;

    CURSOR cGetBaseResClass(cTK_Type rm_tk_type.tkt_id%TYPE) IS
        SELECT res_class_id FROM rm_lst_base_resource_tk
        WHERE tk_type_id = cTK_Type;

    CURSOR GetTelNumber(cLINE rm_tk_data.tkd_resource%TYPE) IS
        SELECT n.num_number,
            (SELECT rv.rbv_id
            FROM rm_rub_value rv, rm_rub_record r
            WHERE rv.rbv_entity = tk.tk_id
                AND rv.rbv_record = r.rbr_id
                AND rv.rbv_ecode = 9    -- сущность ТК
                AND r.rbr_rublst = 89) is_sec   -- рубрика "Охранная сигнализация"
        FROM rm_tk_data d, rm_numbers n, rm_tk tk
        WHERE d.tkd_tk IN ( SELECT td.tkd_tk
                            FROM rm_tk_data td, rm_tk t
                            WHERE td.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                                AND td.tkd_resource = cLINE -- ID ЛД
                                AND t.tk_id = td.tkd_tk
                                AND t.tk_status_id > RM_CONSTS.RM_TK_STATUS_ARCHIVE
                                AND td.tkd_isdel = 0
                                AND td.tkd_is_new_res = 0)
            AND d.tkd_res_class = 6
            AND d.tkd_is_new_res = 0
            AND d.tkd_resource = n.num_id
            AND tk.tk_id = d.tkd_tk
            AND tk.tk_status_id > 0;

    CURSOR GetTkResPorts(cTK_ID NUMBER, cLineID NUMBER, cBaseResClass NUMBER) IS
        SELECT cTK_ID AS TK_ID, dd.tkd_res_class AS Res_Class, dd.tkd_resource AS Res_ID, ROWNUM + 1 AS Pos
        FROM (  SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                FROM rm_tk_data d, rm_equip_port p
                WHERE d.tkd_tk IN (SELECT t2.tkd_tk
                                    FROM rm_tk_data t2
                                    WHERE t2.tkd_res_class = cBaseResClass
                                        AND t2.tkd_resource = cLineID
                                        AND t2.tkd_is_new_res = 0)
                    AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != 0
                    AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                    AND d.tkd_isdel = 0
                    AND d.tkd_is_new_res != 2
                    AND d.tkd_resource = p.prt_id
                    AND p.prt_type IN (42, 789, 792, 804)) dd;

    CURSOR GetTkResLD(cTK_ID NUMBER, cLineID NUMBER, cBaseResClass NUMBER) IS
        SELECT cTK_ID AS TK_ID, dd.tkd_res_class AS Res_Class, dd.tkd_resource AS Res_ID, ROWNUM + 1 AS Pos
        FROM (  SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                FROM rm_tk_data d, rm_tk t
                WHERE d.tkd_tk IN ( SELECT t2.tkd_tk FROM rm_tk_data t2
                                    WHERE t2.tkd_res_class = cBaseResClass
                                        AND t2.tkd_resource = cLineID
                                        AND t2.tkd_is_new_res = 0)
                    AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                    AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                    AND d.tkd_isdel = 0
                    AND d.tkd_is_new_res != 2
                    AND d.tkd_tk = t.tk_id
                    AND t.tk_status_id != RM_CONSTS.RM_TK_STATUS_ARCHIVE) dd;  -- действующие ТК

    mCuslType_ID    ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
    mSubtype_ID     ad_subtypes.id%TYPE;    -- вид родительского документа
    mTelzone_ID     ad_papers.telzone_id%TYPE;
    mAbonent_ID     ad_paper_content.abonent_id%TYPE;
    mContragent_ID  ad_paper_content.contragent_id%TYPE;
    mAddress_ID     ad_paper_content.address_id%TYPE;
    mDeclar_ID      ad_papers.id%TYPE;              -- id созданного документа
    mTS_ID          ad_papers.id%TYPE;              -- id техсправки
    mContent_ID     ad_paper_content.id%TYPE;       -- id содержания созданного документа
    mOtdel_ID       ad_papers.department_id%TYPE;   -- id отдела, в котором документ должен оказаться сразу после создания
    mTK_ID          rm_tk.tk_id%TYPE;               -- id созданной техкарты
    mTK_Number      rm_tk.tk_number%TYPE;           -- наименование (номер) техкарты
    vCreatable      NUMBER;                         -- признак возможности создания абонента
    mTK_type        rm_tk.tk_type%TYPE;             -- тип техкарты (зависит от устанавливаемой услуги)
    mHouseOnly      NUMBER; -- признак того, что для многоквартирного дома не была указана квартира
    mPrivateHouse   NUMBER; -- признак того, что дом является частным (без квартир)
    mAddress2_ID    ad_paper_content.address2_id%TYPE;
    mState          NUMBER;
    mMessage        VARCHAR2(2000);
    mSecondName     VARCHAR2(200);
    mFirstName      VARCHAR2(200);
    mPatrName       VARCHAR2(200);
    mOrgName        VARCHAR2(200);
    mTemp           NUMBER;
    mMarketingCategory  VARCHAR2(50);
    mPriority       NUMBER;
    mPriorityLong   VARCHAR2(200);
    mClientID       NUMBER; -- идентификатор клиента в IRBiS
    mClientName     VARCHAR2(300);  -- наименование клиента
    mClientTypeID   NUMBER; -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
    mAbonementID    NUMBER; -- идентификатор абонемента
    mHouseID        NUMBER; -- идентификатор дома, адрес подключения которого интересует
    mApartment      VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
    mContactPhone   VARCHAR2(200);  -- контактный телефон абонента
    mOperatorName   VARCHAR2(200);  -- ФИО оператора создавшего заявление
    mTariffPlanName VARCHAR2(200);
    mIsTel          NUMBER; -- признак того, что DSL устанавливается на существующую линию
    mAbonOtdelID    ad_papers.department_id%TYPE;
    mChildSubtype   ad_subtypes.id%TYPE;
    mTelNumber      rm_numbers.num_number%TYPE;
    mSec            VARCHAR2(100);
    mCategID        NUMBER;
    mBaseResClass   NUMBER;
    mResClass       NUMBER;
    mKeyParams      irbis_activity_log.PARAMETERS%TYPE;
    mChildSubtypeOld    ad_subtypes.id%TYPE;
    mConnectionReason   VARCHAR2(300);
    mMessm          VARCHAR2(300);
    mDeclarState    NUMBER;
    mTD_ID          NUMBER;
    mRMDocID        NUMBER;
    iTarifficationType  ad_paper_attr.value%type;
    mDopOperation   VARCHAR2(150);

BEGIN
    mKeyParams := 'LineID="'||TO_CHAR(pLineID)||
                 '", EquipmentModel="'||pEquipmentModel||
                 '", ConnectionType="'||pConnectionType||
                 '", AuthenticationType="'||pAuthenticationType||
                 '", TarifficationType="'||pTarifficationType||
                 '", EquipmentNumber="'||pEquipmentNumber||
                 '"';
    IRBIS_IS_CORE.write_irbis_activity_log('CreateTC',
                                            'pRequestID="'||TO_CHAR(pRequestID)||
                                            '", '||mKeyParams,
                                            pRequestID,
                                            MainParam);
    rm_security.setuser(IRBIS_USER_ID);
    m2_common.appuser_id := IRBIS_USER_ID;

    -- Разбор XML
    FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')) LOOP
        CASE x.param_name
            WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
            WHEN 'ContractHouseID'    THEN mHouseID         := TO_NUMBER(x.value);
            WHEN 'ContractAppartment' THEN mApartment       := x.value;
            WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
            WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
            WHEN 'ClientID'           THEN mClientID        := TO_NUMBER(x.value);
            WHEN 'ClientName'         THEN mClientName      := x.value;
            WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
            WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
            WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
            WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.value);
            WHEN 'ConnectionReason'   THEN mConnectionReason := x.value;
            WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.value;
            ELSE NULL;
        END CASE;
    END LOOP;

    mPriorityLong := IRBIS_IS_CORE.GetPriorityValue(mPriority);

    -- 0 = новая линия; > 0 = линия, на которую следует устанавливать; -1 = заявка на обследование
    -- TODO: передан pLineID = -1, то заявка на обследование
    IF pLineID IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Невозможно определить ресурс!');
    END IF;

    -- Определение филиала
    mTelzone_ID := IRBIS_IS_CORE.GetTelzoneByHouse(mHouseID);
    -- Отдел, в котором должно оказаться заявление
    mAbonOtdelID := IRBIS_IS_CORE.get_abonotdel_by_telzone(mTelzone_ID);
    -- Определения адреса
    -- mState не проверять, т.к. 1 - генерировать исключение
    mHouseOnly := 0;
    mPrivateHouse := 0;
    IRBIS_IS_CORE.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
    mAddress2_ID := NULL;

    -- Выбор класса полученного ресурса
    IF pLineID > 0 THEN
        SELECT COUNT(id), MAX(class) INTO mTemp, mResClass
        FROM (  SELECT l.lin_id AS id, '7' AS class FROM rm_cross_idline l WHERE l.lin_id = pLineID
                UNION ALL
                SELECT p.prt_id AS id, '2' AS class FROM rm_equip_port p WHERE p.prt_id = pLineID);
        -- Если есть и порт и ЛДН с таким ID, то смотрим ресурс по адресу
        IF mTemp > 1 THEN
            BEGIN
                mResClass := IRBIS_IS_CORE.getBaseResClass(mClientID, pLineID, mAddress_ID);
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLCODE = -20001 THEN
                        mResClass := NULL;
                    END IF;
            END;
        ELSE
            IRBIS_UTL.assertTrue((mTemp != 0), 'Ресурс с переданным идентификатором не найден!');
        END IF;
        -- Проверка нахождения ТК ресурса в неотработанном списке переключений
        IRBIS_IS_CORE.CheckTKSwitchList(pLineID, mResClass, mState, mMessage);
        IF mState <> 0 THEN
            RAISE_APPLICATION_ERROR(-20001, '<*-М2000: ' || mMessage || '-*>');
        END IF;
    END IF;

    -- << Начало <28.03.2022 Хузин А.Ф.> - Соотвествия перенесены в таблицу M_TTK.RM_LST_CONN_TYPE для облегчения сопровождения БП. Ниже вытаскиваются данные из таблицы
    /*
    -- Определение вида
    IF UPPER(pConnectionType) = 'WIMAX' THEN
        mTK_type      := tk_type_wimax;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    ELSIF UPPER(pConnectionType) in ('METROETHERNET (ДОМОВЫЕ СЕТИ)', 'METROETHERNET (ДОМОВЫЕ СЕТИ)1GBIT', 'METROETHERNET (ДОМОВЫЕ СЕТИ)10GBIT', 'METROETHERNETNANOBRIDGE', 'METROETHERNETSIKLU', 'METROETHERNETRADIO1GBIT', 'METROETHERNETRADIO1GBIT_1', 'METROETHERNETRADIO10MBIT', 'METROETHERNETRADIO10MBIT_1') THEN
        mTK_type      := tk_type_etth;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    ELSIF UPPER(pConnectionType) = 'ETHERNET' THEN
        mTK_type      := tk_type_ethernet;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    ELSIF UPPER(pConnectionType) IN ('ADSL', 'ADSL(B)', 'ANNEXB', 'SHDSL', 'RICHDSL') THEN
        mTK_type      := tk_type_dsl_new;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_LINE_DATA;
    ELSIF UPPER(pConnectionType) = 'GPON' THEN
        mTK_type      := tk_type_gpon;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    -- WiFi Sagem
    ELSIF UPPER(pConnectionType) = 'WIFIGUEST' THEN
        mTK_type      := tk_type_wifiguest;
        mBaseResClass := IRBIS_IS_CORE.getBaseResClass(mClientID, pLineID, mAddress_ID);
    ELSIF UPPER(pConnectionType) = 'WIFIADSL' THEN
        mTK_type      := tk_type_wifiadsl;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_LINE_DATA;
    ELSIF UPPER(pConnectionType) = 'WIFIMETROETHERNET' THEN
        mTK_type      := tk_type_wifimetroethernet;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    ELSIF UPPER(pConnectionType) = 'WIFISTREET' THEN
        mTK_type      := tk_type_wifistreet;
        mBaseResClass := RM_CONSTS.RM_RES_CLASS_EQUIP_PORT;
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Неизвестный тип подключения: ' || pConnectionType);
    END IF;
    */

    -- Опеределение типа ТК по типу подключения
    OPEN cGetTypeTK;
    FETCH cGetTypeTK INTO mTK_type, mDopOperation;
    IF cGetTypeTK%NOTFOUND THEN
        CLOSE cGetTypeTK;
        RAISE_APPLICATION_ERROR(-20011, 'Неизвестный тип подключения: '||pConnectionType);
    END IF;
    FETCH cGetTypeTK INTO mTK_type, mDopOperation;
    IF cGetTypeTK%FOUND THEN
        CLOSE cGetTypeTK;
        RAISE_APPLICATION_ERROR(-20012, 'Для типа подключения - '||pConnectionType||' соотвествует несколько типов техкарт!');
    END IF;
    CLOSE cGetTypeTK;
    -- Поиск базового ресурса для типа ТК
    IF mDopOperation IS NOT NULL THEN
        EXECUTE IMMEDIATE 'BEGIN :mBaseResClass := '||mDopOperation||'(:mClientID, :pLineID, :mAddress_ID) END;'
            USING IN OUT mBaseResClass, IN mClientID, IN pLineID, IN mAddress_ID;
    ELSE
        OPEN cGetBaseResClass(mTK_type);
        FETCH cGetBaseResClass INTO mBaseResClass;
        IF cGetBaseResClass%NOTFOUND THEN
            CLOSE cGetBaseResClass;
            RAISE_APPLICATION_ERROR(-20013, 'Для типа ТК - '||mTK_type||' не указан базовый ресурс!');
        END IF;
        FETCH cGetBaseResClass INTO mBaseResClass;
        IF cGetBaseResClass%FOUND THEN
            CLOSE cGetBaseResClass;
            RAISE_APPLICATION_ERROR(-20014, 'Для типа ТК - '||mTK_type||' указаны несколько базовых ресурсов!');
        END IF;
        CLOSE cGetBaseResClass;
    END IF;
    -- >> Конец <28.03.2022 Хузин А.Ф.>

    -- Проверка соответствия ресурса типу подключения
    IF (mResClass IS NOT NULL) AND (mBaseResClass != mResClass) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Класс ресурса -'||mResClass||' не соответствует создаваемому типу ТК - '||mTK_type||'. Убедитесь в соответствии типа подключения и типа базового ресурса для создаваемой ТК!');
    END IF;

    -- Проверка правильного выбора базового ресурса для WifiGuest.
    IF pLineID > 0 THEN
        mTemp := 0;
        IF (UPPER(pConnectionType) = 'WIFIGUEST') THEN
            SELECT NVL((SELECT tk_type FROM (SELECT t.tk_type
                                             FROM rm_tk t, rm_tk_data d
                                             WHERE t.tk_id = d.tkd_tk
                                                AND d.tkd_resource = pLineID
                                                AND d.tkd_res_class = mBaseResClass
                                                AND t.tk_status_id != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                                                AND t.tk_type IN (tk_type_iptv, tk_type_etth, tk_type_ethernet, tk_type_gpon, tk_type_dsl_old, tk_type_dsl_new, tk_type_sip)
                                                AND NOT EXISTS (SELECT 1
                                                                FROM rm_tk t1, rm_tk_data d1
                                                                WHERE t1.tk_id = d1.tkd_tk
                                                                    AND d1.tkd_resource = pLineID
                                                                    AND d1.tkd_res_class = mBaseResClass
                                                                    AND t1.tk_status_id != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                                                                    AND t1.tk_type IN (tk_type_wifiguest)))
                        WHERE ROWNUM < 2), NULL) INTO mTemp
            FROM dual;
            IRBIS_UTL.assertNotNull(mTemp, 'Неправильно выбран ресурс!');
        END IF;
    END IF;

    -- Проверка установки ДРС на существующий ресурс, который не занимает другая ТК ДРС.
    IF pLineID > 0 and mTK_type IN (tk_type_etth) THEN
        SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type)||'-' || t.tk_number||' (id = ' || TO_CHAR(t.tk_id)||')'
                    FROM rm_tk t, rm_tk_data d
                    WHERE t.tk_id = d.tkd_tk
                        AND d.tkd_resource = pLineID
                        AND d.tkd_res_class = mBaseResClass
                        AND t.tk_status_id != 0
                        AND t.tk_type = mTK_type
                        AND ROWNUM < 2), NULL) INTO mMessm
        FROM dual;
        IRBIS_UTL.assertTrue((mMessm IS NULL),'Данный ресурс уже содержится в ТК '||mMessm||'!');
    END IF;

    -- Осуществлялись ли попытки создания документов ранее
    -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
    mDeclar_ID := IRBIS_IS_CORE.is_parent_created(pRequestID);
    -- Проверка что заявление не закрыто
    SELECT COUNT(1) INTO mDeclarState FROM ad_papers WHERE id = mDeclar_ID AND state_id = 'C';

    -- Если уже производились попытки создания цепочки, то родительский документ не создается во второй раз
    IF (mDeclar_ID IS NOT NULL AND mDeclarState != 1) THEN
        --checkKeyParams('CreateTC', mDeclar_ID, mKeyParams);   -- проверка, не поменялись ли ключевые параметры
        IRBIS_IS_CORE.get_created_paper_data(mDeclar_ID,
                                            mCategID,
                                            mSubtype_ID,
                                            mContent_ID,
                                            mAddress_ID,
                                            mAddress2_ID);
        mChildSubtype := IRBIS_UTL.defineSubtype('BP="3";'||
                                                'TKTYPE="'||TO_CHAR(mTK_type)||'";'||
                                                'OBJECT="T";'||
                                                'CLIENTTYPE="'||TO_CHAR(mClientTypeID)||'";'||
                                                'AUTHENTICATION="'||UPPER(pAuthenticationType)||'";'||
                                                'LINE="'||TO_CHAR(SIGN(pLineID))||'";'||
                                                'CONNECTION="'||UPPER(pConnectionType)||'"');
        IF (mChildSubtype IS NULL) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен вид техсправки');
        END IF;

        SELECT subtype_id INTO mChildSubtypeOld FROM ad_papers
        WHERE parent_id = mDeclar_ID
            AND object_code = 'T'
            AND ROWNUM < 2;
        IF (mChildSubtype != mChildSubtypeOld) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Изменились ключевые параметры, создание документа невозможно!');
        END IF;
    -- Первая попытка создания документа
    ELSE
        mSubtype_ID := IRBIS_UTL.defineSubtype('BP="3";'||
                                               'TKTYPE="'||TO_CHAR(mTK_type)||'";'||
                                               'OBJECT="D";'||
                                               'CLIENTTYPE="'||TO_CHAR(mClientTypeID)||'";'||
                                               'AUTHENTICATION="'||UPPER(pAuthenticationType)||'";'||
                                               'LINE="'||TO_CHAR(SIGN(pLineID))||'";'||
                                               'CONNECTION="'||UPPER(pConnectionType)||'"');
        IRBIS_UTL.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

        mChildSubtype := IRBIS_UTL.defineSubtype('BP="3";'||
                                                'TKTYPE="'||TO_CHAR(mTK_type)||'";'||
                                                'OBJECT="T";'||
                                                'CLIENTTYPE="'||TO_CHAR(mClientTypeID)||'";'||
                                                'AUTHENTICATION="'||UPPER(pAuthenticationType)||'";'||
                                                'LINE="'||TO_CHAR(SIGN(pLineID))||'";'||
                                                'CONNECTION="'||UPPER(pConnectionType)||'"');
        IRBIS_UTL.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

        SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
        IF mCategID = 7 THEN
            SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_INTERNET'), NULL) INTO mCuslType_ID FROM dual;
            ad_utils.ad_create_paper_cat7_single(mDeclar_ID, mContent_ID, mSubtype_ID,
                                                SYSDATE, '',
                                                mTelzone_ID, irbis_user_id, mCuslType_ID,
                                                mClientID, 'IRBIS_CONTRAGENT',
                                                mAbonent_ID, 'IRBIS_ABONENT',
                                                mAddress_ID, 'M2000_ADDRESS',
                                                mAddress2_ID, 'M2000_ADDRESS',
                                                0, NULL, NULL, NULL, NULL, NULL);
            -- Направление
            -- Корректировка отдела-создателя с учетом вида работ
            mAbonOtdelID := IRBIS_UTL.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
            IRBIS_UTL.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
            IRBIS_IS_CORE.move_created_paper(mDeclar_ID, mAbonOtdelID);
            UPDATE ad_paper_extended
            SET usl_id = mAbonementID, usl_card_id = mCuslType_ID
            WHERE id = mContent_ID;
        ELSE
            -- Определение типа услуги
            -- Тип услуги, необходимая формальность
            IF (pLineID = 0) OR (pLineID = -1) THEN
                mCuslType_ID := 8790842;    -- тип услуги
            ELSE
                mCuslType_ID := 2101009;    -- телефон основновной с СПД (old = 2103311);
            END IF;

            -- Контрагент, абонент
            IRBIS_IS_CORE.get_client_name(mClientTypeID,mClientName, mSecondName, mFirstName, mPatrName, mOrgName);
            -- Для устанавливаемых услуг допускается создание контрагента и лицевого счета
            vCreatable := 1;
            IRBIS_IS_CORE.GetAbonentID(mSecondName,
                                        mFirstName,
                                        mPatrName,
                                        mOrgName,
                                        mClientID,
                                        mAddress_ID,
                                        mTelzone_ID,
                                        mClientTypeID - 1,
                                        1,
                                        mAbonent_ID,
                                        mContragent_ID,
                                        mState,
                                        mMessage,
                                        1);
            IF mState <> 0 THEN
                RAISE_APPLICATION_ERROR(-20001, mMessage);
            END IF;

            -- Создание заявления
            ad_queue.ad_create_single_request(mDeclar_ID,
                                                mContent_ID,
                                                mSubtype_ID,    -- вид документа
                                                SYSDATE,        -- дата создания документа
                                                '',             -- примечание к документу
                                                mTelzone_ID,    -- филиал
                                                irbis_user_id,  -- пользователь
                                                mCuslType_ID,   -- тип услуги
                                                mContragent_ID, -- ID контрагента
                                                mAddress_ID,    -- адрес установки
                                                mAbonent_ID,    -- ID лицевого счета
                                                mAddress2_ID,   -- дополнительный адрес
                                                NULL,           -- id кросса
                                                NULL,           -- id шкафа
                                                NULL,           -- дата постановки в очередь
                                                NULL,           -- резолюция (очередь)
                                                NULL,           -- льгота очередника
                                                NULL,           -- примечание к постановке в очередь
                                                0,              -- action code (0=nothing,1=hold,2=hold,...)
                                                NULL,           -- резолюция
                                                NULL,           -- отдел
                                                NULL,           -- текущий пункт прохождения
                                                NULL,           -- новый пункт прохождения
                                                NULL);          -- номер документа

            -- Направление
            -- Корректировка отдела-создателя с учетом вида работ
            mAbonOtdelID := IRBIS_UTL.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
            IRBIS_UTL.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
            IRBIS_IS_CORE.move_created_paper(mDeclar_ID, mAbonOtdelID);
            mTelNumber := '';
            mSec := '';
            IF pLineID > 0 THEN
                OPEN GetTelNumber(pLineID);
                FETCH GetTelNumber INTO mTelNumber, mIsTel;
                IF (mIsTel IS NOT NULL) AND (mIsTel > 0) THEN
                    mSec := 'Есть';
                ELSE
                    mSec := 'Отсутствует';
                END IF;
                CLOSE GetTelNumber;
            END IF;
        END IF;

        SELECT DECODE(pTarifficationType, 'RADIUS accounting', 1, 'NetFlow по ip', 2, 'SNMP', 3, pTarifficationType) INTO iTarifficationType FROM dual;
        IRBIS_IS_CORE.create_paper_attrs(mDeclar_ID);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'CUSL_NUM', mTelNumber, mTelNumber);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'O_SIGNAL', '0', mSec);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', pAuthenticationType, pAuthenticationType);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', pConnectionType, pConnectionType);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'TARIFFICATION_TYPE', iTarifficationType, pTarifficationType);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(pRequestID), TO_CHAR(pRequestID));
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(pEquipmentNumber), pEquipmentNumber);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'BASE_RES_CLASS', mBaseResClass, pLineID);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'CONNECTION_REASON', mConnectionReason, mConnectionReason);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'OLD_TP', mTariffPlanName, mTariffPlanName);
        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'MODEL_EQUIP', pEquipmentModel, pEquipmentModel);

        -- Привязка ID заявки Ирбис к заявлению
        IRBIS_IS_CORE.attach_paper_to_request(mDeclar_ID, pRequestID, 3, MainParam);
    END IF;

    -- Создание техсправки на основании заявления
    IRBIS_IS_CORE.create_tc_by_request(mTS_ID,
                                        mChildSubtype,
                                        mDeclar_ID,
                                        mSubtype_ID,
                                        pRequestID,
                                        mOtdel_ID,
                                        mAbonOtdelID,
                                        0);

    IRBIS_IS_CORE.update_paper_attr(mTS_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

    -- Создание техкарты
    -- Наименование техкарты должно первоначально совпадать с названием документа
    SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;
    -- Создание техкарты
    rm_doc.ad_create_tk(mTK_ID,         -- ID тех карты
                        mTK_type,       -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                        mTelzone_ID,    -- филиал
                        irbis_user_id,  -- пользователь
                        mTK_Number,     -- наименование
                        SYSDATE,        -- дата создания тех карты
                        '',             -- примечание
                        mAddress_ID,    -- основной адрес установки
                        mAddress2_ID,   -- дополнительный адрес установки
                        1,              -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                        NULL);
    -- Добавление информации об операторе, создавшем ТК
    IRBIS_IS_CORE.addTKStateUser(mTK_ID, mOperatorName);
    -- Добавление ссылки на абонемент Ирбис в техкарте
    IF (mAbonementID IS NOT NULL) THEN
        mTemp := RM_TK_PKG.InsertServiceData(xTK_ID   => mTK_ID,
                                            xExt_ID  => 0,
                                            xSvc_ID  => mAbonementID,
                                            xSvcCode => 'IRBIS',
                                            xSvcName => 'Абонемент IRBiS');
    END IF;

    -- << <16.11.2015 Точкасова М.А.> - Временная проверка
    /*
    IF UPPER(pEquipmentModel)!='БЕЗ МОДЕМА' THEN
        SELECT NVL((SELECT e.equ_id
                    FROM rm_equipment e
                    WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t
                            WHERE t.rty_id = e.equ_type) = 1
                                AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 1909 AND v.rvl_value = UPPER(pEquipmentNumber)) --serial
                        --AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 1916 AND LOWER(v.rvl_value) = LOWER(pEquipmentModel))  --model
                    ), NULL) INTO mTemp FROM dual;
        IRBIS_UTL.assertNotNull(mTemp, 'Не удалось найти оборудование с серийным номером : ' || pEquipmentNumber);
        -- Проверка незанятости оборудования на других ТК с другим адресом
        IF rm_pkg.GetResState(mTemp, 1) != 0 THEN
            SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type)||'-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                        FROM rm_tk_data d, rm_tk t, rm_tk_address addr
                        WHERE d.tkd_resource = mTemp
                            AND d.tkd_res_class = 1
                            AND d.tkd_tk = t.tk_id
                            AND t.tk_status_id != 0
                            AND addr.adr_tk = t.tk_id
                            AND addr.adr_id != mAddress_ID
                            AND rownum < 2), NULL) INTO mMessm FROM dual;
            IRBIS_UTL.assertTrue((mMessm IS NULL), 'Устройство занято по другому адресу, закреплено за ТК '||mMessm);
        END IF;
    END IF;
    */
    -- >> <16.11.2015 Точкасова М.А.> - Временная проверка

    -- WiFi... - добавить модем в ТК
    IF (UPPER(pEquipmentModel) != 'БЕЗ МОДЕМА' AND mClientTypeID = 1) OR UPPER(pConnectionType) IN ('WIFIGUEST', 'WIFIADSL', 'WIFIMETROETHERNET') THEN
        SELECT NVL((SELECT e.equ_id FROM rm_equipment e
                    WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1
                        AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 1909 AND v.rvl_value = UPPER(pEquipmentNumber)) --serial
                        --AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 1916 AND LOWER(v.rvl_value) = LOWER(pEquipmentModel))  --model
                    ), NULL) INTO mTemp
        FROM dual;
        IRBIS_UTL.assertNotNull(mTemp, 'Не удалось найти оборудование с серийным номером : '||pEquipmentNumber);

        IRBIS_IS_CORE.update_paper_attr(mDeclar_ID, 'NEW_EQUIP_ID', mTemp, mTemp);
        mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
        -- Добавление оборудования в ТК
        AddCPEtoTK(mTK_ID, mTemp, NULL, mRMDocID); --mCreateChangeModemTS
    END IF;

    -- При установке на существующую линию в техсправке сразу должны быть ЛД
    IF pLineID > 0 THEN
        mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
        mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                        xClass_ID => mBaseResClass,
                                                        xRes_ID   => pLineID,
                                                        xDoc_ID   => mRMDocID,
                                                        xUser_ID  => irbis_user_id);

        -- Если установка xDSL на существующую линию (например, IPTV), также копировать порты СПД
        IF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_LINE_DATA) AND (UPPER(pConnectionType) != 'WIFIGUEST') THEN
            FOR vData IN GetTkResPorts(mTK_ID, pLineID, mBaseResClass) LOOP
                mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => vData.TK_ID,
                                                                xClass_ID => vData.Res_Class,
                                                                xRes_ID   => vData.Res_ID,
                                                                xPos      => vData.Pos,
                                                                xDoc_ID   => mRMDocID,
                                                                xUser_ID  => irbis_user_id);
            END LOOP;
        END IF;

        -- Если установка СПД на существующую линию, также копировать ЛД
        IF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT) AND (UPPER(pConnectionType) != 'WIFIGUEST') THEN
            FOR vData IN GetTkResLD(mTK_ID, pLineID, mBaseResClass) LOOP
                mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => vData.TK_ID,
                                                                xClass_ID => vData.Res_Class,
                                                                xRes_ID   => vData.Res_ID,
                                                                xPos      => vData.Pos,
                                                                xDoc_ID   => mRMDocID,
                                                                xUser_ID  => irbis_user_id);
            END LOOP;
        END IF;

        -- WiFi-Sagem
        IF UPPER(pConnectionType) = 'WIFIGUEST' THEN
            FOR vData IN GetTkResLD(mTK_ID, pLineID, mBaseResClass) LOOP
                mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => vData.TK_ID,
                                                                xClass_ID => vData.Res_Class,
                                                                xRes_ID   => vData.Res_ID,
                                                                xPos      => vData.Pos,
                                                                xDoc_ID   => mRMDocID,
                                                                xUser_ID  => irbis_user_id);
            END LOOP;
        END IF;

    END IF;

    -- Сохранение созданной техкарты в документах - заявке и техсправке.
    IRBIS_IS_CORE.attach_tk_to_paper(mTK_ID, mDeclar_ID);
    IRBIS_IS_CORE.attach_tk_to_paper(mTK_ID, mTS_ID);
    -- Логирование данных по ТС
    IRBIS_IS_CORE.write_ts_log(mCuslType_ID,
                                mTelzone_ID,
                                mSubtype_ID,  -- сохраняется вид документа
                                mClientName||'; id = '||TO_CHAR(mClientID),
                                mAddress_ID,
                                mAddress2_ID,
                                mSecondName||' '||mFirstName||' '||mPatrName,
                                mOrgName,
                                pRequestID,
                                NULL,
                                mTK_ID);
    -- Направление документа в следующий отдел.
    IRBIS_UTL.sendPaperNextDepartment(mTS_ID);
END CreateTC;


-- Установка телефонии
PROCEDURE CreatePSTNTC
(
   RequestID         IN NUMBER,    -- идентификатор заявки в IRBiS
   LineID            IN NUMBER,    -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение, если null - то организовать новую линию
   PhoneNumber       IN VARCHAR2,  -- опциональный параметр, если оператор вручную назначает номер телефона для тех.справки (например он был забронирован)
   PhoneCategory     IN NUMBER,    -- категория оператора дальней связи
   CallBarringState  IN NUMBER,    -- статус исходящей связи
   ConnectionType    IN VARCHAR2,  -- тип подключения (voip, аналог и т.п.)
   MainParam         IN VARCHAR2   -- набор XML-данных, содержащий универсальные параметры
) IS

   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   vCreatable     NUMBER;                       -- признак возможности создания абонента
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   --mDocType       ad_subtypes.type_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;

   mAbonOtdelID   ad_papers.department_id%TYPE;
   --mIsTel         NUMBER;  -- признак того, что тел. устанавливается на существующую линию (что пока не может быть)
   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mState         NUMBER;
   mMessage       VARCHAR2(2000);
   mSecondName    VARCHAR2(200);
   mFirstName     VARCHAR2(200);
   mPatrName      VARCHAR2(200);
   mOrgName       VARCHAR2(200);
   mTemp          NUMBER;

   mClientID       NUMBER;    -- идентификатор клиента в IRBiS
   mClientName     VARCHAR2(300);  -- наименование клиента
   mClientTypeID   NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
   mAbonementID    NUMBER;    -- идентификатор абонемента
   --mSpecClient     NUMBER;    -- признак спец.абонента (0 - обычный абонент, 1 - спец.абонент)
   mHouseID        NUMBER;    -- идентификатор дома, адрес подключения которого интересует
   mApartment      VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
   mContactPhone   VARCHAR2(200);  -- контактный телефон абонента
   mOperatorName   VARCHAR2(200);   -- ФИО оператора создавшего заявление
   mTkd_id          NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);
   mConnectionReason  VARCHAR2(300);

   CURSOR CheckResAtAdr(aADR NUMBER, aCLASS NUMBER, aRES NUMBER) IS
      SELECT COUNT(d.tkd_id)
        FROM rm_tk_address a, rm_tk_data d
       WHERE a.adr_id        = aADR
         AND a.adr_tk        = d.tkd_tk
         AND d.tkd_res_class = aCLASS
         AND d.tkd_resource  = aRES;

   mVZ            VARCHAR2(5);
   mMG            VARCHAR2(5);
   mMN            VARCHAR2(5);

   mAttrValue     ad_paper_attr.value%TYPE;
   mAttrValuLong  ad_paper_attr.value_long%TYPE;

   mParentExists  NUMBER;
   mCategID       NUMBER;
   mProc          NUMBER;
   mBaseResClass  NUMBER;
   mKeyParams     irbis_activity_log.parameters%TYPE;

   mTD_ID         number;
   mRMDocID       number;
BEGIN
   mKeyParams := 'LineID="' || TO_CHAR(LineID) ||
                 '", PhoneCategory="' || PhoneCategory ||
                 '", CallBarringState="' || CallBarringState ||
                 '", ConnectionType="' || ConnectionType ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreatePSTNTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || 'PhoneNumber="' || PhoneNumber ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mApartment   := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
         WHEN 'ClientName'         THEN mClientName    := x.value;
         WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
         WHEN 'AccountID'          THEN mAbonent_ID       := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   -- 0 = новая линия, >0 = линия, на которую следует устанавливать, -1 = заявка на обследование
   IF LineID IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, '<*-М2000: Невозможно определить линию!-*>');
   END IF;

   -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
   -- (mState не проверять, т.к. 1=генерировать исключение)
   mHouseOnly    := 0;
   mPrivateHouse := 0;
   irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
   mAddress2_ID  := NULL;

   mBaseResClass := 7;
   -- Если был передан идентификатор первичного ресурса, проверить его существование
   IF LineID > 0 THEN
      -- проверка существования указанной линии на данном адресе
      OPEN CheckResAtAdr(mAddress_ID, 7, LineID); FETCH CheckResAtAdr INTO mTemp; CLOSE CheckResAtAdr;
      IF mTemp = 0 THEN
         -- Установка sip и voip телефона может быть осуществлена на действующее подключение СПД
         IF (UPPER(SUBSTR(ConnectionType, 1, 3)) = 'SIP') OR
            (UPPER(SUBSTR(ConnectionType, 1, 4)) = 'VOIP') THEN
            -- проверка существования указанного порта на данном адресе
            OPEN CheckResAtAdr(mAddress_ID, 2, LineID); FETCH CheckResAtAdr INTO mTemp; CLOSE CheckResAtAdr;
            IF mTemp = 0 THEN
               RAISE_APPLICATION_ERROR(-20001, 'Порт с переданным идентификатором не найден!');
            ELSE
               mBaseResClass := 2;
            END IF;
         ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Линия с переданным идентификатором не найдена!');
         END IF;
      END IF;
   END IF;

   IF LineID > 0 THEN
      irbis_is_core.CheckTKSwitchList(LineID, mBaseResClass, mState, mMessage);
      IF mState <> 0 THEN
         RAISE_APPLICATION_ERROR(-20001, '<*-М2000: ' || mMessage || '-*>');
      END IF;
   END IF;

   irbis_utl.assertTrue( UPPER(SUBSTR(irbis_utl.getIrbisPhoneCategoryName(PhoneCategory), 1, 4)) != 'ТЕСТ',
                         'Необходимо выбрать другую категорию телефона');

   -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА ------------------------------------------------------
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mParentExists := 0;
   SELECT COUNT(id) INTO mParentExists
     FROM ad_papers p
    WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
      AND p.object_code = 'D';

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mParentExists > 0) THEN
      SELECT p.id INTO mDeclar_ID FROM ad_papers p
       WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
         AND p.object_code = 'D'
         AND ROWNUM < 2;

--      checkKeyParams('CreatePSTNTC', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      --mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'T');
      mProc := irbis_is_core.get_proc_by_paper(mDeclar_ID);
      IF mProc = 1 THEN
         mTK_type := tk_type_tel;
      ELSIF mProc = 17 THEN
         mTK_type := tk_type_sip;
      ELSIF mProc = 20 THEN
         mTK_type := tk_type_voip;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить бизнес-процесс');
      END IF;
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="T";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      IF (mChildSubtype IS NULL) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не определен вид техсправки');
      END IF;

   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- определение бизнес-процесса
      IF UPPER(TRIM(ConnectionType)) IN ('TEL','ISDN','ISDN_DOP', 'UPATC', 'SERINIITEL') THEN
         mProc    := 1;
         mTK_type := tk_type_tel;
      ELSIF UPPER(ConnectionType) IN ('SIP', 'VOIPSIP') THEN
         mProc    := 17;
         mTK_type := tk_type_sip;
      ELSIF UPPER(ConnectionType) = 'VOIP' THEN
         mProc    := 20;
         mTK_type := tk_type_voip;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Неизвестный тип подключения');
      END IF;

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      -- установка телефона
      /*IF mProc = 1 THEN
         get_vid_doc(mTelzone_ID, mClientTypeID, mDocType, mIsTel, mSubtype_ID, mTK_type, mChildSubtype, 'T', LineID, 1);
      -- установка SIP
      ELSIF mProc = 17 THEN
         mSubtype_ID   := irbis_is_core.get_parent_subtype(mTelzone_ID, 17, tk_type_sip); -- филиал, БП, тип ТК
         mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'T');
      -- установка VoIP
      ELSIF mProc = 20 THEN
         mSubtype_ID   := irbis_is_core.get_parent_subtype(mTelzone_ID, 20, tk_type_voip); -- филиал, БП, тип ТК
         mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'T');
      END IF;*/

      mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="D";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="T";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      IF (mSubtype_ID IS NULL) OR (mChildSubtype IS NULL) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не определен вид документа');
      END IF;

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_TEL'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         --UPDATE ad_papers SET department_id = mAbonOtdelID WHERE id = mDeclar_ID;
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
      ELSE
         -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
         -- тип услуги, необходимая формальность
         IF (LineID = 0) OR (LineID = -1) THEN
            mCuslType_ID := 1;
         ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается.');
         END IF;

         -- КОНТРАГЕНТ, АБОНЕНТ ------------------------------------------------------
         irbis_is_core.get_client_name(mClientTypeID,mClientName, mSecondName, mFirstName, mPatrName, mOrgName);

         -- для устанавливаемых услуг допускается создание контрагента и лицевого счета
         vCreatable := 1;
         irbis_is_core.GetAbonentID(mSecondName,
                      mFirstName,
                      mPatrName,
                      mOrgName,
                      mClientID,
                      mAddress_ID,
                      mTelzone_ID,
                      mClientTypeID - 1,
                      1,
                      mAbonent_ID,
                      mContragent_ID,
                      mState,
                      mMessage,
                      1);
         IF mState <> 0 THEN
            RAISE_APPLICATION_ERROR(-20001, mMessage);
         END IF;

         -- СОЗДАНИЕ ЗАЯВЛЕНИЯ -------------------------------------------------------
         ad_queue.ad_create_single_request(mDeclar_ID,
                                           mContent_ID,
                                           mSubtype_ID,   -- вид документа
                                           SYSDATE,       -- дата создания документа
                                           '',            -- примечание к документу
                                           mTelzone_ID,   -- филиал
                                           irbis_user_id, -- пользователь
                                           mCuslType_ID,  -- тип услуги
                                           mContragent_ID,-- ID контрагента
                                           mAddress_ID,   -- адрес установки
                                           mAbonent_ID,   -- ID лицевого счета
                                           mAddress2_ID,  -- дополнительный адрес
                                           NULL,          -- id кросса
                                           NULL,          -- id шкафа
                                           NULL,          -- дата постановки в очередь
                                           NULL,          -- резолюция (очередь)
                                           NULL,          -- льгота очередника
                                           NULL,          -- примечание к постановке в очередь
                                           0,             -- action code (0=nothing,1=hold,2=hold,...)
                                           NULL,          -- резолюция
                                           NULL,          -- отдел
                                           NULL,          -- текущий пункт прохождения
                                           NULL,          -- новый пункт прохождения
                                           NULL);         -- номер документа
      END IF;

      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      --  ВЗ,МГ,МН
      mVZ := 'Да';
      mMG := 'Да';
      mMN := 'Да';
      CASE CallBarringState
         WHEN 2 THEN
            mMN := 'Нет';
         WHEN 3 THEN
            mMN := 'Нет';
            mMG := 'Нет';
         WHEN 10 THEN
            mMN := 'Нет';
            mMG := 'Нет';
            mVZ := 'Нет';
         ELSE
            mVZ := 'Да';
            mMG := 'Да';
            mMN := 'Да';
      END CASE;

      -- Заполнение Атрибутов
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTRAAREAL', mVZ, mVZ);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTERCITY', mMG, mMG);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTERNATIONAL', mMN, mMN);

      mAttrValue := TO_CHAR(PhoneCategory);
      mAttrValuLong := irbis_utl.getIrbisPhoneCategoryName(PhoneCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PHONECATEGORY', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CATEG_AON', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_REASON', mConnectionReason, mConnectionReason);

      mAttrValue := TO_CHAR(CallBarringState);
      CASE CallBarringState
         WHEN 1 THEN
            mAttrValuLong := 'Открыто все - ВЗ,МГ,МН';
         WHEN 2 THEN
            mAttrValuLong := 'Закрыта МН связь';
         WHEN 3 THEN
            mAttrValuLong := 'Закрыты выходы на МГ,МН связь';
         WHEN 10 THEN
            mAttrValuLong := 'Закрыто все - ВЗ,МГ,МН';
         ELSE
            mAttrValuLong := '';
      END CASE;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CALLBARRINGSTATE', mAttrValue, mAttrValuLong);

      IF (LineID IS NULL) OR (LineID < 1) THEN
         mAttrValue    := 1;
         mAttrValuLong := 'На новую линию';
      ELSE
         mAttrValue    := 2;
         mAttrValuLong := 'На существующую';
      END IF;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_OPERATION', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);

      mAttrValue := UPPER(TO_CHAR(ConnectionType));
      CASE UPPER(TRIM(ConnectionType))
         WHEN 'TEL' THEN
            mAttrValuLong := 'Телефон';
         WHEN 'ISDN' THEN
            mAttrValuLong := 'Tелефон ISDN';
         WHEN 'ISDN_DOP' THEN
            mAttrValuLong := 'Дополнительный телефон ISDN';
         WHEN 'SIP' THEN
            mAttrValuLong := 'SIP телефон';
         WHEN 'VOIP' THEN
            mAttrValuLong := 'VoIP телефон';
         WHEN 'UPATC' THEN
            mAttrValuLong := 'Телефон УПАТС';
         ELSE
            mAttrValuLong := '';
      END CASE;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE',  mAttrValue, mAttrValuLong);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
   END IF;

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0);

   -- установка назначенного номера оператором (восстановление)
   irbis_is_core.update_paper_attr(mTS_ID, 'CUSL_NUM', PhoneNumber, PhoneNumber);
   irbis_is_core.update_paper_attr(mTS_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   IF (mAbonementID IS NOT NULL) THEN
     mTemp := RM_TK_PKG.InsertServiceData(xTK_ID   => mTK_ID,
                                          xExt_ID  => 0,
                                          xSvc_ID  => mAbonementID,
                                          xSvcCode => 'IRBIS',
                                          xSvcName => 'Абонемент IRBiS');
      /*INSERT INTO rm_tk_usl (usl_rec, usl_tk, usl_id, usl_idext, usl_strcod, usl_name)
       VALUES (rm_gen_tk_usl.NEXTVAL, mTK_ID, mAbonementID, 0, 'IRBIS', 'Абонемент IRBiS');*/
   END IF;

   mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
   -- при установке на существующую линию в техсправке сразу должны быть ЛД
   IF LineID > 0 THEN
     mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                    xClass_ID => mBaseResClass,
                                                    xRes_ID   => LineID,
                                                    xDoc_ID   => mRMDocID,
                                                    xUser_ID  => irbis_user_id);
     if (mTD_ID is null) then null; end if;

      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id, tkd_algo_switch)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mBaseResClass, LineID, 0, 0, 0, NULL, NULL)
         RETURNING tkd_id INTO mTkd_id;
         irbis_utl.addTKHisData(mTkd_id, irbis_user_id); --сохранение истории ТК*/

      -- При установке SIP
      IF (UPPER(ConnectionType) = 'SIP') THEN
         --  на существующий xDSL выполнить копирование портов СПД
         IF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_LINE_DATA) THEN
           FOR v1 IN (SELECT mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 npp
                        FROM (SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                                FROM rm_tk_data d, rm_equip_port p
                               WHERE d.tkd_tk IN (SELECT d2.tkd_tk     -- ТК, имеющая в ресурсах данную линию
                                                    FROM rm_tk_data d2
                                                   WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                                                     AND d2.tkd_resource = LineID
                                                     AND d2.tkd_is_new_res in (RM_CONSTS.RM_TK_DATA_WORK_NONE, RM_CONSTS.RM_TK_DATA_WORK_INTO))
                                 AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != 0
                                 AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                                 AND d.tkd_isdel = 0
                                 AND d.tkd_is_new_res in (RM_CONSTS.RM_TK_DATA_WORK_NONE, RM_CONSTS.RM_TK_DATA_WORK_INTO)
                                 AND d.tkd_resource = p.prt_id
                                 AND p.prt_type IN (42, 789, 792, 804) ) dd)
           LOOP
             mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                            xClass_ID => v1.tkd_res_class,
                                                            xRes_ID   => v1.tkd_resource,
                                                            xPos      => v1.npp,
                                                            xDoc_ID   => mRMDocID,
                                                            xUser_ID  => irbis_user_id);
           END LOOP;

          /*  INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                    tkd_isdel, tkd_is_new_res, tkd_parent_id)
            SELECT rm_gen_tk_data.nextval, mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 ,
                   0, 0, NULL
              FROM (
               SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                 FROM rm_tk_data d, rm_equip_port p
                WHERE d.tkd_tk IN (SELECT d2.tkd_tk     -- ТК, имеющая в ресурсах данную линию
                                     FROM rm_tk_data d2
                                    WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                                      AND d2.tkd_resource = LineID
                                      AND d2.tkd_is_new_res in (RM_TK_DATA_WORK_NONE, RM_TK_DATA_WORK_INTO))
                  AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_TK_STATUS_ARCHIVE
                  AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                  AND d.tkd_isdel = 0
                  AND d.tkd_is_new_res in (RM_TK_DATA_WORK_NONE, RM_TK_DATA_WORK_INTO)
                  AND d.tkd_resource = p.prt_id
                  AND p.prt_type IN (42, 789, 792, 804) ) dd;

--                irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

         -- на GPON (или Домовые сети), выполнить копирование портов из ТК GPON (или Домовые сети)
         ELSIF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT) THEN
           FOR v1 IN (SELECT mTkd_id, mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 npp
              FROM (
               SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                 FROM rm_tk_data d
                -- действующая ТК типа GPON по данному адресу, имеющая в ресурсах данный порт
                WHERE d.tkd_tk IN (SELECT d2.tkd_tk
                                     FROM rm_tk_data d2, rm_tk t2
                                    WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                                      AND d2.tkd_resource = LineID
                                      AND d2.tkd_is_new_res in (RM_CONSTS.RM_TK_DATA_WORK_NONE, RM_CONSTS.RM_TK_DATA_WORK_INTO)
                                      AND t2.tk_id = d2.tkd_tk
                                      AND t2.tk_type IN (tk_type_gpon, tk_type_etth)
                                      AND t2.tk_status_id != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                                      AND EXISTS (SELECT 1 FROM rm_tk_address WHERE adr_tk = d2.tkd_tk AND adr_id = mAddress_ID))
                  AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                  AND d.tkd_res_class IN (RM_CONSTS.RM_RES_CLASS_EQUIP_PORT, RM_CONSTS.RM_RES_CLASS_LINE_DATA)
                  AND d.tkd_resource != LineID  -- уже был добавлен в ТК
                  AND d.tkd_isdel = 0
                  AND d.tkd_is_new_res in (RM_CONSTS.RM_TK_DATA_WORK_NONE, RM_CONSTS.RM_TK_DATA_WORK_INTO) ) dd )
           LOOP
             mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                            xClass_ID => v1.tkd_res_class,
                                                            xRes_ID   => v1.tkd_resource,
                                                            xPos      => v1.npp,
                                                            xDoc_ID   => mRMDocID,
                                                            xUser_ID  => irbis_user_id);
           END LOOP;
            /*SELECT rm_gen_tk_data.nextval INTO mTkd_id FROM dual;
            INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                    tkd_isdel, tkd_is_new_res, tkd_parent_id)
            SELECT mTkd_id, mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1, 0, 0, NULL
              FROM (
               SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                 FROM rm_tk_data d
                -- действующая ТК типа GPON по данному адресу, имеющая в ресурсах данный порт
                WHERE d.tkd_tk IN (SELECT d2.tkd_tk
                                     FROM rm_tk_data d2, rm_tk t2
                                    WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                                      AND d2.tkd_resource = LineID
                                      AND d2.tkd_is_new_res in (RM_TK_DATA_WORK_NONE, RM_TK_DATA_WORK_INTO)
                                      AND t2.tk_id = d2.tkd_tk
                                      AND t2.tk_type IN (tk_type_gpon, tk_type_etth)
                                      AND t2.tk_status_id != RM_TK_STATUS_ARCHIVE
                                      AND EXISTS (SELECT 1 FROM rm_tk_address WHERE adr_tk = d2.tkd_tk AND adr_id = mAddress_ID))
                  AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_TK_STATUS_ARCHIVE
                  AND d.tkd_res_class IN (RM_CONSTS.RM_RES_CLASS_EQUIP_PORT, RM_CONSTS.RM_RES_CLASS_LINE_DATA)
                  AND d.tkd_resource != LineID  -- уже был добавлен в ТК
                  AND d.tkd_isdel = 0
                  AND d.tkd_is_new_res in (RM_TK_DATA_WORK_NONE, RM_TK_DATA_WORK_INTO) ) dd;

                irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
         END IF;
      END IF;
   END IF;

   -- сохранение созданной техкарты в документе - заявке
   IF mCategID = 7 THEN
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE id = mContent_ID;
      -- сохранение созданной техкарты в документе - техсправке
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE paper_id = mTS_ID;
   ELSE
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE id = mContent_ID;
      -- сохранение созданной техкарты в документе - техсправке
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE paper_id = mTS_ID;
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);

END CreatePSTNTC;

-- Процесс создание Тех.Карты  на установку охранной сигнализации #2
-- Задачи:
-- 1. Создание заявления и наряда
-- 2. Создание тех.карты
-- по номеру телефона филиал. Сделать попытку определить ЛД, добавить их к ТК
PROCEDURE ProcessPlantAlarm (
   RequestID   IN NUMBER,    -- идентификатор заявки в IRBiS
   Num         IN VARCHAR2,  -- номер телефона, на который производится установка охранной сигнализации
   AlarmKey    IN VARCHAR2,  -- значение ключа охраны, в виде текста
   MainParam   IN VARCHAR2   -- набор XML-данных, содержащий универсальные параметры
) IS
   CURSOR cTelzoneByLD(aLD rm_tk_data.tkd_resource%TYPE) IS
      SELECT tk.tk_telzone, (SELECT MAX (a.adr_id)
                               FROM rm_tk_address a
                              WHERE a.adr_tk = tk.tk_id) adr
        FROM rm_tk tk
       WHERE tk.tk_status_id <> 0
         AND tk.tk_id IN (SELECT d.tkd_tk
                            FROM rm_tk_data d
                           WHERE d.tkd_res_class = 7
                             AND d.tkd_resource = aLD
                             AND d.tkd_is_new_res = 0)
         AND ROWNUM = 1;

   CURSOR GetSubtype (aTYPE_ID  irbis_subtypes.type_id%TYPE,
                      aTK_TYPE  irbis_subtypes.tk_type%TYPE) IS
      SELECT subtype_id
        FROM irbis_subtypes
       WHERE type_id = aTYPE_ID
         AND tk_type = aTK_TYPE
         AND proc    = 8;     -- установка охранной сигнализации

   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mDocType       ad_subtypes.type_id%TYPE;     -- id типа документа
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   mLD            rm_tk_data.tkd_resource%TYPE;
   mNumID         rm_tk_data.tkd_resource%TYPE;
   mShortNum      rm_numbers.num_number%TYPE;
   mTK            rm_tk.tk_id%TYPE;
   mTelzone_ID    list_telzone.ltz_cod%TYPE;
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;
   --mTkd_id        NUMBER;
   mCategID       NUMBER;
   mAbonementID   NUMBER;                       -- идентификатор абонемента
   mClientID      NUMBER;                       -- номер клиента в IRBiS
   mKeyParams     irbis_activity_log.parameters%TYPE;
   mUsl           number;
   mTD_ID         number;
   mRMDocID       number;
BEGIN
   mKeyParams := 'Num="' || TO_CHAR(Num) ||
                 '", AlarmKey="' || AlarmKey ||
                 '"';
   irbis_is_core.write_irbis_activity_log('ProcessPlantAlarm',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.VALUE);
         WHEN 'ClientID'           THEN mClientID        := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   BEGIN
      -- определить ld по номерной емкости
      mLD := irbis_is_core.GetLDByNumber(Num);

      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК и филиала ---------------------------------------------------
      OPEN cTelzoneByLD(mLD);
      FETCH cTelzoneByLD into mTelzone_ID, mAddress_ID;
      CLOSE cTelzoneByLD;
   EXCEPTION
      WHEN others THEN
         mLD := NULL;
         irbis_is_core.split_phone(Num, mTelzone_ID, mShortNum, mNumID);
         SELECT NVL((SELECT MAX (a.adr_id)
                       FROM rm_tk_address a, rm_tk_data d
                      WHERE a.adr_tk = d.tkd_tk
                        AND d.tkd_resource  = mNumID
                        AND d.tkd_res_class = 6
                        AND (SELECT tk.tk_status_id FROM rm_tk tk WHERE tk.tk_id = a.adr_tk) != 0), NULL)
           INTO mAddress_ID FROM dual;
   END;
   mAddress2_ID := NULL;

   -- ОТДЕЛ АБОНЕНТСКИЙ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('ProcessPlantAlarm', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      -- тип документа
      mDocType := irbis_is_core.get_type_by_telzone(mTelzone_ID);
      -- вид документа - заявления
      OPEN GetSubtype(mDocType, tk_type_oxr);
      FETCH GetSubtype INTO mSubtype_ID;
      IF GetSubtype%NOTFOUND OR (mSubtype_ID IS NULL) THEN
         CLOSE GetSubtype;
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить вид документа-заявления!');
      END IF;
      CLOSE GetSubtype;

      SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_POH'), NULL)
        INTO mCuslType_ID FROM dual;

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '',
                                            mTelzone_ID, irbis_user_id, mCuslType_ID,
                                            mClientID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',
                                            mAddress_ID, 'M2000_ADDRESS',
                                            mAddress2_ID, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);
      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 8);

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NUM_PULT', AlarmKey, AlarmKey);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NUM', Num, Num);
   END IF;

   -- вид дочернего документа - наряда
   mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'O');

   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mOrder_ID;
   -- создание техкарты
   rm_doc.ad_create_tk(mTK,           -- id тех карты
                       tk_type_oxr,   -- тип тех карты
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление ссылки на абонемент Irbis в техкарту
   IF (mAbonementID IS NOT NULL) THEN
     mUsl := RM_TK_PKG.InsertServiceData(xTK_ID   => mTK,
                                         xExt_ID  => 0,
                                         xSvc_ID  => mAbonementID,
                                         xSvcCode => 'IRBIS',
                                         xSvcName => 'Абонемент IRBiS');
      /*INSERT INTO rm_tk_usl (usl_rec, usl_tk, usl_id, usl_idext, usl_strcod, usl_name)
       VALUES (rm_gen_tk_usl.NEXTVAL, mTK, mAbonementID, 0, 'IRBIS', 'Абонемент IRBiS');*/
   END IF;

   -- привязка техкарты к наряду
   UPDATE ad_paper_extended SET tk_id = mTK WHERE paper_id = mOrder_ID;
   -- привязка техкарты к заявлению
   UPDATE ad_paper_extended SET tk_id = mTK WHERE id = mContent_ID;

   -- в техкарте сразу должны быть ЛД
   IF mLD IS NOT NULL THEN
     mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
     mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK,
                                                    xClass_ID => RM_CONSTS.RM_RES_CLASS_LINE_DATA,
                                                    xRes_ID   => mLD,
                                                    xDoc_ID   => mRMDocID,
                                                    xUser_ID  => irbis_user_id);
     if (mTD_ID is null) then null; end if;

     /* INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK, 7, mLD, 0, 0, 0, NULL)
         RETURNING tkd_id INTO mTkd_id;

        irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
   END IF;

   -- сохранение ключа охраны
   irbis_is_core.SaveTKProp(mTK, 'KEYG', AlarmKey);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END ProcessPlantAlarm;

-- Процесс перекроссировки охранной сигнализации с MainParam
PROCEDURE ProcessReCrossAlarm
(
   RequestID    IN NUMBER,   -- идентификатор заявки в IRBiS
   NewAlarmKey  IN VARCHAR2, -- значение старого ключа охраны, в виде текста
   MainParam    IN VARCHAR2   -- XML с общей информацией
) IS
   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_type, tk_telzone, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID;

   CURSOR GetSubtype (aTYPE_ID  irbis_subtypes.type_id%TYPE,
                      aTK_TYPE  irbis_subtypes.tk_type%TYPE) IS
      SELECT subtype_id
        FROM irbis_subtypes
       WHERE type_id = aTYPE_ID
         AND tk_type = aTK_TYPE
         AND proc    = 12;     -- перекроссировка

   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   --mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
   mTK            rm_tk.tk_id%TYPE;             -- id созданной техкарты
   --mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) созданной техкарты

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   mDocType       ad_subtypes.type_id%TYPE;     -- id типа документа
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000

   mAccountID    ad_paper_content.abonent_id%TYPE;
   --mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;

   mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;
   mParentExists  NUMBER;
   mCategID       NUMBER;
   mTemp          NUMBER;
   mAbonementID   NUMBER;                       -- идентификатор абонемента
   mClientID      NUMBER;                       -- номер клиента в IRBiS
   mOperatorName  VARCHAR2(255); -- ФИО оператора создавшего заявление
BEGIN
   irbis_is_core.write_irbis_activity_log('ProcessReCrossAlarm',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", NewAlarmKey="' || NewAlarmKey ||
                            '"', RequestID, MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

--   Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.VALUE);
         WHEN 'ClientID'           THEN mClientID        := TO_NUMBER(x.VALUE);
         WHEN 'ContractTCID'       THEN mTK_ID           := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.VALUE;
         WHEN 'AccountID'          THEN mAccountID      := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   irbis_utl.assertNotNull(mTK_ID, 'Не указан номер технической карты!');
   irbis_is_core.get_tk_info(mTK_ID, mTelzone_ID, mTK_type);

   -- Проверка того, что переданный абонемент уже находится в переданной техкарте
   SELECT COUNT(1) INTO mTemp
     FROM rm_tk_usl u
    WHERE u.usl_tk = mTK_ID AND u.usl_id = mAbonementID AND u.usl_strcod = 'IRBIS';
   IF mTemp = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Данный абонемент отсутствует в технической карте');
   END IF;

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mParentExists := 0;
   SELECT COUNT(id) INTO mParentExists
     FROM ad_papers p
    WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
      AND p.object_code = 'D';

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mParentExists > 0) THEN
      SELECT p.id INTO mDeclar_ID FROM ad_papers p
       WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
         AND p.object_code = 'D'
         AND ROWNUM < 2;

      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK_ID, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      -- тип документа
      mDocType := irbis_is_core.get_type_by_telzone(mTelzone_ID);
      -- вид документа - заявления
      OPEN GetSubtype(mDocType, mTK_type);
      FETCH GetSubtype INTO mSubtype_ID;
      IF GetSubtype%NOTFOUND OR (mSubtype_ID IS NULL) THEN
         CLOSE GetSubtype;
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить вид документа-заявления!');
      END IF;
      CLOSE GetSubtype;

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_POH'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID,
                                               mContent_ID,
                                               mSubtype_ID,
                                               SYSDATE,
                                               '',
                                               mTelzone_ID,
                                               irbis_user_id,
                                               mCuslType_ID,
                                               mClientID,
                                               'IRBIS_CONTRAGENT',
                                               mAccountID,
                                               'IRBIS_ABONENT',
                                               mAddress_ID,
                                               'M2000_ADDRESS',
                                               mAddress2_ID,
                                               'M2000_ADDRESS',
                                               0,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL);
         UPDATE ad_paper_extended
            SET usl_id      = mAbonementID,
                usl_card_id = mCuslType_ID,
                tk_id       = mTK_ID
          WHERE id = mContent_ID;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- Отделом-создателем является абон отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 12, MainParam);

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_NUM_PULT', NewAlarmKey, NewAlarmKey);
      SELECT REPLACE(REPLACE(TRIM(tk_rem), CHR(13), ''), CHR(10), '')
        INTO mAttrValue FROM rm_tk WHERE tk_id = mTK_ID;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_NUM_PULT', mAttrValue, mAttrValue);

   END IF;
   -- вид дочернего документа
   mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'O');

   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0);

   -- сохранение ключа охраны
   irbis_is_core.SaveTKProp(mTK, 'KEYG', NewAlarmKey);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END ProcessReCrossAlarm;


-- Процесс снятия охранной сигнализации
-- 1. Поиск техкарты
-- 2. Определение отделов, куда будут направлены документы
-- 3. Определение вида заявления на снятие
-- 4. Определение вида наряда на снятие
-- 5. Создание заявления на снятие
-- 6. Запись атрибутов заявления
-- 7. Отправка заявления в абон отдел
-- 8. Создание наряда на основании заявления
-- 9. Отправка наряда в тех отдел
--10. Привязка техкарты к документам
PROCEDURE ProcessExAlarmTK
(
   RequestID   IN NUMBER,    -- идентификатор заявки в IRBiS
   Num         IN VARCHAR2,  -- номер телефона, с которого производится снятие охранной сигнализации
   AlarmKey    IN VARCHAR2   -- значение ключа охраны, в виде текста
) IS

   CURSOR cTKbyLD(aLD rm_tk_data.tkd_resource%type) IS
      SELECT t1.tk_id,t1.tk_telzone
        FROM rm_tk_data d1, rm_tk t1
       WHERE d1.tkd_tk = t1.tk_id
         AND t1.tk_status_id <> 0
         AND d1.tkd_res_class = 7
         AND d1.tkd_resource = aLD
         AND d1.tkd_is_new_res = 0
         AND t1.tk_type = tk_type_oxr;

   CURSOR GetSubtype (aTYPE_ID  irbis_subtypes.type_id%TYPE,
                      aTK_TYPE  irbis_subtypes.tk_type%TYPE) IS
      SELECT subtype_id
        FROM irbis_subtypes
       WHERE type_id = aTYPE_ID
         AND tk_type = aTK_TYPE
         AND proc    = 4;     -- снятие

   CURSOR GetIrbisUslFromTK(aTK  rm_tk.tk_id%TYPE) IS
      SELECT usl_id
        FROM rm_tk_usl
       WHERE usl_tk = aTK
         AND usl_strcod = 'IRBIS';

   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mDocType       ad_subtypes.type_id%TYPE;     -- id типа документа
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mTexOtdel_ID   ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания
   mStpDepID      ad_subtype_department.id%TYPE;   -- следующий пункт прохождения
   mOldDepID      ad_subtype_department.id%TYPE;   -- текущий пункт прохождения
   mResID         ad_list_resolution.id%TYPE;
   mAbonementID   number;
   mLD            rm_tk_data.tkd_resource%type;
   mTK            rm_tk.tk_id%type;
   mTelzone_ID    list_telzone.ltz_cod%type;
BEGIN
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   -- определить ld по номерной ескости
   mLD := irbis_is_core.GetLDByNumber(Num);
   -- найти ТК по известной LD
   OPEN cTKbyLD(mLD);
   FETCH cTKbyLD INTO mTK, mTelzone_ID;
   IF cTKbyLD%NOTFOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Тех. карта не найдена!');
   END IF;
   CLOSE cTKbyLD;
   -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
   irbis_is_core.get_address_by_tk(mTK, mAddress_ID, mAddress2_ID);

   -- ОТДЕЛ АБОНЕНТСКИЙ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
   -- тип документа
   mDocType := irbis_is_core.get_type_by_telzone(mTelzone_ID);
   -- вид документа - наряда
   OPEN GetSubtype(mDocType, tk_type_oxr);
   FETCH GetSubtype INTO mSubtype_ID;
   IF GetSubtype%NOTFOUND OR (mSubtype_ID IS NULL) THEN
      CLOSE GetSubtype;
      RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить вид документа-наряда!');
   END IF;
   CLOSE GetSubtype;

   SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_POH';
   irbis_is_core.get_irbis_abonent(mTK, mAbonent_ID, mContragent_ID);
   ad_utils.ad_create_paper_cat7_single(mOrder_ID,
                                        mContent_ID,
                                        mSubtype_ID,
                                        SYSDATE,
                                        '',
                                        mTelzone_ID,
                                        irbis_user_id,
                                        mCuslType_ID,
                                        mContragent_ID,
                                        'IRBIS_CONTRAGENT',
                                        mAbonent_ID,
                                        'IRBIS_ABONENT',
                                        mAddress_ID,
                                        'M2000_ADDRESS',
                                        mAddress2_ID,
                                        'M2000_ADDRESS',
                                        0,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL);
   -- привязка техкарты к наряду
   UPDATE ad_paper_extended SET tk_id = mTK WHERE id = mContent_ID;
   OPEN GetIrbisUslFromTK(mTK);
   FETCH GetIrbisUslFromTK INTO mAbonementID;
   IF GetIrbisUslFromTK%FOUND AND (mAbonementID IS NOT NULL) THEN
      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
   END IF;
   CLOSE GetIrbisUslFromTK;

   -- НАПРАВЛЕНИЕ ДОКУМЕНТА В НУЖНЫЙ ОТДЕЛ -------------------------------------
   mAbonOtdelID := irbis_utl.getDepCreatorByWork(mOrder_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
   irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
   irbis_is_core.move_created_paper(mOrder_ID, mAbonOtdelID);

   irbis_is_core.get_next_step_data(mOrder_ID, mOldDepID, mStpDepID, mTexOtdel_ID, mResID);

   ad_utils.ad_createas_execute_action(2,
                                       mOrder_ID,
                                       irbis_user_id,
                                       mResID,
                                       NULL,
                                       NULL,
                                       mAbonOtdelID,
                                       mOldDepID,
                                       mTexOtdel_ID,
                                       mStpDepID);

   -- привязка ID заявки Ирбис к наряду
   irbis_is_core.attach_paper_to_request(mOrder_ID, RequestID, 4);

   -- дата исполнения
   UPDATE ad_paper_attr
      SET value      = TO_CHAR(SYSDATE, 'DD.MM.YYYY'),
          value_long = TO_CHAR(SYSDATE, 'DD.MM.YYYY')
    WHERE paper_id = mOrder_ID
      AND UPPER(strcod) = 'DATE_PLAN';

END ProcessExAlarmTK;

-- <23.01.2014-Точкасова М.А.> Создание заявления, ТС на замену номера, используется коллекция MainParam
-- 1. Запись в историю
-- 2. Разбор XML
-- 3. Поиск техкарты и филиала
-- 4. Проверка наличия абонемента в техкарте
-- 5. Определение отдела, куда будут направлены документы
-- 6. Определение адресов ТК
-- 7. Определение вида заявления
-- 8. Проверка категории заявления (создание только для 7 категории)
-- 9. Определение типа услуги
-- 10. Создание заявления
-- 11. Привязка ТК, id абонемента и тип услуги к заявлению
-- 12. Заполнение Атрибутов заявления
-- 13. Привязка ID заявки Ирбис к заявлению
-- 14. Отправка заявления в абон отдел
-- 15. Определение вида ТС
-- 16. Создание ТС на основании заявления (привязка ТК к ТС)
-- 17. Заполнение старого номера из ТК в атрибут ТС 'OLD_PHONE_NUM'
-- 18. Отправка ТС в следующий отдел
PROCEDURE CreateNumTS
(
   RequestID     IN NUMBER,    -- идентификатор заявки в IRBiS
   Num           IN VARCHAR2,  -- выбранный номер телефона (10 знаков)
   EхpDate       IN DATE,      -- Ожидаемая абонентом дата изменения телефонного номера
   MainParam     IN VARCHAR2   -- XML с общей информацией
) IS

   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_type, tk_telzone, tk_status_id
        FROM rm_tk tk
       WHERE tk_id = atk_id;

   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mDeclar_ID     ad_papers.id%TYPE;            -- id документа
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContent_ID    ad_paper_content.ID%TYPE;     -- id содержания созданного документа
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mAbonementID   NUMBER;
   mTK            rm_tk.tk_id%TYPE;
   mTelzone_ID    list_telzone.ltz_cod%TYPE;
   mTK_status     NUMBER;
   mTK_type       rm_tk.tk_type%TYPE;
   --mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mChildSubtype  ad_subtypes.ID%TYPE;
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mAttrValuLong  ad_paper_attr.value_long%TYPE;

   mCategID       ad_subtypes.list_cat_id%TYPE;
   mTemp          NUMBER;

   mOperatorName    ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   mClientID           NUMBER;   -- номер клиента в IRBiS
   mContactPhone       ad_paper_attr.value_long%TYPE;
BEGIN
   irbis_is_core.write_irbis_activity_log('CreateNumTS',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", Num="' || Num ||
                            '", EхpDate="' || TO_CHAR(EхpDate, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID, MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

    -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractTCID'        THEN mTK              := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonID'    THEN mAbonementID     := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'      THEN mOperatorName    := x.VALUE;
         WHEN 'ClientID'            THEN mClientID        := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
         WHEN 'AccountID'           THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
         WHEN 'ClientPhones'        THEN mContactPhone    := x.value;
         ELSE NULL;
      END CASE;
   END LOOP;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   IF mTK IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(mTK);
   FETCH GetTK INTO mTK_type, mTelzone_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;

   -- Проверка того, что переданный абонемент уже находится в переданной техкарте
   SELECT COUNT(1) INTO mTemp
     FROM rm_tk_usl u
    WHERE u.usl_tk = mTK AND u.usl_id = mAbonementID AND u.usl_strcod = 'IRBIS';
   IF mTemp = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Данный абонемент отсутствует в технической карте');
   END IF;

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
    IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             --mDocType,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
     irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="11";' ||
                               'OBJECT="D";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                               '"',
                               RequestID);
      mSubtype_ID := irbis_utl.defineSubtype('BP="11";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                                             'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                             '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');


      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID,
                                               mContent_ID,
                                               mSubtype_ID,
                                               SYSDATE,
                                               '',
                                               mTelzone_ID,
                                               irbis_user_id,
                                               mCuslType_ID,
                                               --mContragent_ID,
                                               mClientID,
                                               'IRBIS_CONTRAGENT',
                                               mAbonent_ID,
                                               'IRBIS_ABONENT',
                                               mAddress_ID,
                                               'M2000_ADDRESS',
                                               mAddress2_ID,
                                               'M2000_ADDRESS',
                                               0,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL);
      -- привязка ТК, id абонемента и тип услуги к заявлению
         UPDATE ad_paper_extended
            SET usl_id      = mAbonementID,
                usl_card_id = mCuslType_ID,
                tk_id       = mTK
          WHERE id = mContent_ID;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      -- Заполнение Атрибутов заявления
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', TO_CHAR(mTK), TO_CHAR(mTK));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_NUM', Num, Num);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATE_PLAN', TO_CHAR(EхpDate, 'DD.MM.YYYY'), TO_CHAR(EхpDate, 'DD.MM.YYYY'));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 11, MainParam);

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

   -- вид дочернего документа
   mChildSubtype := irbis_utl.defineSubtype('BP="11";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                            '"');
   irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   --запись старого номера в атрибут ТС 'OLD_PHONE_NUM'
   irbis_is_core.get_number_from_tk(mTK, mTemp, mAttrValuLong);
   irbis_is_core.update_paper_attr(mTS_ID, 'OLD_PHONE_NUM', TO_CHAR(mTemp), mAttrValuLong);

   --Отправка ТС в следующий отдел
   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateNumTS;

--<23.01.2014-Точкасова М.А.> Создание наряда на замену номера
-- 1. Запись в историю
-- 2. Разбор XML
-- 3. Поиск родительского документа-заявления
-- 4. Определение вида наряда
-- 5. Создание наряда на основании заявления
-- 6. Определение ограничения исходящей связи и оператора дальней связи.
-- 7. Заполнение атрибутов
-- 8. Разбор XML DVOList
-- 9. Отправка наряда в следующий отдел
PROCEDURE CreateCommutationTelNumOrder
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   MainParam       IN VARCHAR2,  -- XML с общей информацией
   DVOList         IN VARCHAR2   -- XML с услугами ДВО
) IS
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
     SELECT p.ID, p.telzone_id, p.department_id
       FROM ad_papers p, irbis_request_papers r
      WHERE r.request_id = aREQUEST
        AND r.paper_id = p.ID
        AND p.parent_id IS NULL;

   CURSOR GetSubtype (aParent_ID   ad_papers.ID%TYPE) IS
     SELECT subtype_id FROM ad_papers WHERE ID = aParent_ID;

   mParent_ID    ad_papers.id%TYPE;
   mParentSubtype ad_subtypes.id%TYPE;
   mTelzone_ID   ad_papers.telzone_id%TYPE;
   mNextOtdel_ID     ad_papers.department_id%TYPE;
   mAbonOtdelID  ad_papers.department_id%TYPE;
   mChildSubtype ad_subtypes.id%TYPE;
   mOrder_ID     ad_papers.id%TYPE;

   mAbonementID   NUMBER;
   mAttrValueID   NUMBER;
   --mAttrValue     ad_paper_attr.value%TYPE;
   mAttrValuLong  ad_paper_attr.value_long%TYPE;

   mTK_type       NUMBER;
   mTK_telzone    NUMBER;
   mTK_ID         rm_tk.tk_id%TYPE;

   mSourceOfSales   VARCHAR2(300);
   mRequestCreator  VARCHAR2(300);
   mContractCommonType VARCHAR2(255); -- Тип абонемента
BEGIN
   irbis_is_core.write_irbis_activity_log('CreateCommutationTelNumOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", RequestComment="' || RequestComment ||
                            '"',
                            RequestID, MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   IF MainParam IS NOT NULL THEN
    FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
              XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
           ) LOOP
     CASE x.param_name
        WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.VALUE;
        WHEN 'RequestCreator'     THEN mRequestCreator  := x.VALUE;
        WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
        WHEN 'ContractCommonID'    THEN mAbonementID     := TO_NUMBER(x.VALUE);
        ELSE NULL;
     END CASE;
    END LOOP;
   END IF;

      -- поиск родительского документа
   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID;
   CLOSE GetParentPaper;
   IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
   END IF;

   OPEN GetSubtype(mParent_ID);
   FETCH GetSubtype INTO mParentSubtype;
   IF GetSubtype%NOTFOUND OR (mParentSubtype IS NULL) THEN
      CLOSE GetSubtype;
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно определить вид родительского документа!');
   END IF;
   CLOSE GetSubtype;

   -- поиск данных для определения вида через defineSubtype
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);
   irbis_is_core.get_tk_info(mTK_ID, mTK_telzone, mTK_type);

   -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
   mChildSubtype := irbis_utl.defineSubtype('BP="11";' ||
                                            'OBJECT="O";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                                            'PARENT_SUBTYPE="' || TO_CHAR(mParentSubtype) ||
                                            '"');
   irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид наряда');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                                      mChildSubtype,
                                      mParent_ID,
                                      mParentSubtype,
                                      RequestID,
                                      mNextOtdel_ID,
                                      mAbonOtdelID,
                                      0,
                                      MainParam);

   -- Определение ограничение исходящей связи
   irbis_is_core.get_irbis_call_barring_state(mAbonementID, mAttrValueID, mAttrValuLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CALLBARRINGSTATE', TO_CHAR(mAttrValueID), mAttrValuLong);
   -- Определение оператора дальней связи
   irbis_is_core.get_irbis_phone_category(mAbonementID, mAttrValueID, mAttrValuLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'PHONECATEGORY', TO_CHAR(mAttrValueID), mAttrValuLong);
   -- Заполнение Атрибутов
   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);

   -- Разбор XML DVOList
   IF DVOList IS NOT NULL THEN
      FOR x IN (SELECT name FROM XMLTABLE('/SERVICES/SERVICE' PASSING XMLTYPE(DVOList)
                COLUMNS NAME VARCHAR2(100) PATH 'NAME')
               ) LOOP
         irbis_is_core.add_paper_attr(mOrder_ID, 'DVO', x.name, x.name);
      END LOOP;
   END IF;

   --Отправка наряда в следующий отдел
   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateCommutationTelNumOrder;

-- Процедура запуска процесса переноса
-- Создать заявление
-- Создать техкарту
-- Привязать техкарту к заявлению
PROCEDURE CreateTransferTC
(
   RequestID          IN NUMBER,   -- идентификатор заявки в IRBiS
   LineID             IN NUMBER,   -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение,
                                   -- OBSOLETE: если null - то организовать новую линию
                                   -- 0  = выбран вариант установки на новую линию (ТВ есть),
                                   -- -1 = ТВ не определяется, выбран вариант установки без ТВ, с обследованием
   NewHouseID         IN NUMBER,   -- идентификатор дома, адрес на которой происходит перенос
   NewApartment       IN VARCHAR2, -- номер квартиры (офиса),  адрес на которой происходит перенос
   ConnectionType     IN VARCHAR2, -- тип подключения (ADSL, SHDSL и т.п.)
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   TarifficationType  IN VARCHAR2, -- тип тарификации (NetFlow поip, SNMP и т.п.)
   BegEndPP           IN NUMBER,   -- при переносе прямого провода указание переносимого конца прямого провода (1 - начало ПП, 0 ? конец)
   MainParam          IN VARCHAR2  -- XML с общей информацией
) IS
   mNewLineID     NUMBER; -- <Stanislav Gorokhov 2017.09.07 8013: [Ticket#2017072610275379]>
   mNewLineID1    NUMBER;
   mOldLineID1    NUMBER;
   mTelzone_ID    NUMBER;
   mAbonent_ID    NUMBER;
   mContragent_ID NUMBER;
   mAbonementID   NUMBER;
   mContactPhone  ad_paper_attr.value_long%TYPE;
   mTK            NUMBER;
   mOldCrossID    NUMBER;
   mNewAddress    NUMBER;
   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mState         NUMBER;
   mHouseAdr      NUMBER;
   mTemp          NUMBER;
   mTemp1         NUMBER;
   mRMHouse       NUMBER;
   mSubtype_ID    NUMBER;          -- вид родительского документа
   mChildSubtype  NUMBER;
   mAbonOtdelID   NUMBER; -- id отдела, в котором заявление должно оказаться сразу после создания
   mCuslType_ID   NUMBER; -- тип услуги в M2000
   mTK_type       NUMBER;
   mDeclar_ID     NUMBER;            -- id созданного документа
   mContent_ID    NUMBER;     -- id содержания созданного документа
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   --mParentExists  NUMBER;
   mCategID       NUMBER;
   mAddress_ID    NUMBER;
   mAddress2_ID   NUMBER;
   mTransferType  NUMBER;
   mAttrValueID   NUMBER;
   mAttrValue     ad_paper_attr.value%TYPE;
   mAttrValuLong  ad_paper_attr.value_long%TYPE;
   CURSOR GetLine(aTK rm_tk_data.tkd_tk%TYPE) IS
      SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = 7 AND tkd_isdel = 0 AND tkd_is_new_res = 0;
   mLineID     rm_tk_data.tkd_resource%TYPE;
   --mTkd_id          NUMBER;
   mContractHouse    NUMBER;
   mContractApart    ad_paper_attr.value_long%TYPE;
   mTariffPlanName   ad_paper_attr.value_long%TYPE;
   mContractAddress  NUMBER;
   mConnectionType   VARCHAR2(200);
   mClientID         NUMBER;    -- идентификатор клиента в IRBiS
   mRequestCreator   VARCHAR2(300);

   mTK_status  rm_tk.tk_status_id%TYPE;

   m2000AdrCardId    NUMBER;
   mBaseResClass     NUMBER;
   mKeyParams     irbis_activity_log.parameters%TYPE;
   mParentAddr    rm_tk_address.adr_rec%TYPE;
   CURSOR GetParentAddress(aTK rm_tk_data.tkd_tk%TYPE, aAddress_ID rm_tk_address.adr_id%TYPE) IS
      SELECT adr_rec FROM rm_tk_address WHERE adr_tk = aTK AND adr_id = aAddress_ID;

   mContractCommonType VARCHAR2(255); -- Тип абонемента

   mTD_ID         number;
   mTD_ID1        NUMBER;
   mAddr          number;
   mRMDocID       number;
   mPos           number;
   mPos1          NUMBER;
   iTarifficationType ad_paper_attr.value%type;
BEGIN
   mKeyParams := 'LineID="' || TO_CHAR(LineID) ||
                 '", NewHouseID="' || TO_CHAR(NewHouseID) ||
                 '", NewApartment="' || NewApartment ||
                 '", ConnectionType="' || ConnectionType ||
                 '", TarifficationType="' || TarifficationType ||
                 '", BegEndPP="' || TO_CHAR(BegEndPP) ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreateTransferTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mContragent_ID   := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ClientID'        THEN mClientID        := TO_NUMBER(x.value);
         WHEN 'ClientPhones'    THEN mContactPhone    := x.value;
         WHEN 'ContractTCID'    THEN mTK              := TO_NUMBER(x.value);
         WHEN 'ContractHouseID' THEN mContractHouse   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mContractApart:= x.value;
         WHEN 'TariffPlanName'  THEN mTariffPlanName  := x.VALUE;
         WHEN 'RequestCreator'  THEN mRequestCreator  := x.VALUE;
         WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   irbis_is_core.get_tk_info(mTK, mTelzone_ID, mTK_type);
   -- ОТДЕЛ АБОНЕНТСКИЙ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- проверка состояния ТК
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');  --Diana

   IF ConnectionType IS NULL THEN
      CASE
         WHEN mTK_type = tk_type_pp THEN mConnectionType := 'ПРЯМОЙ ПРОВОД';
         WHEN mTK_type IN (tk_type_dsl_new, tk_type_dsl_old) THEN mConnectionType := 'ADSL'; --, 'ANNEXB', 'SHDSL', 'REACHDSL'
         WHEN mTK_type = tk_type_tel THEN mConnectionType := 'TEL'; --'ISDN', 'UPATC',
         WHEN mTK_type = tk_type_voip THEN mConnectionType := 'VOIP';
         WHEN mTK_type = tk_type_vats THEN mConnectionType := 'ВАТС-ПОРТАЛ';
      END CASE;
   ELSE
      mConnectionType := UPPER(ConnectionType);
   END IF;

   irbis_is_core.GetAddressID(NewHouseID, NewApartment, mNewAddress, mHouseOnly, mPrivateHouse, 1, mState);
   IF LineID > 0 THEN
      mBaseResClass := irbis_is_core.getBaseResClass(mClientID, LineID, mNewAddress);
   END IF;

   IF (UPPER(mConnectionType) NOT IN ('GPON', 'METROETHERNET (ДОМОВЫЕ СЕТИ)', 'METROETHERNET (ДОМОВЫЕ СЕТИ)1GBIT', 'METROETHERNET (ДОМОВЫЕ СЕТИ)10GBIT', 'ПРЯМОЙ ПРОВОД',
                                      'KTV', 'ETHERNET', 'WIFIMETROETHERNET', 'WIFIGUEST', 'VOIP', 'IP TV ETHERNET', 'IP TV GPON', 'WIFIMETROETHERNET', 'ВАТС-ПОРТАЛ', 'KTVG')) OR
      (UPPER(mConnectionType) IN ('WIFIGUEST') AND (mBaseResClass = 7)) THEN
     mOldCrossID := irbis_is_core.get_cross_by_tk(mTK);
   END IF;

   -- дом частный
   IF mPrivateHouse = 1 THEN
      mHouseAdr := mNewAddress;
   -- дом многоквартирный
   ELSE
      mHouseAdr := irbis_utl.getHouseAdrByAdr(mNewAddress);
   END IF;

   SELECT COUNT(o.obj_id) INTO mTemp FROM rm_object o WHERE o.obj_adr = mHouseAdr AND o.obj_class = 3;
   irbis_utl.assertTrue(mTemp < 2, 'В системе техучета зарегистрировано более одного дома по данному адресу');
   SELECT NVL((SELECT o.obj_id FROM rm_object o WHERE o.obj_adr = mHouseAdr AND o.obj_class = 3), NULL)
     INTO mRMHouse FROM dual;

   irbis_is_core.get_address_by_tk(mTK, mAddress_ID, mAddress2_ID, 0);
   -- адреса концов прямого провода - проверка и замена в случае необходимости
   -- адрес абонемента должен быть равен началу прямого провода (mContractAddress = mAddress_ID)
   IF UPPER(mConnectionType) = 'ПРЯМОЙ ПРОВОД' THEN
      irbis_is_core.GetAddressID(mContractHouse, mContractApart, mContractAddress, mHouseOnly, mPrivateHouse, 1, mState);
      irbis_utl.assertNotNull(mContractAddress, 'Не удалось определить адрес абонемента');
      IF mContractAddress = mAddress2_ID THEN   -- адреса начала прямого провода попал во вторую переменную, поменять
         mTemp := mAddress2_ID; mAddress2_ID := mAddress_ID; mAddress_ID := mTemp;
      ELSIF mContractAddress != mAddress_ID THEN  -- где тогда начало ПП??
         RAISE_APPLICATION_ERROR(-20001, 'Не удается определить адрес начала прямого провода');
      END IF;
   END IF;

   -- проверка абонемента в ТК и генерация исключения
   SELECT COUNT(1) INTO mTemp
     FROM rm_tk_usl u
    WHERE u.usl_tk = mTK
      AND u.usl_id = mAbonementID
      AND u.usl_strcod = 'IRBIS';
   IF mTemp = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Техническая карта не содержит данный абонемент');
   END IF;

   SELECT id INTO m2000AdrCardId FROM ad_list_card_type WHERE strcod = 'M2000_ADDRESS' AND card_id = 4;

   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
   mLineID := SIGN(LineID);

    -- сохранение адреса в ТК
   OPEN GetParentAddress(mTK, mAddress_ID);
   FETCH GetParentAddress INTO mParentAddr;
   CLOSE GetParentAddress;
     IF mParentAddr IS NOT NULL THEN
       mAddr := RM_TK_PKG.LazyEmbindAddressIntoData(xTK_ID     => mTK,
                                                    xAdr_ID    => mNewAddress,
                                                    xParent_ID => mParentAddr,
                                                    xDoc_ID    => mRMDocID,
                                                    xUser_ID   => irbis_user_id);
       /* INSERT INTO rm_tk_address (adr_rec, adr_tk, adr_id, adr_is_new, adr_parent_id)
        VALUES (rm_gen_tk_adr.NEXTVAL, mTK, mNewAddress, 1, mParentAddr);*/
     END IF;
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('CreateTransferTC', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ПЕРЕНОС ADSL
      IF (UPPER(mConnectionType) IN ('ADSL', 'ANNEXB', 'SHDSL', 'REACHDSL', 'GPON', 'METROETHERNET (ДОМОВЫЕ СЕТИ)', 'METROETHERNET (ДОМОВЫЕ СЕТИ)1GBIT', 'METROETHERNET (ДОМОВЫЕ СЕТИ)10GBIT', 'ETHERNET', 'WIFIGUEST', 'WIFIADSL', 'WIFIMETROETHERNET')) THEN
         IF (mTK_type = tk_type_sip) THEN --SIP
           SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL'), NULL)
             INTO mCuslType_ID FROM dual;
         ELSE
           SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET'), NULL)
             INTO mCuslType_ID FROM dual;
         END IF;
      -- ПЕРЕНОС ТЕЛЕФОНИИ (по умолчанию)
      ELSIF (UPPER(mConnectionType) IN ('ISDN', 'UPATC', 'TEL', 'SERINIITEL')) THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL'), NULL)
           INTO mCuslType_ID FROM dual;
         -- если известна линия, на которую осуществляется перенос, нет необходимости
         --   пытаться построить новую линию
         mTransferType := 0;
         IF LineID > 0 THEN
            -- сравниваются кроссы по старым и новым ЛД
            IF irbis_is_core.get_cross_by_ld(LineID) = irbis_is_core.get_cross_by_tk(mTK) THEN mTransferType := 2; ELSE mTransferType := 1; END IF;
         ELSE
            BEGIN
               IF irbis_is_core.IsSmallTransfer(mRMHouse, mOldCrossID) THEN mTransferType := 2; ELSE mTransferType := 1; END IF;
            EXCEPTION
               -- не удалось построить линию. Документ все равно должен быть создан
               WHEN others THEN
                  mTransferType := 1;
            END;
         END IF;

      ELSIF (UPPER(mConnectionType) IN ('VOIP')) THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL'), NULL)
           INTO mCuslType_ID FROM dual;

      ELSIF (UPPER(mConnectionType) IN ('ПРЯМОЙ ПРОВОД')) THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_PP'), NULL)
           INTO mCuslType_ID FROM dual;

--24.08.2012    Balmasova   BEGIN
      ELSIF (UPPER(mConnectionType) IN ('KTV','KTVG')) THEN --ktvgpon
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE'), NULL)
           INTO mCuslType_ID FROM dual;
--24.08.2012    Balmasova   END
      ELSIF (UPPER(mConnectionType) IN ('IP TV XDSL', 'IP TV ETHERNET', 'IP TV GPON')) THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_IPTV'), NULL)
           INTO mCuslType_ID FROM dual;
     --<02.11.2020 Хузин А.Ф.>
     ELSIF (UPPER(mConnectionType) IN ('ВАТС-ПОРТАЛ')) THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_NET_RES'), NULL)
           INTO mCuslType_ID FROM dual;

      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Неизвестный тип подключения: ' || mConnectionType);
      END IF;

     -- Проверка правильного выбора базового ресурса для WifiGuest
     IF (UPPER(ConnectionType) = 'WIFIGUEST') THEN
          mTemp :=0;
        SELECT nvl((SELECT tk_type FROM (
             SELECT t.tk_type
               FROM rm_tk t, rm_tk_data d
              WHERE t.tk_id = d.tkd_tk
                AND d.tkd_resource = LineID
                and d.tkd_res_class = mBaseResClass
                AND t.tk_status_id != 0
                AND t.tk_type IN (tk_type_iptv, tk_type_etth, tk_type_ethernet, tk_type_gpon, tk_type_dsl_old, tk_type_dsl_new, tk_type_sip)
                /*AND NOT EXISTS (SELECT 1
                                 FROM rm_tk t1, rm_tk_data d1
                                WHERE t1.tk_id = d1.tkd_tk
                                  AND d1.tkd_resource = LineID
                                  and d1.tkd_res_class = mBaseResClass
                                  AND t1.tk_status_id != 0
                                  AND t1.tk_type IN (tk_type_wifiguest))*/)
        WHERE ROWNUM < 2), NULL) INTO mTemp FROM dual;
        irbis_utl.assertNotNull(mTemp, 'Неправильно выбран ресурс!');
     END IF;

       IF (mLineID > 0) AND (mConnectionType = 'IP TV XDSL') THEN
       SELECT COUNT(t.tk_id)
           INTO mTemp
           FROM rm_tk_data d, rm_tk t
          WHERE d.tkd_resource = LineID
            AND d.tkd_isdel = 0
            AND d.tkd_res_class = 7
            AND d.tkd_tk = t.tk_id
            AND t.tk_status_id != 0
            AND t.tk_type IN (tk_type_dsl_old, tk_type_dsl_new);
         IF mTemp > 0 THEN
            mLineID := 1;
         ELSE
            -- ЛИНИЯ ЕСТЬ, НО СПД НЕ ПРЕДОСТАВЛЯЕТСЯ
            -- переданный ресурс находится в ТК типа "Телефон"
            SELECT COUNT(t.tk_id)
              INTO mTemp
              FROM rm_tk_data d, rm_tk t
             WHERE d.tkd_resource = LineID
               AND d.tkd_isdel = 0
               AND d.tkd_res_class = 7
               AND d.tkd_tk = t.tk_id
               AND t.tk_status_id != 0
               AND t.tk_type IN (tk_type_tel, tk_type_pp, tk_type_oxr);
            IF mTemp > 0 THEN
               mLineID := 2;
            END IF;
         END IF;
      END IF;


      irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="9";' ||
                               'OBJECT="D";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                               'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                               'LINE="' || TO_CHAR(mLineID) || '";' ||
                               'TRUNSFER_TYPE="' || mTransferType || '";' ||
                               'AUTHENTICATION="' || UPPER(AuthenticationType) || '";',
                               RequestID);
      mSubtype_ID := irbis_utl.defineSubtype('BP="9";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                             'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                             'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                                             'LINE="' || TO_CHAR(mLineID) || '";' ||
                                             'TRUNSFER_TYPE="' || mTransferType || '";' ||
                                             'AUTHENTICATION="' || UPPER(AuthenticationType) || '";');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '', mTelzone_ID, irbis_user_id,
                                            mCuslType_ID,
                                            mContragent_ID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',

                                            -- временно возвращаем как было:
                                            mNewAddress, 'M2000_ADDRESS',
                                            NULL, 'M2000_ADDRESS',

                                            --mAddress_ID, 'M2000_ADDRESS', mAddress2_ID, 'M2000_ADDRESS',



                                            0, NULL, NULL, NULL, NULL, NULL);
      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      UPDATE ad_paper_extended
         SET usl_id = mAbonementID,
             usl_card_id = mCuslType_ID   --,
             -- на старый лад:
             --new_adr_id = mNewAddress,
             --new_adr_card_id = m2000AdrCardId
       WHERE id = mContent_ID;
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 9, MainParam);

      irbis_is_core.attach_tk_to_paper(mTK, mDeclar_ID);

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      SELECT DECODE(mTransferType,
                    1, 'Большой перенос',
                    2, 'Малый перенос',
                    'Не определен') INTO mAttrValuLong FROM dual;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TRUNSFER_TYPE', TO_CHAR(mTransferType), mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', TO_CHAR(mTK), TO_CHAR(mTK));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.get_irbis_call_barring_state(mAbonementID, mAttrValueID, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CALLBARRINGSTATE', TO_CHAR(mAttrValueID), mAttrValuLong);
      irbis_is_core.get_irbis_phone_category(mAbonementID, mAttrValueID, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PHONECATEGORY', TO_CHAR(mAttrValueID), mAttrValuLong);
      IF LineID < 1 THEN
         mAttrValue    := 1;
         mAttrValuLong := 'На новую линию';
      ELSE
         mAttrValue    := 2;
         mAttrValuLong := 'На существующую';
      END IF;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_OPERATION', mAttrValue, mAttrValuLong);

      -- сохранение адресов
      IF UPPER(mConnectionType) = 'ПРЯМОЙ ПРОВОД' THEN
         irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_ADDR_BGN', TO_CHAR(mAddress_ID), ao_adr.get_addresst(mAddress_ID));
         irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_ADDR_END', TO_CHAR(mAddress2_ID), ao_adr.get_addresst(mAddress2_ID));
         IF BegEndPP = 1 THEN  -- переносится начало ПП
            irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ADDR_BGN', TO_CHAR(mNewAddress), ao_adr.get_addresst(mNewAddress));
            irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ADDR_END', TO_CHAR(mAddress2_ID), ao_adr.get_addresst(mAddress2_ID));
            -- на старый лад:
            UPDATE ad_paper_extended SET address2_id = mAddress2_ID, adr2_card_id = m2000AdrCardId WHERE id = mContent_ID;
            --UPDATE ad_paper_extended SET new_adr2_id = mAddress2_ID, new_adr2_card_id = m2000AdrCardId WHERE id = mContent_ID;
         ELSE
            irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ADDR_BGN', TO_CHAR(mAddress_ID), ao_adr.get_addresst(mAddress_ID));
            irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ADDR_END', TO_CHAR(mNewAddress), ao_adr.get_addresst(mNewAddress));
            -- на старый лад:
            UPDATE ad_paper_extended SET address_id = mAddress_ID, adr_card_id = m2000AdrCardId,
                                         address2_id = mNewAddress, adr2_card_id = m2000AdrCardId
             WHERE id = mContent_ID;
            --UPDATE ad_paper_extended SET new_adr_id = mAddress_ID, new_adr_card_id = m2000AdrCardId,
            --                             new_adr2_id = mNewAddress, new_adr2_card_id = m2000AdrCardId
            -- WHERE id = mContent_ID;
         END IF;
      ELSE
         irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_ADDR', TO_CHAR(mAddress_ID), ao_adr.get_addresst(mAddress_ID));
         irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ADDR', TO_CHAR(mNewAddress),  ao_adr.get_addresst(mNewAddress));
      END IF;

      SELECT DECODE(TarifficationType, 'RADIUS accounting', 1, 'NetFlow по ip', 2, 'SNMP', 3, TarifficationType) INTO iTarifficationType FROM dual;

      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'LINE', TO_CHAR(LineID),  TO_CHAR(LineID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', AuthenticationType, AuthenticationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_TP', mTariffPlanName, mTariffPlanName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TARIFFICATION_TYPE', iTarifficationType, TarifficationType);

   END IF;

   irbis_is_core.write_irbis_activity_log('defineSubtype',
                            'BP="9";' ||
                            'OBJECT="T";' ||
                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                            'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                            'LINE="' || TO_CHAR(mLineID) || '";' ||
                            'TRUNSFER_TYPE="' || mTransferType || '";' ||
                            'AUTHENTICATION="' || UPPER(AuthenticationType) || '";',
                            RequestID);
   mChildSubtype := irbis_utl.defineSubtype('BP="9";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                                            'LINE="' || TO_CHAR(mLineID) || '";' ||
                                            'TRUNSFER_TYPE="' || mTransferType || '";' ||
                                            'AUTHENTICATION="' || UPPER(AuthenticationType) || '";');
   irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);
   OPEN GetLine(mTK); FETCH GetLine INTO mLineID; CLOSE GetLine;
   irbis_is_core.update_paper_attr(mTS_ID, 'OLD_LD', TO_CHAR(mLineID), rm_pkg.getlinetext(mLineID));

   IF (LineID > 0) THEN
        --Для SIP РТУ
        IF mTK_type = tk_type_sip AND UPPER(mConnectionType) IN ('METROETHERNET (ДОМОВЫЕ СЕТИ)', 'METROETHERNET (ДОМОВЫЕ СЕТИ)1GBIT', 'METROETHERNET (ДОМОВЫЕ СЕТИ)10GBIT') THEN
               SELECT NVL((SELECT tkd_id FROM
                             (SELECT tkd_id FROM rm_tk_data d, rm_equip_port p
                               WHERE d.tkd_tk = mTK AND d.tkd_res_class = 2
                                 AND d.tkd_isdel = 0 AND d.tkd_is_new_res=0
                                 AND p.prt_id = d.tkd_resource
                                 -- тип порта : Ethernet, FastEthernet, Сектор WiMAX
                                 AND p.prt_type IN (43, 543, 843, 1023, 383, 263)
                              ORDER BY d.tkd_is_new_res DESC)
                            WHERE ROWNUM < 2), NULL)
                 INTO mTemp FROM dual;
        -- <01.12.2020 Хузин А.Ф.> Начало
        ELSIF mTK_type = 302 OR mTK_type = 242 AND UPPER(ConnectionType) = 'KTVG' THEN
            -- Сплиттер GPON
            SELECT NVL((SELECT tkd.tkd_id FROM rm_tk_data tkd
                        JOIN rm_equip_port prt  ON tkd.tkd_resource = prt.prt_id
                        JOIN rm_equip_unit un   ON prt.prt_unit = un.un_id
                        JOIN rm_equipment eq    ON un.un_equip = eq.equ_id AND eq.equ_type = 1043
                        WHERE tkd.tkd_tk = mTK AND tkd.tkd_res_class = 2
                            AND tkd.tkd_isdel = 0 AND tkd.tkd_is_new_res = 0), NULL) INTO mTemp
            FROM dual;
            -- Коммутатор GPON
            mTemp1 := NULL;
            SELECT tkd.tkd_id, tkd.tkd_resource INTO mTemp1, mOldLineID1 FROM rm_tk_data tkd
            JOIN rm_equip_port prt  ON tkd.tkd_resource = prt.prt_id
            JOIN rm_equip_unit un   ON prt.prt_unit = un.un_id
            JOIN rm_equipment eq    ON un.un_equip = eq.equ_id AND eq.equ_type = 1003
            WHERE tkd.tkd_tk = mTK AND tkd.tkd_res_class = 2
                AND tkd.tkd_isdel = 0 AND tkd.tkd_is_new_res = 0;
        -- <01.12.2020 Хузин А.Ф.> Конец
        ELSE
            -- ссылка на старый (удаляемый) ресурс
            SELECT NVL((SELECT tkd_id FROM rm_tk_data
                       WHERE tkd_tk = mTK AND tkd_res_class = mBaseResClass
                         AND tkd_isdel = 0 AND tkd_is_new_res = 0), NULL)
            INTO mTemp FROM dual;
      END IF;

      if (mBaseResClass = RM_CONSTS.RM_RES_CLASS_LINE_DATA) then
        mNewLineID := RM_PKG.CopyLine(LineID);
        if mNewLineID is null then
          RAISE_APPLICATION_ERROR(-20001, 'Ошибка копирования ЛД: Ресурс не является ЛД');
        end if;
      else
        mNewLineID := LineID;

      end if;

      SELECT nvl(max(tkd_npp)+1, 0) INTO mPos FROM rm_tk_data WHERE tkd_tk = mTK;
      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK,
                                                     xClass_ID  => mBaseResClass,
                                                     xRes_ID    => mNewLineID,
                                                     xParent_ID => mTemp,
                                                     xPos       => mPos,
                                                     xDoc_ID    => mRMDocID,
                                                     xUser_ID   => irbis_user_id);
    if (mTD_ID is null) then null; end if;
    -- <01.12.2020 Хузин А.Ф.> Начало
    IF mTK_type = 302 OR (mTK_type = 242 AND UPPER(ConnectionType) = 'KTVG') THEN
        SELECT tkd1.tkd_resource INTO mNewLineID1 FROM rm_tk_data tkd
        JOIN rm_tk_data tkd1    ON tkd.tkd_tk = tkd1.tkd_tk AND tkd1.tkd_resource <> LineID AND tkd1.tkd_res_class = 2
        JOIN rm_tk tk           ON tk.tk_id = tkd.tkd_tk AND tk.tk_status_id <> 0 AND tk.tk_id <> mTK
        JOIN rm_equip_port prt  ON tkd1.tkd_resource = prt.prt_id
        JOIN rm_equip_unit un   ON prt.prt_unit = un.un_id
        JOIN rm_equipment eq    ON un.un_equip = eq.equ_id AND eq.equ_type = 1003
        WHERE tkd.tkd_resource = LineID;

        IF mNewLineID1 <> mOldLineID1 AND mOldLineID1 IS NOT NULL THEN
            SELECT nvl(max(tkd_npp)+3, 0) INTO mPos1 FROM rm_tk_data WHERE tkd_tk = mTK;
            mTD_ID1 := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK,
                                                             xClass_ID  => mBaseResClass,
                                                             xRes_ID    => mNewLineID1,
                                                             xParent_ID => mTemp1,
                                                             xPos       => mPos1,
                                                             xDoc_ID    => mRMDocID,
                                                             xUser_ID   => irbis_user_id);
            if (mTD_ID1 is null) then null; end if;
        END IF;
    END IF;
    -- <01.12.2020 Хузин А.Ф.> Конец
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateTransferTC;

-- Запуск наряда по процессу переноса
PROCEDURE CreateTransferOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment IN VARCHAR2, -- комментарий к дате назначения монтера
   DateMontWish    IN DATE,     -- желаемая дата прихода монтера
   MainParam       IN VARCHAR2, -- XML с общей информацией
   DVOList         IN VARCHAR2  -- XML с услугами ДВО
) IS
   mParent_ID    ad_papers.id%TYPE;
   mSubtype_ID   ad_subtypes.id%TYPE;
   mTelzone_ID   ad_papers.telzone_id%TYPE;
   mOtdel_ID     ad_papers.department_id%TYPE;
   mAbonOtdelID  ad_papers.department_id%TYPE;
   mChildSubtype ad_subtypes.id%TYPE;
   mOrder_ID     ad_papers.id%TYPE;
   mTK           rm_tk.tk_id%TYPE;
   --mTK_telzone   rm_tk.tk_telzone%TYPE;
   mTK_type      rm_tk.tk_type%TYPE;
   mConnType     ad_paper_attr.value%TYPE;
   mAuthenticationType ad_paper_attr.value%TYPE;
   mTransferType ad_paper_attr.value%TYPE;
   mLine         NUMBER;
   mLineText     ad_paper_attr.value%TYPE;
   mResult       BOOLEAN;
   mSourceOfSales   VARCHAR2(300);
   mRequestCreator  VARCHAR2(300);
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;

   mContractCommonType VARCHAR2(255); -- Тип абонемента
   mTariffPlanName       VARCHAR2(200);

BEGIN
/*
INSERT INTO TMP_LOG_CRTRANS_DVO
(  REQ_ID, OLDDVO, TIME)
VALUES (RequestID,DVOList,SYSDATE);
*/
   irbis_is_core.write_irbis_activity_log('CreateTransferOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   IF MainParam IS NOT NULL THEN
    FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
              XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
           ) LOOP
     CASE x.param_name
        WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.VALUE;
        WHEN 'RequestCreator'     THEN mRequestCreator  := x.VALUE;
        WHEN 'ContractCommonType' THEN mContractCommonType  := x.VALUE;
        WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
        ELSE NULL;
     END CASE;
    END LOOP;
   END IF;
   -- поиск родительского документа
   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mSubtype_ID;
   CLOSE GetParentPaper;
   IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
   END IF;

   mTK := irbis_utl.getTKByPaper(mParent_ID);
   irbis_is_core.get_tk_info(mTK, mTelzone_ID, mTK_type);
   ad_rules.get_attr_value(mParent_ID, 'CONNECTION_TYPE', mResult, mConnType);
   ad_rules.get_attr_value(mParent_ID, 'LINE', mResult, mLineText);
   ad_rules.get_attr_value(mParent_ID, 'TRUNSFER_TYPE', mResult, mTransferType);
   BEGIN
      mLine := SIGN(TO_NUMBER(mLineText));
   EXCEPTION
      WHEN others THEN NULL;
   END;

   ad_rules.get_attr_value(mParent_ID, 'AUTHENTICATION_TYPE', mResult, mAuthenticationType);
   irbis_is_core.write_irbis_activity_log('defineSubtype',
                            'BP="9";' ||
                            'OBJECT="O";' ||
                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                            'CONNECTION="' || UPPER(mConnType) || '";' ||
                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                            'LINE="' || TO_CHAR(SIGN(mLine)) || '";' ||
                            'TRUNSFER_TYPE="' || mTransferType || '";' ||
                            'AUTHENTICATION="' || UPPER(mAuthenticationType) || '";',
                            RequestID);

   mChildSubtype := irbis_utl.defineSubtype('BP="9";' ||
                                            'OBJECT="O";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'CONNECTION="' || mConnType || '";' ||
                                            'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||'";' ||
                                            'LINE="' || TO_CHAR(mLine) || '";' ||
                                            'TRUNSFER_TYPE="' || mTransferType || '";' ||
                                            'AUTHENTICATION="' || UPPER(mAuthenticationType) || '";' ||
                                            'PARENT_SUBTYPE="' || UPPER(mSubtype_ID) || '";');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление


   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   IF (mSubtype_ID) IN (10846, 10845) THEN
      irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_TEST', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   ELSE
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   END IF;
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

   -- Разбор XML DVOList
   IF DVOList IS NOT NULL THEN
      FOR x IN (SELECT name FROM XMLTABLE('/SERVICES/SERVICE' PASSING XMLTYPE(DVOList)
                COLUMNS NAME VARCHAR2(100) PATH 'NAME')
               ) LOOP
         irbis_is_core.add_paper_attr(mOrder_ID, 'DVO', x.name, x.name);
      END LOOP;
   END IF;

   irbis_utl.sendPaperNextDepartment(mOrder_ID);
END CreateTransferOrder;

-- Создание наряда на отключение КТВ
PROCEDURE CreateKTVConnDisconnOrder
(
   RequestID    IN NUMBER,   -- идентификатор заявки в IRBiS
   ChangeType   IN NUMBER,   -- тип изменения: 1 ? отключение по задолженности; 2 ? включение после откл. по задолженности; 3- смена ТП; 4 ? вр. отключение КТВ; 5 ? возобновление после вр. отключения.
   --TCID         IN NUMBER,   -- идентификатор технической карты
   --AbonementID  IN NUMBER,   -- идентификатор абонемента
   --ClientID     IN NUMBER,   -- номер клиента в IRBiS
   --ContactPhone IN VARCHAR2, -- контактный телефон абонента
   --OperatorName IN VARCHAR2, -- ФИО оператора создавшего заявление
   CurTP        IN VARCHAR2, -- текущий ТП КТВ
   NewTP        IN VARCHAR2, -- новый ТП КТВ
   DateMontWish IN DATE DEFAULT SYSDATE,     -- желаемая дата подключения
   MainParam    IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mDeclar_ID     ad_papers.id%TYPE; -- id созданного документа
   mCategID       ad_subtypes.list_cat_id%TYPE;
   mSubtype_ID    ad_papers.subtype_id%TYPE; -- вид родительского документа
   mChildSubtype  ad_papers.subtype_id%TYPE;
   mContent_ID    ad_paper_extended.id%TYPE; -- id содержания созданного документа
   mAddress_ID    ad_paper_extended.address_id%TYPE;
   mAddress2_ID   ad_paper_extended.address2_id%TYPE;
   mContragent_ID ad_paper_extended.contragent_id%TYPE;
   mAbonent_ID    ad_paper_extended.abonent_id%TYPE;
   mAbonementID   ad_paper_extended.usl_id%TYPE;
   mUslType_ID    ad_paper_extended.usl_type_id%TYPE; -- тип услуги
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания
   mOperatorName  ad_paper_attr.value_long%TYPE;
   mContactPhone  ad_paper_attr.value_long%TYPE;
   mConnectionType       ad_paper_attr.VALUE%TYPE;--ktvgpon
BEGIN
   irbis_is_core.write_irbis_activity_log('CreateKTVConnDisconnOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ChangeType="' || TO_CHAR(ChangeType) ||
                            --'", TCID="' || TO_CHAR(TCID) ||
                            --'", AbonementID="' || TO_CHAR(AbonementID) ||
                            --'", ClientID="' || TO_CHAR(ClientID) ||
                            --'", ContactPhone="' || ContactPhone ||
                            --'", OperatorName="' || OperatorName ||
                            '", CurTP="' || CurTP ||
                            '", NewTP="' || NewTP ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mContragent_ID   := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractTCID'    THEN mTK_ID           := TO_NUMBER(x.value);
         WHEN 'RequestCreator'  THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'    THEN mContactPhone    := x.value;
         WHEN 'ConnectionType'     THEN mConnectionType    := x.VALUE;--ktvgpon
         ELSE NULL;
      END CASE;
   END LOOP;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   irbis_utl.assertNotNull(mTK_ID, 'Не указан номер технической карты!');
   irbis_is_core.get_tk_info(mTK_ID, mTelzone_ID, mTK_type);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      mSubtype_ID   := irbis_utl.defineSubtype('BP="23";' ||
                                               'OBJECT="D";' ||
                                               'CHANGETYPE="' || TO_CHAR(ChangeType) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) ||
                                               '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
      IF mCategID = 7 THEN
         irbis_is_core.get_address_by_tk(mTK_ID, mAddress_ID, mAddress2_ID);

         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_CABLE'), NULL)
           INTO mUslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mUslType_ID,
                                               mContragent_ID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mUslType_ID, tk_id = mTK_ID
          WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         -- корректировка отдела-создателя с учетом вида работ
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_TP', CurTP, CurTP);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_TP', NewTP, NewTP);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType); --ktvgpon

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 23, MainParam);
   END IF;

   mChildSubtype := irbis_utl.defineSubtype('BP="23";' ||
                                            'OBJECT="O";' ||
                                            'CHANGETYPE="' || TO_CHAR(ChangeType) ||'";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||
                                            '"');
   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateKTVConnDisconnOrder;

-- Создание наряда на изменение условий договора
PROCEDURE CreateNRPhoneCondChange (
   RequestID         IN NUMBER,
   TCID              IN NUMBER,
   PhoneCategory     IN NUMBER,
   CallBarringState  IN NUMBER,
   ClientID          IN NUMBER   -- номер клиента в IRBiS
) IS
   CURSOR GetSubtype (aTYPE_ID  irbis_subtypes.type_id%TYPE,
                      aPROC     irbis_subtypes.proc%TYPE) IS
      SELECT subtype_id
        FROM irbis_subtypes
       WHERE type_id = aTYPE_ID
         AND proc    = aPROC;

   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_type, tk_telzone, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID;

   CURSOR GetIrbisUslFromTK(aTK  rm_tk.tk_id%TYPE) IS
      SELECT usl_id
        FROM rm_tk_usl
       WHERE usl_tk = aTK
         AND usl_strcod = 'IRBIS';

   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mTK_status     rm_tk.tk_status_id%TYPE;      -- наименование (номер) техкарты

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   mDocType       ad_subtypes.type_id%TYPE;     -- id типа документа
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000

   xCategory      BOOLEAN;
   xState         BOOLEAN;
   --xtmp           VARCHAR2(300);

   mAttrValue     ad_paper_attr.value%TYPE;
   mAttrValuLong  ad_paper_attr.value_long%TYPE;

   --mStpDepID      ad_subtype_department.id%TYPE;   -- следующий пункт прохождения
   --mOldDepID      ad_subtype_department.id%TYPE;   -- текущий пункт прохождения
   --mResID         ad_list_resolution.id%TYPE;

   mAbonementID   ad_paper_extended.usl_id%TYPE;
   mProcess       NUMBER;
   mCategID       NUMBER;
   mParentExists  NUMBER;
BEGIN
   -- определяем что меняется
   xCategory := PhoneCategory IS NOT NULL;
   xState    := CallBarringState IS NOT NULL;
   IF    xCategory THEN
      mProcess := 6;
   ELSIF xState THEN
      mProcess := 7;
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Не определена категория АОН либо статус исходящей связи!');
   END IF;
   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   IF TCID IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(TCID);
   FETCH GetTK INTO mTK_ID, mTK_type, mTelzone_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;

   irbis_utl.assertTrue( UPPER(SUBSTR(irbis_utl.getIrbisPhoneCategoryName(PhoneCategory), 1, 4)) != 'ТЕСТ',
                         'Необходимо выбрать другую категорию телефона');

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ доп.соглашение -------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mParentExists := 0;
   SELECT COUNT(id) INTO mParentExists
     FROM ad_papers p
    WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
      AND p.object_code = 'D';

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mParentExists > 0) THEN
      SELECT p.id INTO mDeclar_ID FROM ad_papers p
       WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
         AND p.object_code = 'D'
         AND ROWNUM < 2;

      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             --mDocType,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(TCID, mAddress_ID, mAddress2_ID, 0);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      -- тип документа
      mDocType := irbis_is_core.get_type_by_telzone(mTelzone_ID);
      -- вид документа - доп.соглашение
      OPEN GetSubtype(mDocType /*, mTK_type*/ , mProcess);
      FETCH GetSubtype INTO mSubtype_ID;
      IF GetSubtype%NOTFOUND OR (mSubtype_ID IS NULL) THEN
         CLOSE GetSubtype;
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить вид документа-заявления!');
      END IF;
      CLOSE GetSubtype;

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория
      IF mCategID = 7 THEN
         -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
         -- тип услуги, необходимая формальность
         -- СПД
         IF (mTK_type = tk_type_dsl_new) OR (mTK_type = tk_type_dsl_old) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
         ELSIF (mTK_type = tk_type_tel) OR (mTK_type = tk_type_voip) OR (mTK_type = tk_type_sip) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         -- TODO:
         ELSIF mTK_type = tk_type_iptv THEN
            mCuslType_ID := NULL;
         ELSE
            mCuslType_ID := NULL;
         END IF;
         irbis_is_core.get_irbis_abonent(TCID, mAbonent_ID, mContragent_ID);
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               ClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- привязка техкарты к заявлению
         UPDATE ad_paper_extended SET tk_id = TCID WHERE id = mContent_ID;
         OPEN GetIrbisUslFromTK(TCID);
         FETCH GetIrbisUslFromTK INTO mAbonementID;
         IF GetIrbisUslFromTK%FOUND AND (mAbonementID IS NOT NULL) THEN
            UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         END IF;
         CLOSE GetIrbisUslFromTK;
      ELSE
         -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
         -- тип услуги, необходимая формальность
         IF    mTK_type = tk_type_tel THEN
            mCuslType_ID := 1;
         ELSIF mTK_type = tk_type_dsl_new THEN
            mCuslType_ID := 8790842;         -- тип услуги
         ELSIF mTK_type = tk_type_dsl_old THEN
            mCuslType_ID := 2101009;         -- Телефон основновной с СПД (old=2103311)
         ELSIF mTK_type = tk_type_iptv THEN
            mCuslType_ID := 8792158;
         ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить тип услуги!');
         END IF;

         -- КОНТРАГЕНТ, АБОНЕНТ ------------------------------------------------------
         irbis_is_core.get_abonent_by_tk(TCID, mAbonent_ID, mContragent_ID);

         -- СОЗДАНИЕ доп.соглашения -------------------------------------------------------
         ad_queue.ad_create_single_request(mDeclar_ID,
                                           mContent_ID,
                                           mSubtype_ID,   -- вид документа
                                           SYSDATE,       -- дата создания документа
                                           '',            -- примечание к документу
                                           mTelzone_ID,   -- филиал
                                           irbis_user_id, -- пользователь
                                           mCuslType_ID,  -- тип услуги
                                           mContragent_ID,-- ID контрагента
                                           mAddress_ID,   -- адрес установки
                                           mAbonent_ID,   -- ID лицевого счета
                                           mAddress2_ID,  -- дополнительный адрес
                                           NULL,          -- id кросса
                                           NULL,          -- id шкафа
                                           NULL,          -- дата постановки в очередь
                                           NULL,          -- резолюция (очередь)
                                           NULL,          -- льгота очередника
                                           NULL,          -- примечание к постановке в очередь
                                           0,             -- action code (0=nothing,1=hold,2=hold,...)
                                           NULL,          -- резолюция
                                           NULL,          -- отдел
                                           NULL,          -- текущий пункт прохождения
                                           NULL,          -- новый пункт прохождения
                                           NULL);         -- номер документа
         -- привязка техкарты к доп.соглашению
         UPDATE ad_paper_content SET bron_id = TCID WHERE paper_id = mDeclar_ID;
      END IF;

      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProcess);
   END IF;

      mAttrValue := TO_CHAR(CallBarringState);
      CASE CallBarringState
         WHEN 1 THEN
            mAttrValuLong := 'Открыто все - ВЗ,МГ,МН';
         WHEN 2 THEN
            mAttrValuLong := 'Закрыта МН связь';
         WHEN 3 THEN
            mAttrValuLong := 'Закрыты выходы на МГ,МН связь';
         WHEN 10 THEN
            mAttrValuLong := 'Закрыто все - ВЗ,МГ,МН';
         ELSE
            mAttrValuLong := '';
      END CASE;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CALLBARRINGSTATE', mAttrValue, mAttrValuLong);

      mAttrValue := TO_CHAR(PhoneCategory);
      mAttrValuLong := irbis_utl.getIrbisPhoneCategoryName(PhoneCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PHONECATEGORY', mAttrValue, mAttrValuLong);

      mAttrValue := TO_CHAR(SYSDATE, 'DD.MM.YYYY');
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATE_PLAN', mAttrValue, mAttrValue);

      mAttrValue := TO_CHAR(TCID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', mAttrValue, mAttrValue);

   -- вид дочернего документа
   mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'O');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ доп.соглашения -----------------------------------
   -- определение дочернего вида см. выше
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0);

   -- дата исполнения
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_PLAN', TO_CHAR(SYSDATE, 'DD.MM.YYYY'), TO_CHAR(SYSDATE, 'DD.MM.YYYY'));

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateNRPhoneCondChange;

-- смена категории исходящей связи
PROCEDURE SetPhoneCategory (
   RequestID      IN NUMBER,
   TCID           IN NUMBER,
   PhoneCategory  IN NUMBER,
   ClientID       IN NUMBER    -- номер клиента в IRBiS
) IS
BEGIN
   irbis_is_core.write_irbis_activity_log('SetPhoneCategory',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", TCID="' || TO_CHAR(TCID) ||
                            '", PhoneCategory="' || TO_CHAR(PhoneCategory) ||
                            '", ClientID="' || TO_CHAR(ClientID) ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   CreateNRPhoneCondChange(RequestID, TCID, PhoneCategory, NULL, ClientID);
END SetPhoneCategory;

-- смена статуса исходящей связи
PROCEDURE SetCallBarringState (
   RequestID         IN NUMBER,
   TCID              IN NUMBER,
   CallBarringState  IN NUMBER,
   ClientID          IN NUMBER    -- номер клиента в IRBiS
) IS
BEGIN
   irbis_is_core.write_irbis_activity_log('SetCallBarringState',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", TCID="' || TO_CHAR(TCID) ||
                            '", CallBarringState="' || TO_CHAR(CallBarringState) ||
                            '", ClientID="' || TO_CHAR(ClientID) ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   CreateNRPhoneCondChange(RequestID, TCID, NULL, CallBarringState, ClientID);
END SetCallBarringState;

-- заявка на снятие услуги
-- 1. Поиск техкарты
-- 2. Определение отделов, куда будут направлены документы
-- 3. Определение вида заявления на снятие
-- 4. Определение вида наряда на снятие
-- 5. Создание заявления на снятие
-- 6. Запись атрибутов заявления
-- 7. Отправка заявления в абон отдел
-- 8. Создание наряда на основании заявления
-- 9. Отправка наряда в тех отдел
--10. Привязка техкарты к документам
PROCEDURE CloseTC
(
   RequestID    IN NUMBER,     -- идентификатор заявки на расторжение в IRBiS
   CloseReason  IN VARCHAR2,   -- причина отказа от услуг
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   MainParam          IN VARCHAR2  -- XML с общей информацией
)
IS
   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_type, tk_telzone, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID;

   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mTK_status     rm_tk.tk_status_id%TYPE;      -- наименование (номер) техкарты

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в который наряд должен быть направлен после создания

   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;

   mCategID       ad_subtypes.list_cat_id%TYPE;
   --mParentExists  NUMBER;
   mFlag          NUMBER;

   mTK            NUMBER; -- id техкарты
   mAbonementID   NUMBER; -- идентификатор абонемента
   mOperatorName    ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление
   mClientID      NUMBER;   -- номер клиента в IRBiS
   mConnectionType   ad_paper_attr.VALUE%TYPE;
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   mContactPhone  ad_paper_attr.value_long%TYPE; -- контактный телефон абонента
   mContractTypeID NUMBER; --Идентификатор типа абонемента
   mTemp           NUMBER;
   mTK_info VARCHAR2(300); --полное название ТК
BEGIN
   irbis_is_core.write_irbis_activity_log('CloseTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", CloseReason="' || CloseReason ||
                            '", AuthenticationType="' || TO_CHAR(AuthenticationType) ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

 -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractTCID'        THEN mTK                  := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonID'    THEN mAbonementID         := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'      THEN mOperatorName        := x.VALUE;
         WHEN 'ClientID'            THEN mClientID            := TO_NUMBER(x.VALUE);
         WHEN 'ConnectionType'      THEN mConnectionType      := x.VALUE;
         WHEN 'AccountID'           THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
         WHEN 'ClientPhones'        THEN mContactPhone         := x.VALUE;
         WHEN 'ContractTypeID'      THEN mContractTypeID      := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   IF mTK IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(mTK);
   FETCH GetTK INTO mTK_ID, mTK_type, mTelzone_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;

   --проверка соответствия тип ТК и абонемента -- NEW
   SELECT count(1) INTO mTemp FROM ad_type_tk_usl WHERE tk_type = mTK_type AND usl_type = mContractTypeID;
   SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                         '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                    FROM  rm_tk t WHERE t.tk_id = mTK_ID), NULL)INTO mTK_info FROM dual;
   irbis_utl.assertTrue((mTemp>0),'Тип указанной технической карты ' || TO_CHAR(mTK_info) ||
                                  ' не может соответствовать типу данного абонемента (' || TO_CHAR(mContractCommonType) || ')!');

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
     mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
  IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      mSubtype_ID := irbis_utl.defineSubtype('BP="4";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                             'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                             'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                                             'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                             '";');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория
      IF mCategID = 7 THEN
         -- проверка наличия абонемента в техкарте
         SELECT COUNT(u.usl_rec) INTO mFlag
           FROM rm_tk_usl u
          WHERE u.usl_tk     = mTK_ID
            AND u.usl_id     = mAbonementID
            AND u.usl_strcod = 'IRBIS';
         IF mFlag = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта (' || TO_CHAR(mTK_ID) ||
                                            ') не содержит данный абонемент (' || TO_CHAR(mAbonementID) || ')!');
         END IF;

         -- СПД
         IF (mTK_type IN (tk_type_dsl_old,
                          tk_type_dsl_new,
                          tk_type_wimax,
                          tk_type_etth,
                          tk_type_ethernet,
                          tk_type_gpon,
                          tk_type_wifiguest,
                          tk_type_wifistreet,
                          tk_type_wifiadsl,
                          tk_type_wifimetroethernet)) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
         ELSIF mTK_type IN (tk_type_tel, tk_type_voip, tk_type_sip) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         ELSIF (mTK_type = tk_type_oxr) THEN
            SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_POH';
         ELSIF mTK_type in (tk_type_cable, tk_type_digitalcable, tk_type_ckpt) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
         ELSIF (mTK_type = tk_type_iptv) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_IPTV';
         ELSIF (mTK_type = tk_type_pp) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_PP';
         ELSE
            mCuslType_ID := NULL;
         END IF;
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- привязка техкарты к заявлению
         UPDATE ad_paper_extended SET tk_id = mTK WHERE ID = mContent_ID;
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE ID = mContent_ID;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', AuthenticationType, AuthenticationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 4, MainParam);

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

  irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="4";' ||
                               'OBJECT="O";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                               'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                               'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                               '";',
                               RequestID);
  mChildSubtype := irbis_utl.defineSubtype('BP="4";' ||
                                           'OBJECT="O";' ||
                                           'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                           'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                           'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                                           'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                           '";');
  irbis_utl.assertNotNull(mChildSubtype,'Не определен вид наряда');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0, --можно было бы использовать 1 (отправка в след отдел)
                        MainParam);

   IF mTK_type = tk_type_wifistreet THEN
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(SYSDATE, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(SYSDATE, 'DD.MM.YYYY HH24:MI:SS'));
   ELSE
   -- дата исполнения
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_PLAN', TO_CHAR(SYSDATE, 'DD.MM.YYYY'), TO_CHAR(SYSDATE, 'DD.MM.YYYY'));
   END IF;
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CloseTC;

-- заявка на снятие услуги
-- 1. Поиск техкарты
-- 2. Определение отделов, куда будут направлены документы
-- 3. Определение вида заявления на снятие
-- 4. Определение вида наряда на снятие
-- 5. Создание заявления на снятие
-- 6. Запись атрибутов заявления
-- 7. Отправка заявления в абон отдел
-- 8. Создание наряда на основании заявления
-- 9. Отправка наряда в тех отдел
--10. Привязка техкарты к документам
PROCEDURE CloseTC
(
   RequestID          IN NUMBER,   -- идентификатор заявки на расторжение в IRBiS
   CloseReason        IN VARCHAR2, -- причина отказа от услуг
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   DateMontWish       IN DATE,     -- желаемая дата подключения
   DateMontComment    IN VARCHAR2, -- комментарий к дате назначения монтера
   MainParam          IN VARCHAR2  -- XML с общей информацией
)
IS
   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_type, tk_telzone, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID;

   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mTK_status     rm_tk.tk_status_id%TYPE;      -- наименование (номер) техкарты

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в который наряд должен быть направлен после создания

   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;

   mCategID       ad_subtypes.list_cat_id%TYPE;
   --mParentExists  NUMBER;
   mFlag          NUMBER;

   mTK            NUMBER; -- id техкарты
   mAbonementID   NUMBER; -- идентификатор абонемента
   mOperatorName    ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление
   mClientID      NUMBER;   -- номер клиента в IRBiS
   mConnectionType   ad_paper_attr.VALUE%TYPE;
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   mContactPhone  ad_paper_attr.value_long%TYPE; -- контактный телефон абонента
   mContractTypeID NUMBER; --Идентификатор типа абонемента
   mTemp           NUMBER; --NEW
   mTK_info VARCHAR2(300); --полное название ТК
BEGIN
   irbis_is_core.write_irbis_activity_log('CloseTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", CloseReason="' || CloseReason ||
                            '", AuthenticationType="' || TO_CHAR(AuthenticationType) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

 -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractTCID'        THEN mTK                  := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonID'    THEN mAbonementID         := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'      THEN mOperatorName        := x.VALUE;
         WHEN 'ClientID'            THEN mClientID            := TO_NUMBER(x.VALUE);
         WHEN 'ConnectionType'      THEN mConnectionType      := x.VALUE;
         WHEN 'AccountID'           THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
         WHEN 'ClientPhones'        THEN mContactPhone        := x.VALUE;
         WHEN 'ContractTypeID'      THEN mContractTypeID      := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   IF mTK IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(mTK);
   FETCH GetTK INTO mTK_ID, mTK_type, mTelzone_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;

   --проверка соответствия тип ТК и абонемента
   SELECT count(1) INTO mTemp FROM ad_type_tk_usl WHERE tk_type = mTK_type AND usl_type = mContractTypeID;
   SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                         '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                    FROM  rm_tk t WHERE t.tk_id = mTK_ID), NULL)INTO mTK_info FROM dual;
   irbis_utl.assertTrue((mTemp>0),'Тип указанной технической карты ' || TO_CHAR(mTK_info) ||
                                  ' не может соответствовать типу данного абонемента (' || TO_CHAR(mContractCommonType) || ')!');

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
     mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
  IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      mSubtype_ID := irbis_utl.defineSubtype('BP="4";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                             'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                             'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                                             'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                             '";');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория
      IF mCategID = 7 THEN
         -- проверка наличия абонемента в техкарте
         SELECT COUNT(u.usl_rec) INTO mFlag
           FROM rm_tk_usl u
          WHERE u.usl_tk     = mTK_ID
            AND u.usl_id     = mAbonementID
            AND u.usl_strcod = 'IRBIS';
         IF mFlag = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта (' || TO_CHAR(mTK_ID) ||
                                            ') не содержит данный абонемент (' || TO_CHAR(mAbonementID) || ')!');
         END IF;

         -- СПД
         IF (mTK_type IN (tk_type_dsl_old,
                          tk_type_dsl_new,
                          tk_type_wimax,
                          tk_type_etth,
                          tk_type_ethernet,
                          tk_type_gpon,
                          tk_type_wifiguest,
                          tk_type_wifistreet,
                          tk_type_wifiadsl,
                          tk_type_wifimetroethernet)) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
         ELSIF mTK_type IN (tk_type_tel, tk_type_voip, tk_type_sip) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         -- охранная сигнализация
         ELSIF (mTK_type = tk_type_oxr) then
            SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_POH';
         ELSIF mTK_type in (tk_type_cable,tk_type_digitalcable,tk_type_ckpt) then
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
         ELSIF (mTK_type = tk_type_iptv) then
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_IPTV';
         ELSIF (mTK_type = tk_type_pp) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_PP';
         ELSIF (mTK_type = tk_type_vats) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_NET_RES';
         ELSE
            mCuslType_ID := NULL;
         END IF;
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- привязка техкарты к заявлению
         UPDATE ad_paper_extended SET tk_id = mTK WHERE ID = mContent_ID;
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE ID = mContent_ID;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', AuthenticationType, AuthenticationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 4, MainParam);

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

  irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="4";' ||
                               'OBJECT="O";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                               'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                               'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                               '";',
                               RequestID);
  mChildSubtype := irbis_utl.defineSubtype('BP="4";' ||
                                           'OBJECT="O";' ||
                                           'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                           'CONNECTION="' || UPPER(mConnectionType) || '";' ||
                                           'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                                           'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) ||
                                           '";');
  irbis_utl.assertNotNull(mChildSubtype,'Не определен вид наряда');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0, --можно было бы использовать 1 (отправка в след отдел)
                        MainParam);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
   IF mTK_type = tk_type_wifistreet THEN
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   ELSE
   -- дата исполнения
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_PLAN', TO_CHAR(SYSDATE, 'DD.MM.YYYY'), TO_CHAR(SYSDATE, 'DD.MM.YYYY'));
   END IF;

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CloseTC;

-- Процесс переоформления
PROCEDURE RenewalTC
(
   RequestID      IN NUMBER,               -- идентификатор заявки в IRBiS
   TKID           IN NUMBER,               -- идентификатор Тех карты
   oldAbonementID IN NUMBER,               -- идентификатор старого абонемента
   newAbonementID IN NUMBER,               -- идентификатор нового абонемента
   MainParam      IN VARCHAR2 DEFAULT NULL -- набор XML-данных, содержащий универсальные параметры
) IS
   --mTK_ID         rm_tk.tk_id%TYPE;             -- id старой техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   --mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
   --mTK            rm_tk.tk_id%TYPE;             -- id созданной техкарты
   --mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) созданной техкарты

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   --mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   --mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   --mDocType       ad_subtypes.type_id%TYPE;     -- id типа документа
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   --mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mUslCardStrcod ad_list_card_type.strcod%TYPE;

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;

   --mStpDepID      ad_subtype_department.id%TYPE;   -- следующий пункт прохождения
   --mOldDepID      ad_subtype_department.id%TYPE;   -- текущий пункт прохождения
   --mResID         ad_list_resolution.id%TYPE;
   --mOtdel_ID      ad_subtype_department.department_id%TYPE;  -- отдел, в который направится документ

   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;
   --mTemp          NUMBER;

   CURSOR c_procedure(aPAPER_ID  ad_papers.id%TYPE) IS
     SELECT a.p_hold
       FROM ad_subtypes a
      WHERE a.id = (SELECT b.subtype_id
                      FROM ad_papers b
                     WHERE b.id = aPAPER_ID);
   proc_name   ad_subtypes.p_send%TYPE;
   message     VARCHAR2(2000);
   result      NUMBER;
   vspec         NUMBER;
   num_usl     NUMBER;
BEGIN
   irbis_is_core.write_irbis_activity_log('RenewalTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", TKID="' || TO_CHAR(TKID) ||
                            '", oldAbonementID="' || TO_CHAR(oldAbonementID) ||
                            '", newAbonementID="' || TO_CHAR(newAbonementID) || '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   irbis_is_core.check_tk(TKID);
   irbis_is_core.get_tk_info(TKID, mTelzone_ID, mTK_type);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
   irbis_is_core.get_address_by_tk(TKID, mAddress_ID, mAddress2_ID);

   -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
   --mSubtype_ID := irbis_is_core.get_parent_subtype(mTelzone_ID, 13, mTK_type);
   mSubtype_ID := irbis_utl.defineSubtype('BP="13"');

   IF (mTK_type IN (tk_type_tel, tk_type_voip, tk_type_sip, tk_type_isdn, tk_type_vats))  THEN
      mUslCardStrcod := 'IRBIS_TEL';
   ELSIF (mTK_type IN (tk_type_dsl_old,
                       tk_type_dsl_new,
                       tk_type_wimax,
                       tk_type_etth,
                       tk_type_ethernet,
                       tk_type_wifiguest, ---- ДОБАВИЛА 23.03.2012 Балмасова
                       tk_type_wifiadsl,
                       tk_type_wifimetroethernet,
                       tk_type_gpon,
                       tk_type_wifistreet, ---Добавила Гаппасова 13.11.2015
                       tk_type_sl)) THEN
      mUslCardStrcod := 'IRBIS_INTERNET';
   ELSIF (mTK_type in (tk_type_cable, tk_type_digitalcable)) THEN
      mUslCardStrcod := 'IRBIS_CABLE';
   ELSIF (mTK_type = tk_type_iptv) THEN
      mUslCardStrcod := 'IRBIS_IPTV';
   ELSIF (mTK_type = tk_type_pp) THEN
      mUslCardStrcod := 'IRBIS_PP';
   ELSIF (mTK_type = tk_type_oxr) THEN
      mUslCardStrcod := 'IRBIS_POH';
   ELSIF (mTK_type = tk_type_mvno) THEN
      mUslCardStrcod := 'IRBIS_MVNO';
   END IF;
   SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = mUslCardStrcod), NULL)
     INTO mCuslType_ID FROM dual;

   IF MainParam IS NOT NULL THEN
      -- Разбор XML
      FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                  XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
               ) LOOP
         CASE x.param_name
            WHEN 'ClientID'  THEN mContragent_ID := TO_NUMBER(x.value);
            WHEN 'AccountID' THEN mAbonent_ID    := TO_NUMBER(x.value);
            ELSE NULL;
         END CASE;
      END LOOP;
   ELSE
      SELECT NVL((SELECT cc.account_id FROM billing.TContractCommon@irbis cc WHERE cc.object_no = oldAbonementID), NULL)
        INTO mAbonent_ID FROM dual;
      SELECT NVL((SELECT a.client_id FROM billing.TAccount@irbis a WHERE a.object_no = mAbonent_ID), NULL)
        INTO mContragent_ID FROM dual;
   END IF;

   ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                         SYSDATE, '',
                                         mTelzone_ID, irbis_user_id, mCuslType_ID,
                                         mContragent_ID, 'IRBIS_CONTRAGENT',
                                         mAbonent_ID, 'IRBIS_ABONENT',
                                         mAddress_ID, 'M2000_ADDRESS',
                                         mAddress2_ID, 'M2000_ADDRESS',
                                         0, NULL, NULL, NULL, NULL, NULL);
   irbis_is_core.create_paper_attrs(mDeclar_ID);
   irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', TO_CHAR(TKID), TO_CHAR(TKID));
   irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_ABONEMENT_ID', TO_CHAR(oldAbonementID), TO_CHAR(oldAbonementID));
   irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_ABONEMENT_ID', TO_CHAR(newAbonementID), TO_CHAR(newAbonementID));
   irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));

   UPDATE ad_paper_extended
      SET usl_id      = oldAbonementID,
          usl_card_id = mCuslType_ID,
          tk_id       = TKID
    WHERE id = mContent_ID;

   -- НАПРАВЛЕНИЕ --------------------------------------------------------------
   mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
   irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
   irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

   -- привязка ID заявки Ирбис к наряду
   irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 13, MainParam);

   -- ВЫПОЛНЕНИЕ ДЕЙСТВИЙ ------------------------------------------------------
   --BEGIN
      -- изменение ссылки на услугу в техкарте
      --UPDATE rm_tk_usl
      --   SET usl_id = newAbonementID
      -- WHERE usl_tk = TKID
      --   AND usl_id = oldAbonementID
      --   AND usl_strcod = 'IRBIS';

      for v1 in (select d.usl_rec from rm_tk_usl d where d.usl_tk = TKID and d.usl_id = oldAbonementID and d.usl_strcod = 'IRBIS') loop
          RM_TK_PKG.DeleteServiceData(v1.usl_rec);
      end loop;
     /* DELETE FROM rm_tk_usl WHERE usl_tk = TKID AND usl_id = oldAbonementID AND usl_strcod = 'IRBIS';*/

      irbis_is_core.attach_usl_to_tk(TKID, newAbonementID, 'IRBIS', 'Абонемент IRBiS');

      -- Перенос заявок RSC на новый абонемент 7.09.2011 Балмасова
    /*  UPDATE rsc_card_common card
         SET real_id = newAbonementID
       WHERE real_id = oldAbonementID
         AND card.species_id IN (SELECT s.id FROM rsc_card_species s WHERE s.vid_id = 1);*/

         SELECT COUNT(*) INTO num_usl
         FROM rsc_card_common
         WHERE real_id = oldAbonementID
         AND species_id IN (SELECT id FROM rsc_card_species WHERE vid_id = 1);

         IF num_usl = 1 THEN
         SELECT species_id INTO vspec
         FROM rsc_card_common card
         WHERE real_id = oldAbonementID
         AND species_id IN (SELECT id FROM rsc_card_species WHERE vid_id = 1);

         INSERT INTO rsc_card_common (id,species_id,real_id) VALUES (rsc_card_common_seq.nextval, vspec, newAbonementID);
         END IF;

      /*SAVEPOINT before_hold;*/
      -- завершение работы с документом - проведение и закрытие
      ad_actions.ad_action_paper_hold(mDeclar_ID,
                                      0,
                                      SYSDATE,
                                      248,
                                      SYSDATE,
                                      irbis_user_id,
                                      '');
      OPEN c_procedure(mDeclar_ID);
      FETCH c_procedure INTO proc_name;

      IF (c_procedure%FOUND) AND
         (proc_name IS NOT NULL) AND
         (NOT (LENGTH(TRIM(proc_name)) = 0)) THEN
         EXECUTE IMMEDIATE 'BEGIN ' || proc_name ||
                           '( :mes, :res, :paper_id, :user_id, null, null); END;'
                           USING IN OUT message, IN OUT result, IN mDeclar_ID, IN irbis_user_id;
      END IF;
      CLOSE c_procedure;

      IF result = -1 THEN
         RAISE_APPLICATION_ERROR(-20001, message);
      END IF;
   /*EXCEPTION
      -- в случае ошибки - направление в следующий пункт прохождения
      WHEN others THEN
         ROLLBACK TO before_hold;*/

         /*irbis_is_core.get_next_step_data(mDeclar_ID, mOldDepID, mStpDepID, mOtdel_ID, mResID);
         -- выполнение направления в отдел
         ad_utils.ad_createas_execute_action(2,
                                             mDeclar_ID,
                                             irbis_user_id,
                                             mResID,
                                             NULL,
                                             NULL,
                                             mAbonOtdelID,
                                             mOldDepID,
                                             mOtdel_ID,
                                             mStpDepID);
         BEGIN
            irbis_utl.sendPaperNextDepartment(mDeclar_ID);
         EXCEPTION
            WHEN others THEN NULL;
         END;
         UPDATE ad_paper_history
            SET remm = SUBSTR(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 200)
          WHERE id = (SELECT MAX(id) FROM ad_paper_history WHERE paper_id = mDeclar_ID);
   END;*/
END RenewalTC;

-- Установка параллельного аппарата
-- Изменение технической карты (отметка о наличии параллельного аппарата)
PROCEDURE ModificationParallelAppTK
(
   RequestID   IN NUMBER,  -- идентификатор заявки в IRBiS
   TC          IN NUMBER,  -- идентификатор Тех карты
   AbonementID IN NUMBER,  -- идентификатор абонемента
   ExpDate     IN DATE     -- ожидаемая клиентом дата установки параллельного аппарата
) IS
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала

   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   --mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   --mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в который наряд должен быть направлен после создания

   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   --mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mCategID       ad_subtypes.list_cat_id%TYPE;

   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;
BEGIN
   irbis_is_core.write_irbis_activity_log('ModificationParallelAppTK',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", TС="' || TO_CHAR(TC) ||
                            '", AbonementID="' || TO_CHAR(AbonementID) ||
                            '", ExpDate="' || TO_CHAR(ExpDate, 'DD.MM.YYYY HH24:MI:SS') || '"',
                            RequestID);
   --8938 Заявление на установку параллельного аппарата
   --8939 Техническая справка на установку параллельного аппарата
   --8940 Наряд на установку параллельного аппарата

   -- проверка ТК
   irbis_is_core.check_tk(TC);

   irbis_is_core.get_tk_info(TC, mTelzone_ID, mTK_type);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(TC, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      mSubtype_ID := irbis_is_core.get_parent_subtype(mTelzone_ID, 14, NULL);

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория для Казани
      IF mCategID = 7 THEN
         -- только телефон
         IF  (mTK_type = tk_type_tel)  OR (mTK_type = tk_type_voip) OR (mTK_type = tk_type_sip) THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         ELSE
            mCuslType_ID := NULL;
         END IF;
         irbis_is_core.get_irbis_abonent(TC, mAbonent_ID, mContragent_ID);
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID,
                                               mContent_ID,
                                               mSubtype_ID,
                                               SYSDATE,
                                               '',
                                               mTelzone_ID,
                                               irbis_user_id,
                                               mCuslType_ID,
                                               mContragent_ID,
                                               'IRBIS_CONTRAGENT',
                                               mAbonent_ID,
                                               'IRBIS_ABONENT',
                                               mAddress_ID,
                                               'M2000_ADDRESS',
                                               mAddress2_ID,
                                               'M2000_ADDRESS',
                                               0,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL);
         -- привязка техкарты к заявлению
         UPDATE ad_paper_extended SET tk_id = TC WHERE id = mContent_ID;
         -- TODO: AbonementID???
         --OPEN GetIrbisUslFromTK(TС);
         --FETCH GetIrbisUslFromTK INTO mAbonementID;
         --IF GetIrbisUslFromTK%FOUND AND (mAbonementID IS NOT NULL) THEN
         --   UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         --END IF;
         --CLOSE GetIrbisUslFromTK;
      -- TODO: нет 3 категории
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функциональность не реализована');
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', TO_CHAR(TC), TO_CHAR(TC));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(AbonementID), TO_CHAR(AbonementID));

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 14);

      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

   --TODO: отметка о наличии параллельного аппарата
   --irbis_is_core.SaveTKProp(TС, '????', '???');
END ModificationParallelAppTK;

-- Снятие параллельного аппарата
-- Изменение технической карты (снятие отметки о наличии параллельного аппарата)
PROCEDURE ModificationExParallelAppTK
(
   RequestID   IN NUMBER,  -- идентификатор заявки в IRBiS
   TС          IN NUMBER,  -- идентификатор Тех карты
   AbonementID IN NUMBER,  -- идентификатор абонемента
   ExpDate     IN DATE     -- ожидаемая клиентом дата снятия параллельного аппарата
) IS
BEGIN
   --8941 Заявление на снятие параллельного аппарата
   --8942 Наряд на снятие параллельного аппарата
   NULL;
END ModificationExParallelAppTK;

-- общая процедура для установки и снятия параллельного аппарата
PROCEDURE CommonParallelApp
(
   RequestID         IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish      IN DATE,     -- желаемая дата прихода специалиста
   DateMontComment   IN VARCHAR2, -- комментарий к дате прихода специалиста
   HouseID           IN NUMBER,   -- идентификатор дома, адрес на который устанавливается параллельный аппарат
   Apartment         IN VARCHAR2, -- номер квартиры (офиса), адрес на которой устанавливается параллельный аппарат
   MainParam         IN VARCHAR2, -- XML с общей информацией
   aBP               IN NUMBER    -- БП - 14-установка, 25-снятие
) IS
   mTelzone_ID    NUMBER;
   mAbonent_ID    NUMBER;
   mContragent_ID NUMBER;
   mAbonementID   NUMBER;
   mTK            rm_tk.tk_id%TYPE;
   mTK_type       rm_tk.tk_type%TYPE;
   mDeclar_ID     ad_papers.id%TYPE;
   mContent_ID    ad_paper_extended.id%TYPE;
   mTS_ID         ad_papers.id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE;
   --mParentExists  NUMBER;
   mCategID       NUMBER;
   mAddress_ID    NUMBER;
   mAddress2_ID   NUMBER;
   mAddress    NUMBER;
   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mState         NUMBER;
   mSubtype_ID    ad_papers.subtype_id%TYPE;
   mChildSubtype  ad_papers.subtype_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE;
   mContactPhone  ad_paper_attr.value_long%TYPE;
   mTemp          NUMBER;
   mSourceOfSales  VARCHAR2(300);
   mRequestCreator VARCHAR2(200);
   mAddr          number;
   mRMDocID       number;
BEGIN
   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mContragent_ID   := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractTCID'    THEN mTK              := TO_NUMBER(x.value);
         WHEN 'ClientPhones'    THEN mContactPhone    := x.VALUE;
         WHEN 'SourceOfSales'   THEN mSourceOfSales   := x.VALUE;
         WHEN 'RequestCreator'  THEN mRequestCreator  := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   irbis_is_core.GetAddressID(HouseID, Apartment, mAddress, mHouseOnly, mPrivateHouse, 1, mState);

   irbis_utl.assertNotNull(mTK, 'Не указана техническая карта');
   IF aBP = 25 THEN
      SELECT COUNT(adr_rec) INTO mTemp FROM rm_tk_address WHERE adr_tk = mTK AND adr_id = mAddress;
      irbis_utl.assertTrue(mTemp > 0, 'В указанной техкарте отсутствует данный адрес');
   END IF;
   irbis_is_core.get_tk_info(mTK, mTelzone_ID, mTK_type);
   -- ОТДЕЛ АБОНЕНТСКИЙ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      SELECT NVL((SELECT id FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL'), NULL)
        INTO mCuslType_ID FROM dual;
      mSubtype_ID := irbis_utl.defineSubtype('BP="' || TO_CHAR(aBP) || '";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '', mTelzone_ID, irbis_user_id,
                                            mCuslType_ID,
                                            mContragent_ID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',
                                            mAddress, 'M2000_ADDRESS',
                                            NULL, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);
      UPDATE ad_paper_extended
         SET usl_id = mAbonementID,
             usl_card_id = mCuslType_ID
       WHERE id = mContent_ID;
      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, aBP, MainParam);

      irbis_is_core.attach_tk_to_paper(mTK, mDeclar_ID);

      irbis_is_core.create_paper_attrs(mDeclar_ID);

      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', TO_CHAR(mTK), TO_CHAR(mTK));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);
   END IF;
   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(aBP) || '";' ||
                                            'OBJECT="O";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '"');
   irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид наряда');

   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);
   IF aBP = 14 THEN
      SELECT COUNT(adr_rec) INTO mTemp FROM rm_tk_address WHERE adr_tk = mTK AND adr_id = mAddress;
      IF mTemp = 0 THEN
        mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
        mAddr := RM_TK_PKG.PureEmbindAddressIntoData(xTK_ID     => mTK,
                                                     xAdr_ID    => mAddress,
                                                     xDoc_ID    => mRMDocID,
                                                     xUser_ID   => irbis_user_id,
                                                     xNotice    => 'Параллельный аппарат');
         /*INSERT INTO rm_tk_address (adr_rec, adr_tk, adr_id, adr_rem)
         VALUES (rm_gen_tk_adr.NEXTVAL, mTK, mAddress, 'Параллельный аппарат');*/
      END IF;
      SELECT COUNT(v.id) INTO mTemp
        FROM rm_tk_prop_value v
       WHERE v.tk_id = mTK
         AND v.prop_id = (SELECT p.id FROM rm_tk_property p WHERE p.tktype = mTK_type AND p.strcod = 'PARALLEL_APP');
      IF mTemp = 0 THEN
         INSERT INTO rm_tk_prop_value (id, tk_id, prop_id, value, value_cod)
         VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK, (SELECT p.id FROM rm_tk_property p WHERE p.tktype = mTK_type AND p.strcod = 'PARALLEL_APP'), NULL, 0);
      END IF;
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CommonParallelApp;

-- Создание наряда на установку параллельного аппарата
PROCEDURE CreateParallelAppTK
(
   RequestID         IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish      IN DATE,     -- желаемая дата прихода специалиста
   DateMontComment   IN VARCHAR2, -- комментарий к дате прихода специалиста
   NewHouseID        IN NUMBER,   -- идентификатор дома, адрес на который устанавливается параллельный аппарат
   NewApartment      IN VARCHAR2, -- номер квартиры (офиса), адрес на которой устанавливается параллельный аппарат
   MainParam         IN VARCHAR2  -- XML с общей информацией
) IS
BEGIN
   irbis_is_core.write_irbis_activity_log('CreateParallelAppTK',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", DateMontComment="' || DateMontComment ||
                            '", NewHouseID="' || TO_CHAR(NewHouseID) ||
                            '", NewApartment="' || NewApartment ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   CommonParallelApp(RequestID, DateMontWish, DateMontComment, NewHouseID, NewApartment, MainParam, 14);
END CreateParallelAppTK;

--Создание наряда на снятие параллельного аппарата
PROCEDURE DeleteParallelAppTK
(
   RequestID         IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish      IN DATE,     -- желаемая дата снятия
   DateMontComment   IN VARCHAR2, -- комментарий к дате назначения монтера
   OldHouseID        IN NUMBER,   -- идентификатор дома, адрес c которого снимается параллельный аппарат
   OldApartment      IN VARCHAR2, -- номер квартиры (офиса), адрес c которого снимается параллельный аппарат
   MainParam         IN VARCHAR2  -- XML с общей информацией
) IS
BEGIN
   irbis_is_core.write_irbis_activity_log('DeleteParallelAppTK',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", DateMontComment="' || DateMontComment ||
                            '", OldHouseID="' || TO_CHAR(OldHouseID) ||
                            '", OldApartment="' || OldApartment ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   CommonParallelApp(RequestID, DateMontWish, DateMontComment, OldHouseID, OldApartment, MainParam, 25);
END DeleteParallelAppTK;

-- Процесс снятия брони телефонного номера
PROCEDURE ProcessExResNum
(
   RequestID   IN NUMBER,  -- идентификатор заявки в IRBiS
   TC          IN NUMBER,  -- идентификатор Тех. Карты
   AbonementID IN NUMBER,  -- идентификатор абонемента
   ExpDate     IN DATE     -- ожидаемая абонентом дата бронирования телефонного номера
) IS
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mCategID       ad_subtypes.list_cat_id%TYPE;
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   CURSOR GetPhone(aTK rm_tk_data.tkd_tk%TYPE) IS
      SELECT (SELECT TO_CHAR(t.numcode) FROM list_telcode t WHERE t.id = n.num_telcode) ||
             n.num_number
        FROM rm_tk_data d, rm_numbers n
       WHERE d.tkd_tk = aTK
         AND n.num_id = d.tkd_resource
         AND d.tkd_res_class = 6
         AND d.tkd_is_new_res = 0;
   mPhone      rm_numbers.num_number%TYPE;
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   CURSOR c_procedure(aPAPER_ID  ad_papers.id%TYPE) IS
     SELECT a.p_hold
       FROM ad_subtypes a
      WHERE a.id = (SELECT b.subtype_id
                      FROM ad_papers b
                     WHERE b.id = aPAPER_ID);
   proc_name   ad_subtypes.p_hold%TYPE;
   message     VARCHAR2(2000);
   result      NUMBER;
   mOldDepID      ad_subtype_department.id%TYPE;   -- текущий пункт прохождения
   mStpDepID      ad_subtype_department.id%TYPE;   -- следующий пункт прохождения
   mOtdel_ID      ad_subtype_department.department_id%TYPE;  -- отдел, в который направится документ
   mResID         ad_list_resolution.id%TYPE;
BEGIN
   irbis_is_core.write_irbis_activity_log('ProcessExResNum',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", TС="' || TO_CHAR(TC) ||
                            '", AbonementID="' || TO_CHAR(AbonementID) ||
                            '", ExpDate="' || TO_CHAR(ExpDate, 'DD.MM.YYYY HH24:MI:SS') || '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   -- проверка ТК
   irbis_is_core.check_tk(TC);
   irbis_is_core.get_tk_info(TC, mTelzone_ID, mTK_type);
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(TC, mAddress_ID, mAddress2_ID);

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      mSubtype_ID := irbis_is_core.get_parent_subtype(mTelzone_ID, 16, NULL);

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория для Казани
      IF mCategID = 7 THEN
         -- только телефон
         IF  (mTK_type = tk_type_tel) OR (mTK_type = tk_type_voip) OR (mTK_type = tk_type_sip)  THEN
            SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         ELSE
            mCuslType_ID := NULL;
         END IF;
         irbis_is_core.get_irbis_client_by_abonement(AbonementID, mAbonent_ID, mContragent_ID);
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '', mTelzone_ID, irbis_user_id,
                                               mCuslType_ID,
                                               mContragent_ID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- привязка техкарты к заявлению
         irbis_is_core.attach_tk_to_paper(TC, mDeclar_ID);
      -- TODO: нет 3 категории
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функциональность не реализована');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(AbonementID), TO_CHAR(AbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      OPEN GetPhone(TC); FETCH GetPhone INTO mPhone; CLOSE GetPhone;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TEL_NUM', mPhone, mPhone);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID);

      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

   -- Обработка: перевод ТК в архив и освобождение ресурсов, проведение документа
   BEGIN
      -- попытка перевести ТК в архив
      rm_doc.ad_change_tk_state(TC, irbis_user_id, 0, 'Снятие брони телефонного номера');
      -- попытка завершения работы с документом - проведение и закрытие
      ad_actions.ad_action_paper_hold(mDeclar_ID,
                                      0,
                                      SYSDATE,
                                      248,   -- "Выполнено"
                                      SYSDATE,
                                      irbis_user_id,
                                      '');
      OPEN c_procedure(mDeclar_ID);
      FETCH c_procedure INTO proc_name;

      IF (c_procedure%FOUND) AND
         (proc_name IS NOT NULL) AND
         (NOT (LENGTH(TRIM(proc_name)) = 0)) THEN
         EXECUTE IMMEDIATE 'BEGIN ' || proc_name ||
                           '( :mes, :res, :paper_id, :user_id, null, null); END;'
                           USING IN OUT message, IN OUT result, IN mDeclar_ID, IN irbis_user_id;
      END IF;
      CLOSE c_procedure;

      IF result = -1 THEN
         RAISE_APPLICATION_ERROR(-20001, message);
      END IF;
      -- отправка уведомления в IRBiS
      UPDATE irbis_request_papers SET state_id = 2 WHERE paper_id = mDeclar_ID;
   EXCEPTION
      -- в случае ошибки - направление в следующий пункт прохождения
      WHEN others THEN
         irbis_is_core.get_next_step_data(mDeclar_ID, mOldDepID, mStpDepID, mOtdel_ID, mResID);
         -- выполнение направления в отдел
         ad_utils.ad_createas_execute_action(2,
                                             mDeclar_ID,
                                             irbis_user_id,
                                             mResID,
                                             NULL,
                                             NULL,
                                             mAbonOtdelID,
                                             mOldDepID,
                                             mOtdel_ID,
                                             mStpDepID);
         UPDATE ad_paper_history
            SET remm = SUBSTR(DBMS_UTILITY.FORMAT_ERROR_STACK, 1, 200)
          WHERE id = (SELECT MAX(id) FROM ad_paper_history WHERE paper_id = mDeclar_ID);
   END;
END ProcessExResNum;

-- Процесс создание Тех карты на подключение sip-телефонии, запуск наряда
PROCEDURE ProcessPlanSIPNum
(
   RequestID         IN NUMBER,    -- идентификатор заявки в IRBiS
   PhoneNumb         IN VARCHAR2,  -- номер телефона (10-значный), на который производится установка sip-телефонии
   QuantSes          IN NUMBER,    -- кол-во сессий
   PhoneCategory     IN VARCHAR2,  -- категория исходящей связи
   CallBarringState  IN VARCHAR2,  -- оператор дальней связи
   AbonementID       IN NUMBER     -- идентификатор абонемента
) IS
BEGIN
   NULL;
END ProcessPlanSIPNum;


-- Создание технической карты на бронирование тел номера
PROCEDURE CreateResNumTC (
   RequestID   IN NUMBER,    -- идентификатор заявки в IRBiS
   AbonementId IN NUMBER,    -- идентификатор абонемента
   PhoneNumb   IN VARCHAR2   -- бронируемый номер телефона (10-знаков)
) IS
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mCategID       ad_subtypes.list_cat_id%TYPE;
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mAddress_ID    ad_paper_content.address_id%TYPE;
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mChildSubtype  ad_subtypes.id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   --mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
BEGIN
   irbis_is_core.write_irbis_activity_log('CreateResNumTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", AbonementId="' || TO_CHAR(AbonementId) ||
                            '", PhoneNumb="' || PhoneNumb || '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   mTelzone_ID := irbis_is_core.get_telzone_by_phone(PhoneNumb);
   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------
      mSubtype_ID := irbis_is_core.get_parent_subtype(mTelzone_ID, 15, 1); -- филиал, БП, тип ТК

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      -- 7 категория для Казани
      IF mCategID = 7 THEN
         -- только телефон
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
         irbis_is_core.get_irbis_client_by_abonement(AbonementId, mAbonent_ID, mContragent_ID);
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '', mTelzone_ID, irbis_user_id,
                                               mCuslType_ID,
                                               mContragent_ID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = AbonementId, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TEL_NUM', PhoneNumb, PhoneNumb);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(AbonementId), TO_CHAR(AbonementId));

      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID);
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

   -- вид дочернего документа
   mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'T');

   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0);
   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       tk_type_tel,   -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление ссылки на абонемент Irbis в техкарту
   irbis_is_core.attach_usl_to_tk(mTK_ID, AbonementId, 'IRBIS', 'Абонемент IRBiS');

   -- сохранение созданной техкарты в документе - заявке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mTS_ID);

   irbis_utl.sendPaperNextDepartment(mTS_ID);

END CreateResNumTC;

-- Аннулирование технической карты на бронирование тел номера
PROCEDURE AnnulResNumTC
(
   RequestID IN NUMBER   -- идентификатор заявки в IRBiS
) IS
BEGIN
   NULL;
END AnnulResNumTC;

-- Фиксирование бронирования ТК
PROCEDURE FixResNumTC
(
   RequestID IN NUMBER   -- идентификатор заявки в IRBiS
) IS
BEGIN
   irbis_is_core.write_irbis_activity_log('FixResNumTC',
                            'RequestID="' || TO_CHAR(RequestID) || '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
END FixResNumTC;

-- Выделение сетевого ресурса - Создание заявления и технической карты
PROCEDURE CreateTCDirWire
(
   RequestID      IN NUMBER,   -- идентификатор заявки в IRBiS
   ConnectionType IN VARCHAR2, -- тип сетевого ресурса (прямой провод, поток Е1, SIP-транк)
   BgnHouseID     IN NUMBER,
   BgnApartment   IN VARCHAR2,
   EndHouseID     IN NUMBER,   -- идентификатор дома, адрес подключения которого интересует (2 конец при установке прямого провода)
   EndApartment   IN VARCHAR2, -- номер квартиры (офиса), адрес подключения которого интересует (2 конец при установке прямого провода)
   Direction      IN VARCHAR2, -- направление прямого провода
   KolChannel     IN NUMBER,   -- количество каналов
   Capacity       IN VARCHAR2, -- пропускная способность
   MainParam      IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   mTelzone_ID      ad_papers.telzone_id%TYPE;
   mAbonOtdelID     ad_papers.department_id%TYPE;
   mOtdel_ID        ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mDeclar_ID       ad_papers.id%TYPE;            -- id созданного документа
   mTS_ID           ad_papers.id%TYPE;            -- id техсправки
   mContent_ID      ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mCategID         ad_subtypes.list_cat_id%TYPE; -- id категории документа
   mSubtype_ID      ad_subtypes.id%TYPE;          -- вид родительского документа
   mAddress_ID      ad_paper_content.address_id%TYPE;
   mAddress2_ID     ad_paper_content.address2_id%TYPE;
   mChildSubtype    ad_subtypes.id%TYPE;
   mHouseOnly       NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse    NUMBER;           -- признак того, что дом является частным (без квартир)
   mState           NUMBER;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_Number       rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   mTK_type         rm_tk.tk_type%TYPE := tk_type_pp;  -- тип техкарты (зависит от устанавливаемой услуги)
   mContragent_ID   ad_paper_extended.contragent_id%TYPE;
   mAbonent_ID      ad_paper_extended.abonent_id%TYPE;
   mUslType_ID      ad_paper_extended.usl_type_id%TYPE; -- тип услуги
   mAbonementID     ad_paper_extended.usl_id%TYPE;
   mOperatorName    ad_paper_attr.value_long%TYPE;
   mContactPhone    ad_paper_attr.value_long%TYPE;
   --mDateMontRang    ad_paper_attr.value_long%TYPE;
   --mDateMontComment ad_paper_attr.value_long%TYPE;
   --mDateMont        ad_paper_attr.value_long%TYPE;
   --mRequestComment  ad_paper_attr.value_long%TYPE;
   --mDateMontWish    ad_paper_attr.value_long%TYPE;
   mAccountNumber   ad_paper_attr.value_long%TYPE;
   mTariffPlanName  ad_paper_attr.value_long%TYPE;
   mKeyParams       irbis_activity_log.parameters%TYPE;
   mUsl             number;
BEGIN
   mKeyParams := 'ConnectionType="' || ConnectionType ||
                 '", BgnHouseID="' || TO_CHAR(BgnHouseID) ||
                 '", BgnApartment="' || BgnApartment ||
                 '", EndHouseID="' || TO_CHAR(EndHouseID) ||
                 '", EndApartment="' || EndApartment ||
                 '", Direction="' || Direction ||
                 '", KolChannel="' || TO_CHAR(KolChannel) ||
                 '", Capacity="' || Capacity ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreateTCDirWire',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(BgnHouseID);
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- TODO
   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mContragent_ID   := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'RequestCreator'  THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'    THEN mContactPhone    := x.value;
         WHEN 'AccountNumber'   THEN mAccountNumber   := x.value;
         WHEN 'TariffPlanName'  THEN mTariffPlanName  := x.value;

         /*WHEN 'DateMontRang'    THEN mDateMontRang    := x.value;
         WHEN 'DateMontComment' THEN mDateMontComment := x.value;
         WHEN 'DateMont'        THEN mDateMont        := x.value;
         WHEN 'RequestComment'  THEN mRequestComment  := x.value;
         WHEN 'DateMontWish'    THEN mDateMontWish    := x.value;*/
         ELSE NULL;
      END CASE;
   END LOOP;

   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('CreateTCDirWire', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      -- TODO
      mChildSubtype := irbis_utl.defineSubtype('BP="2";' ||
                                               'OBJECT="T";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');
   ELSE
      mSubtype_ID   := irbis_utl.defineSubtype('BP="2";' ||
                                               'OBJECT="D";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      mChildSubtype := irbis_utl.defineSubtype('BP="2";' ||
                                               'OBJECT="T";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

      mHouseOnly    := 0;      mPrivateHouse := 0;
      irbis_is_core.GetAddressID(BgnHouseID, BgnApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
      mHouseOnly    := 0;      mPrivateHouse := 0;
      irbis_is_core.GetAddressID(EndHouseID, EndApartment, mAddress2_ID, mHouseOnly, mPrivateHouse, 1, mState);



      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
      irbis_utl.assertTrue(mCategID = 7, 'Функциональность реализована только для категории "Расширенная работа с услугами (id = ' || TO_CHAR(mSubtype_ID) || ')');

      SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_PP'), NULL)
        INTO mUslType_ID FROM dual;
      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '',
                                            mTelzone_ID, irbis_user_id, mUslType_ID,
                                            mContragent_ID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',
                                            mAddress_ID, 'M2000_ADDRESS',
                                            mAddress2_ID, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);
      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- корректировка отдела-создателя с учетом вида работ
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mUslType_ID WHERE id = mContent_ID;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      -- TODO
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', ConnectionType, ConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DIRECTION', Direction, Direction);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'KOLCHANNEL', TO_CHAR(KolChannel), TO_CHAR(KolChannel));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CAPACITY', Capacity, Capacity);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CARDNUM_IRBIS', mAccountNumber, mAccountNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TARPLAN', mTariffPlanName, mTariffPlanName);

      /*irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_RANG', mDateMontRang, mDateMontRang);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_RANG2',
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_COMMENT', mDateMontComment, mDateMontComment);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATE_PLAN', mDateMont, mDateMont);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DOC_COMMENT', mRequestComment, mRequestComment);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_WISH', mDateMontWish, mDateMontWish);*/
      /*irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', ContactPhone, ContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CUSL_NUM', mTelNumber, mTelNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'O_SIGNAL', '0', mSec);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', AuthenticationType, AuthenticationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TARIFFICATION_TYPE', TarifficationType, TarifficationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', OperatorName, OperatorName);
*/
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 2, MainParam);
   END IF;

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   IF ConnectionType = 'ВАТС-Портал' THEN
        mTK_type := tk_type_vats;
   END IF;
   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   IF (mAbonementID IS NOT NULL) THEN
     mUsl := RM_TK_PKG.InsertServiceData(xTK_ID   => mTK_ID,
                                          xExt_ID  => 0,
                                          xSvc_ID  => mAbonementID,
                                          xSvcCode => 'IRBIS',
                                          xSvcName => 'Абонемент IRBiS');

      /*INSERT INTO rm_tk_usl (usl_rec, usl_tk, usl_id, usl_idext, usl_strcod, usl_name)
      VALUES (rm_gen_tk_usl.NEXTVAL, mTK_ID, mAbonementID, 0, 'IRBIS', 'Абонемент IRBiS');*/
   END IF;

   IF mCategID = 7 THEN
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE id = mContent_ID;
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE paper_id = mTS_ID;
   ELSE
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE id = mContent_ID;
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE paper_id = mTS_ID;
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateTCDirWire;

-- Выделение сетевого ресурса - Запуск наряда
PROCEDURE CreateDirWireConnectOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста на 1 конец ПП
   DateMontWishEnd IN DATE,     -- желаемая дата прихода специалиста на 2 конец ПП
   DateMontComment IN VARCHAR2, -- комментарий к дате прихода специалиста
   RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
   DateActivation  IN DATE,     -- дата заявленной активации
   MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;
   mParent_ID    ad_papers.id%TYPE;
   mSubtype_ID   ad_subtypes.id%TYPE;
   mTelzone_ID   ad_papers.telzone_id%TYPE;
   mOtdel_ID     ad_papers.department_id%TYPE;
   mAbonOtdelID  ad_papers.department_id%TYPE;
   mChildSubtype ad_subtypes.id%TYPE;
   mOrder_ID     ad_papers.ID%TYPE;
   mSourceOfSales  VARCHAR2(300);
   mRequestCreator VARCHAR2(200);
   mTariffPlanName VARCHAR2(200);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateDirWireConnectOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", DateMontWishEnd="' || TO_CHAR(DateMontWishEnd, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateActivation="' || TO_CHAR(DateActivation, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   IF MainParam IS NOT NULL THEN
    FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
              XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
           ) LOOP
     CASE x.param_name
        WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.VALUE;
        WHEN 'RequestCreator'     THEN mRequestCreator  := x.VALUE;
        WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
        ELSE NULL;
     END CASE;
    END LOOP;
   END IF;

   -- поиск родительского документа
   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mSubtype_ID;
   CLOSE GetParentPaper;
   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

   mChildSubtype := irbis_utl.defineSubtype('BP="2";' ||
                                            'OBJECT="O";' ||
                                            'PARENT_SUBTYPE ="' || TO_CHAR(mSubtype_ID) || '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH2', TO_CHAR(DateMontWishEnd, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWishEnd, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);
   --DATEMONT_RANG
   --DATEMONT_RANG2

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateDirWireConnectOrder;

-- <26.03.2014-Точкасова М.А.> Заявка на замену паспортизированного клиентского оборудования (СРЕ):
-- 1. Разбор XML-коллекции MainParam
-- 2. Получение филиала и типа техкарты
-- 3. Определение отделов, куда будут направлены документы
-- 4. Определение адресов ТК
-- 5. Определение вида заявления, ТС
-- 6. Проверка категории заявления (создание только для 7 категории)
-- 7. Определение типа услуги
-- 8. Создание заявления
-- 9. Отправка заявления в абон отдел
-- 10. Привязка id абонемента и тип услуги к заявлению+
-- 11. Привязка техкарты к заявлению
-- 12. Заполнение Атрибутов заявления
-- 13. Привязка ID заявки Ирбис к заявлению
-- 14. Создание ТС на основании заявления
-- 15. Поиск нового и старого оборудования(нахождение id)
-- 16. Процесс проверки и добавления ресурса в ТК различный в зависимости от типа ТК
-- 17. Автоматическое проведение ТС
-- <10.06.2014-Точкасова М.А.> - изменения с учетом новой услуги ЦКТВ
PROCEDURE CreateChangeModemTS
(
   RequestID          IN     NUMBER,   -- идентификатор заявки в IRBiS
   EquipmentNumberOld IN     VARCHAR2, -- серийный номер старого оборудования
   EquipmentNumber    IN     VARCHAR2, -- серийный номер оборудования
   MainParam          IN     VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   LineID             OUT    NUMBER,    -- идентификатор базового ресурса (оборудования)
   EquipmentLicense  OUT    VARCHAR2  -- внутренний номер устройства ЦКТВ
) IS
   mClientID        ad_paper_extended.contragent_id%TYPE;
   mAbonent_ID      ad_paper_extended.abonent_id%TYPE;
   mCuslType_ID      ad_paper_extended.usl_type_id%TYPE; -- тип услуги
   mAbonementID     ad_paper_extended.usl_id%TYPE;
   mTelzone_ID      ad_papers.telzone_id%TYPE;
   mAbonOtdelID     ad_papers.department_id%TYPE;
   mNextOtdel_ID    ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mDeclar_ID       ad_papers.id%TYPE;            -- id созданного документа
   mTS_ID           ad_papers.id%TYPE;            -- id техсправки
   mContent_ID      ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mCategID         ad_subtypes.list_cat_id%TYPE; -- id категории документа
   mSubtype_ID      ad_subtypes.id%TYPE;          -- вид родительского документа
   mAddress_ID      ad_paper_content.address_id%TYPE;
   mAddress2_ID     ad_paper_content.address2_id%TYPE;
   mChildSubtype    ad_subtypes.id%TYPE;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mEquipOld        rm_tk_data.tkd_id%TYPE;
   mMessage         VARCHAR2(300);
   mHoldResult      VARCHAR2(2000);
   --mTkd_id               NUMBER;
   --mKeyParams     irbis_activity_log.PARAMETERS%TYPE;

   mOperatorName    ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление

   mNewEquipID rm_equipment.equ_id%TYPE; -- id нового оборудования
   mOldEquipID rm_equipment.equ_id%TYPE; -- id старого оборудования
   mTemp            NUMBER;
   mPortID     rm_tk_data.tkd_resource%TYPE;

   mAccountNumber   ad_paper_attr.value_long%TYPE;
   mContactPhone    ad_paper_attr.value_long%TYPE;

   mTD_ID         number;
   mRMDocID       number;

   --Определение id оборудования по серийному номеру для тип устройств "SIP адаптер" и "Модем SAGEM"
   CURSOR GetEquipmentID (aEquipmentNumber rm_res_prop_value.rvl_value%TYPE) IS
   SELECT e.equ_id
     FROM rm_equipment e
    WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1 --возможность добавления устройства в ТК
      AND EXISTS (SELECT 1 FROM rm_res_prop_value v, rm_res_property rp
                   WHERE v.rvl_res = e.equ_id
                     AND v.rvl_prop_id = rp.rpr_id --id свойства
                     AND v.rvl_res_type = rp.rpr_restype --тип устройства
                     AND rp.rpr_strcod in ( 'SERIAL','S_NUMBER')
                     AND rp.rpr_restype IN (2574, 1083) -- типы устройств "CPE" или "Оборудование ЦКТВ"
                     AND LOWER(v.rvl_value) = LOWER(aEquipmentNumber));

     --получение информации по занятым FXS-портам для id оборудования
     CURSOR GetInfoUsedPorts (aEquipId rm_equipment.equ_id%TYPE) IS
     SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id, t.tk_id, d.tkd_id
        FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d, rm_tk t
       WHERE e.equ_id = aEquipId
         AND e.equ_id = eu.un_equip
         AND eu.un_id = ep.prt_unit
         AND ep.prt_type = 1323
         AND rm_pkg.GetResState(ep.prt_id, 2) > 0
         AND d.tkd_resource = ep.prt_id
         AND d.tkd_res_class = 2
         AND d.tkd_tk=t.tk_id
         AND t.tk_status_id !=0
         AND t.tk_type = tk_type_sip
         order by ep.prt_name;

     mProfile  VARCHAR2(200); --наименование профайла
     mProfileID  NUMBER; -- id профайла
    --количество занятых портов на оборудовании
    FUNCTION GetUsedPorts
    (
       aEquipId      IN  rm_equipment.equ_id%TYPE
    ) RETURN NUMBER
    IS
    mCount     NUMBER;
    BEGIN
       SELECT COUNT(1)
       INTO mCount
       FROM rm_equip_unit eu, rm_equip_port ep
       WHERE eu.un_equip = aEquipId
       AND ep.prt_unit = eu.un_id
       AND ep.prt_type = 1323                           -- порт FXS
       AND rm_pkg.GetResState(ep.prt_id, 2) > 0;

       RETURN mCount;
    END GetUsedPorts;

    --количество всего портов на оборудовании
    FUNCTION CountPorts
    (
       aEquipId      IN  rm_equip_port.prt_unit%TYPE
    ) RETURN NUMBER
    IS
    mCount     NUMBER;
    BEGIN
       SELECT COUNT(1)
       INTO mCount
       FROM rm_equip_unit eu, rm_equip_port ep
       WHERE eu.un_equip = aEquipId
       AND ep.prt_unit = eu.un_id
       AND ep.prt_type = 1323;                          -- порт FXS

       RETURN mCount;
    END CountPorts;

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateChangeModemTS',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", EquipmentNumberOld="' || EquipmentNumberOld ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mClientID        := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractTCID'    THEN mTK_ID           := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'  THEN mOperatorName    := x.VALUE;
         WHEN 'ClientPhones'    THEN mContactPhone    := x.VALUE;
         WHEN 'AccountNumber'   THEN mAccountNumber   := x.value;
         ELSE NULL;
      END CASE;
   END LOOP;
   --Получение филиала и типа техкарты
   irbis_is_core.get_tk_info(mTK_ID, mTelzone_ID, mTK_type);
   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
       irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      mChildSubtype := irbis_utl.defineSubtype('BP="24";' ||
                                               'OBJECT="T";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK_ID, mAddress_ID, mAddress2_ID, 1);

      -- ОПРЕДЕЛЕНИЕ ВИДА --------------------------------------------------------
      mSubtype_ID   := irbis_utl.defineSubtype('BP="24";' ||
                                               'OBJECT="D";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      mChildSubtype := irbis_utl.defineSubtype('BP="24";' ||
                                               'OBJECT="T";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
      irbis_utl.assertTrue(mCategID = 7, 'Функциональность реализована только для категории "Расширенная работа с услугами (id = ' || TO_CHAR(mSubtype_ID) || ')');

      -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
       IF (mTK_type = tk_type_wifiguest) THEN
          SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
       ELSIF (mTK_type = tk_type_sip) THEN
          SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
       ELSIF (mTK_type = tk_type_digitalcable) THEN
          SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
       ELSE
          mCuslType_ID := NULL;
       END IF;

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '',
                                            mTelzone_ID, irbis_user_id, mCuslType_ID,
                                            mClientID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',
                                            mAddress_ID, 'M2000_ADDRESS',
                                            mAddress2_ID, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- корректировка отдела-создателя с учетом вида работ
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      -- привязка id абонемента и тип услуги к заявлению
      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE ID = mContent_ID;
      -- привязка техкарты к заявлению и ТС
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE id = mContent_ID;

      -- Заполнение Атрибутов заявления
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CARDNUM_IRBIS', mAccountNumber, mAccountNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_EQUIP', TO_CHAR(EquipmentNumberOld), EquipmentNumberOld);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 24, MainParam);
   END IF;
   irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

--1. поиск нового и старого оборудования
   OPEN GetEquipmentID(EquipmentNumber);
   FETCH GetEquipmentID INTO mNewEquipID;
      IF GetEquipmentID%NOTFOUND THEN
      CLOSE GetEquipmentID;
      RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);
      END IF;
   CLOSE GetEquipmentID;

   OPEN GetEquipmentID(EquipmentNumberOld);
   FETCH GetEquipmentID INTO mOldEquipID;
      IF GetEquipmentID%NOTFOUND THEN
      CLOSE GetEquipmentID;
      RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти старое оборудование с серийным номером : ' || EquipmentNumberOld);
      END IF;
   CLOSE GetEquipmentID;

 IF mTK_type in ( tk_type_wifiguest,tk_type_digitalcable)THEN
    --замена оборудования для WifiGuest
      --2. проверка существования старого оборудования в ТК
     SELECT NVL((SELECT d.tkd_id -- tkd_resource
                   FROM rm_tk_data d
                  WHERE d.tkd_tk = mTK_ID
                    AND d.tkd_res_class = 1
                    AND d.tkd_resource = mOldEquipID
                ), NULL) INTO mEquipOld FROM dual;
     irbis_utl.assertNotNull(mEquipOld, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||
                                         'старое оборудование с серийным номером : ' || EquipmentNumberOld);

     --3. Проверка свободности нового оборудования
     IF rm_pkg.GetResState(mNewEquipID, 1) != 0 THEN
        SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                           '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                      FROM rm_tk_data d, rm_tk t
                     WHERE d.tkd_resource = mNewEquipID
                       AND d.tkd_res_class = 1
                       AND d.tkd_tk = t.tk_id
                       AND t.tk_status_id != 0
                       AND rownum < 2), NULL)
          INTO mMessage FROM dual;
        RAISE_APPLICATION_ERROR(-20001, 'Устройство не свободно, закреплено за ТК ' || mMessage);
     END IF;

      --5. Добавление нового оборудования в ТК
      mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK_ID,
                                                     xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                     xRes_ID    => mNewEquipID,
                                                     xParent_ID => mEquipOld,
                                                     xPos       => 1,
                                                     xDoc_ID    => mRMDocID,
                                                     xUser_ID   => irbis_user_id);
      if (mTD_ID is null) then null; end if;

     /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                             tkd_isdel, tkd_is_new_res, tkd_parent_id)
     VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 1, mNewEquipID, 1, 0, 1, mEquipOld)
      RETURNING tkd_id INTO mTkd_id;
     --добавление в историю ТК информацию о добавлении ресурса в ТК
      irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

      IF mTK_type = tk_type_wifiguest THEN
      --поиск профиля по умолчанию для id оборудования
      SELECT NVL((SELECT p.id
      FROM rm_res_prop_value v, rm_res_property rp, rm_lst_equip_model rm, rm_equip_model_profile mp, rm_lst_equip_profile p
      WHERE v.rvl_res = mNewEquipID
       AND v.rvl_prop_id = rp.rpr_id --id свойства
       AND v.rvl_res_type = rp.rpr_restype --тип устройства
       AND rp.rpr_strcod in ('MODEL')
       AND rp.rpr_restype IN (1083)
       AND UPPER(v.rvl_value)=UPPER(rm.NAME)
       AND rm.ID = mp.model_id
       AND mp.is_default = 1
       AND mp.profile_id = p.ID
       ), NULL) INTO mProfileID FROM dual;
      irbis_utl.assertNotNull(mProfileID, 'Не найден профайл для оборудования с серийным номером : ' || EquipmentNumber);

      SELECT NAME INTO mProfile FROM rm_lst_equip_profile WHERE ID = mProfileID;
      --присвоение свойству профайла
      MERGE INTO rm_tk_prop_value v
     USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PROFILE' and p.tktype=tk_type_wifiguest)
     ON    (v.prop_id = property_id AND v.tk_id = mTK_ID)
     WHEN MATCHED
        THEN UPDATE
             SET value = mProfile, value_cod = mProfileID
     WHEN NOT MATCHED
        THEN INSERT
             VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, mProfile, mProfileID);
     END IF;

     --6.Обновление базового ресурса для WifiGuest, ЦКТВ
     IF mTK_type = tk_type_wifiguest THEN
      LineID := mNewEquipID;
     ELSIF mTK_type = tk_type_digitalcable THEN
      SELECT NVL((SELECT tkd_resource FROM
       (SELECT tkd_resource FROM rm_tk_data d
         WHERE d.tkd_tk = mTK_ID AND d.tkd_res_class = 2
           AND d.tkd_isdel = 0 AND d.tkd_is_new_res IN (0, 1)
        ORDER BY d.tkd_is_new_res DESC)
      WHERE ROWNUM < 2), NULL)
      INTO LineID FROM dual;
     END IF;

 ELSIF mTK_type = tk_type_sip THEN
    --замена оборудования для SIP
    --2. проверка существования порта старого оборудования в ТК
     SELECT count(1) INTO mTemp
       FROM rm_tk_data d, rm_equip_unit eu, rm_equip_port ep
      WHERE d.tkd_tk = mTK_ID
        AND d.tkd_res_class = 2
        AND d.tkd_resource = ep.prt_id
        AND ep.prt_type = 1323    -- FXS порт
        AND ep.prt_unit = eu.un_id
        AND eu.un_equip = mOldEquipID;
     IF (mTemp < 1)
     THEN RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ') порт оборудования с серийным номером : ' || EquipmentNumberOld);
     END IF;

     --3. Проверка свободных портов нового оборудования
     IF (GetUsedPorts(mNewEquipID) > 0)
     THEN RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером : ' || EquipmentNumber||' занято');
     END IF;

    --4. Проверка возможности замены на новое оборудование
     IF (GetUsedPorts(mOldEquipID) > CountPorts(mNewEquipID))
     THEN RAISE_APPLICATION_ERROR(-20001, 'У оборудования с серийным номером : ' || EquipmentNumber||' количество портов меньше, чем у старого оборудования');
     END IF;

    --4.1. Проверка управляемости PMP нового оборудования
    mTemp:=0;
         SELECT count(1) INTO mTemp
           FROM rm_res_property rp, rm_res_prop_value rpv
          WHERE rpv.rvl_res = mNewEquipID
            AND rpv.rvl_prop_id = rp.rpr_id
            AND rp.rpr_restype = rpv.rvl_res_type
            AND UPPER(rp.rpr_strcod) = UPPER('PMP')
            AND UPPER(rpv.rvl_value) = UPPER('Да');
     IF (mTemp < 1)
     THEN RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером : ' || EquipmentNumber||' не управляется PMP');
     END IF;


     --5. Добавление портов нового оборудования в ТК
     mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
     FOR mOldEquip IN GetInfoUsedPorts(mOldEquipID) LOOP
       for v1 in (SELECT mOldEquip.tk_id mTK_ID, RM_CONSTS.RM_RES_CLASS_EQUIP_PORT tkd_res_class, dd.prt_id tkd_resource, 1 npp, mOldEquip.tkd_id tkd_parent_id
                    FROM (SELECT d.prt_id
                            FROM (SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id
                                    FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep
                                   WHERE e.equ_id = mNewEquipID
                                     AND e.equ_id = eu.un_equip
                                     AND eu.un_id = ep.prt_unit
                                     AND ep.prt_type = 1323
                                    --AND rm_pkg.GetResState(ep.prt_id, 2) = 0 --проверка, что занятых портов у оборудования нет, была ранее
                                ORDER BY ep.prt_name) d
                           where d.prt_rownum = mOldEquip.prt_rownum) dd)
         loop
           mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => v1.mTK_ID,
                                                          xClass_ID  => v1.tkd_res_class,
                                                          xRes_ID    => v1.tkd_resource,
                                                          xParent_ID => v1.tkd_parent_id,
                                                          xPos       => v1.npp,
                                                          xDoc_ID    => mRMDocID,
                                                          xUser_ID   => irbis_user_id);
         end loop;
       /*SELECT rm_gen_tk_data.nextval INTO mTkd_id FROM dual;
       INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                               tkd_isdel, tkd_is_new_res, tkd_parent_id)
       SELECT mTkd_id, mOldEquip.tk_id, 2, dd.prt_id, 1, 0, 1, mOldEquip.tkd_id
       FROM (SELECT d.prt_id FROM
          (SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id
              FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep
             WHERE e.equ_id = mNewEquipID
               AND e.equ_id = eu.un_equip
               AND eu.un_id = ep.prt_unit
               AND ep.prt_type = 1323
               --AND rm_pkg.GetResState(ep.prt_id, 2) = 0 --проверка, что занятых портов у оборудования нет, была ранее
               ORDER BY ep.prt_name)d
               where d.prt_rownum=mOldEquip.prt_rownum)dd;
       --добавление в историю ТК информацию о добавлении ресурса в ТК
        irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
     END LOOP;

     mProfileID:=7;  --для SIP в настоящее время профайл SIP_12
    SELECT NAME INTO mProfile FROM rm_lst_equip_profile WHERE ID = mProfileID;
      --присвоение свойству профайла
      MERGE INTO rm_tk_prop_value v
     USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PROFILE' and p.tktype=tk_type_sip)
     ON    (v.prop_id = property_id AND v.tk_id = mTK_ID)
     WHEN MATCHED
        THEN UPDATE
             SET value = mProfile, value_cod = mProfileID
     WHEN NOT MATCHED
        THEN INSERT
             VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, mProfile, mProfileID);

     --6.Обновление базового ресурса для SIP
     -- Базовый ресурс - линия (Sip устанолен по xDSL) либо порт (Sip установлен по Ethernet/WiMAX)
     SELECT NVL((SELECT tkd_resource FROM
                   (SELECT tkd_resource FROM rm_tk_data d, rm_equip_port p
                     WHERE d.tkd_tk = mTK_ID AND d.tkd_res_class = 2
                       AND d.tkd_isdel = 0 AND d.tkd_is_new_res IN (0, 1)
                       AND p.prt_id = d.tkd_resource
                       -- тип порта : Ethernet, FastEthernet, Сектор WiMAX
                       AND p.prt_type IN (43, 543, 843, 1023, 383, 263)
                    ORDER BY d.tkd_is_new_res DESC)
                  WHERE ROWNUM < 2), NULL)
       INTO mPortID FROM dual;
     IF mPortID IS NOT NULL THEN
        LineID := mPortID;
     ELSE
        SELECT NVL((SELECT tkd_resource FROM
                   (SELECT tkd_resource FROM rm_tk_data
                     WHERE tkd_tk = mTK_ID AND tkd_res_class = 7 AND tkd_isdel = 0 AND tkd_is_new_res != 2
                     ORDER BY tkd_is_new_res DESC)
                     WHERE ROWNUM < 2), NULL)
        INTO LineID FROM dual;
     END IF;
     --Проверка передачи в Ирбис базового ресурса--необязательная проверка
     IF LineID IS NULL
     THEN RAISE_APPLICATION_ERROR(-20001, ' Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ') базовый ресурс');
     END IF;
 ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Для данной услуги не предусмотрена замена оборудования!');
 END IF;

   --получение внутреннего номера оборудования
    IF mTK_type = tk_type_digitalcable THEN
       SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                   WHERE v.rvl_res = mNewEquipID
                     AND v.rvl_prop_id = rp.rpr_id --id свойства
                     AND v.rvl_res_type = rp.rpr_restype --тип оборудования
                     AND rp.rpr_strcod = 'S_C_NO'
                     AND rp.rpr_restype = 2574), -- тип оборудования "Оборудование ЦКТВ"), --TO DO: WORK 2574
            NULL) INTO EquipmentLicense FROM dual;
    ELSE
    EquipmentLicense := NULL;
    END IF;

   --irbis_utl.sendPaperNextDepartment(mTS_ID);
   --проведение ТС
   mHoldResult := irbis_is_core.ad_paper_hold(mTS_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
   IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
      RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
   END IF;

   irbis_is_core.write_irbis_activity_log('CreateChangeModemTS - end',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", EquipmentNumberOld="' || EquipmentNumberOld ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '", LineID="' || LineID ||
                            '", EquipmentLicense="' || EquipmentLicense ||
                            '"',
                            RequestID,
                            NULL);

END CreateChangeModemTS;

-- замена паспортизированного клиентского оборудования (СРЕ) (модема WiFi Guest или Sip-адптера и  оборудования ЦКТВ)
-- Запуск наряда
PROCEDURE CreateChangeModemOrder
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment IN VARCHAR2, -- комментарий к дате прихода специалиста
   RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
   MainParam       IN VARCHAR2,  -- набор XML-данных, содержащий универсальные параметры
   OfficeId        IN NUMBER,   --идентификатор  выбранного офиса/склада
   Сonditions      IN NUMBER    --условия выдачи оборудования: 112  - Покупка оборудования(выкуп) , 111  -  Аренда, 113 - Оборудование клиента (продажа)
) IS
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;
   mParent_ID    ad_papers.id%TYPE;
   mSubtype_ID   ad_subtypes.id%TYPE;
   mTelzone_ID   ad_papers.telzone_id%TYPE;
   mOtdel_ID     ad_papers.department_id%TYPE;
   mAbonOtdelID  ad_papers.department_id%TYPE;
   mChildSubtype ad_subtypes.id%TYPE;
   mOrder_ID     ad_papers.id%TYPE;

   mTK_type       NUMBER;
   mTK_telzone    NUMBER;
   mTK_ID         rm_tk.tk_id%TYPE;
   mHoldResult    VARCHAR2(2000);

   Office_name     VARCHAR2(100);
   vcon_str        ad_paper_attr.value%TYPE;
   vcon_id         NUMBER;
   mProc           irbis_subtypes.proc%TYPE; --MCreateChangeModemTS
   mActionType     VARCHAR2(2);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateChangeModemOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", OfficeId="' || OfficeId ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
   -- поиск родительского документа
   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mSubtype_ID;
   CLOSE GetParentPaper;
   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

   -- поиск данных для определения вида через defineSubtype
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);
   irbis_is_core.get_tk_info(mTK_ID, mTK_telzone, mTK_type);

   mProc  := irbis_utl.getProcByPaper(mParent_ID); --MCreateChangeModemTS

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' || --MCreateChangeModemTS
                                            'OBJECT="O";' ||
                                            'PARENT_SUBTYPE="' || TO_CHAR(mSubtype_ID) || '";' || --MCreateChangeModemTS
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);
-- Начало <13.02.2020 Хузин А.Ф.>
   IF mActionType = 12 THEN
   SELECT name INTO Office_name FROM ad_list_office
   WHERE id = OfficeId;
   irbis_is_core.update_paper_attr(mOrder_ID, 'RETUTN_OFFICE', OfficeId, Office_name);
   END IF;
-- Конец
   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));

   --проведение наряда на замену оборудования ЦКТВ
   IF mTK_type = tk_type_digitalcable THEN
       irbis_is_core.update_paper_attr(mOrder_ID, 'MAKE_DATE', TO_CHAR(SYSDATE,'dd.mm.yyyy hh24:mi:ss'), TO_CHAR(SYSDATE,'dd.mm.yyyy hh24:mi:ss'));
       mHoldResult := irbis_is_core.ad_paper_hold(mOrder_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
       IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
          RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
       END IF;
   ELSE
   irbis_utl.sendPaperNextDepartment(mOrder_ID);
   END IF;

END CreateChangeModemOrder;

/*
 * Смена технологии подключения (21-й БП)
 * Создание техсправки
 */
PROCEDURE CreateChangeTechTC
(
   RequestID          IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID         IN NUMBER,   -- идентификатор первичного ресурса (линии/порта), на который следует произвести подключение
   oldConnectionType  IN VARCHAR2, -- текущий тип подключения (voip, аналог и т.п.)
   newConnectionType  IN VARCHAR2, -- выбранный тип подключения (voip, аналог и т.п.)
   PhoneNumber        IN VARCHAR2, -- заполняется, если оператор вручную назначает номер телефона для тех.справки (например он был забронирован)
   AuthenticationType IN VARCHAR2, -- тип авторизации (PPPoE, ISG, выделенная линия и т.п.)
   TarifficationType  IN VARCHAR2, -- тип тарификации (NetFlow поip, SNMP и т.п.)
   EquipmentNumber    IN VARCHAR2, -- серийный номер оборудования
   DeviceType         IN VARCHAR2, -- тип устройства
   MainParam          IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
)
IS
   mTCID          rm_tk.tk_id%TYPE;
   mAbonentID    ad_paper_extended.abonent_id%TYPE;
   mClientID      ad_paper_extended.contragent_id%TYPE;
   mAbonementID   ad_paper_extended.usl_id%TYPE;
   mContactPhone  ad_paper_attr.value_long%TYPE;
   mOperatorName  ad_paper_attr.value_long%TYPE;
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mTK_status     rm_tk.tk_status_id%TYPE;      -- наименование (номер) техкарты
   mProc          NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;          -- вид родительского документа
   mChildSubtype  ad_subtypes.id%TYPE;          -- вид дочернего документа
   mAddress_ID    NUMBER;
   mAddress2_ID   NUMBER;
   mAbonOtdelID   ad_papers.department_id%TYPE; -- id отдела, в котором заявление должно оказаться сразу после создания
   --mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в который техспр должна быть направлена после создания
   mOtdel_ID      NUMBER;
   mParentExists  NUMBER;
   mCategID       ad_subtypes.list_cat_id%TYPE;
   mDeclar_ID     ad_papers.id%TYPE;            -- id заявления
   mContent_ID    ad_paper_extended.id%TYPE;    -- id содержания созданного документа
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги
   --mTkd_id          NUMBER;
   mTemp          NUMBER;
   mMessage       VARCHAR2(300);
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   oldConType     VARCHAR2(255); -- текущий тип подключения (voip, аналог и т.п.)
   newConType     VARCHAR2(255); -- выбранный тип подключения (voip, аналог и т.п.)

   mTD_ID         number;
   mRMDocID       number;
   iTarifficationType ad_paper_attr.value%type;
BEGIN
   IF (UPPER(newConnectionType) = 'GPON' AND UPPER(AuthenticationType) = 'ВЫДЕЛЕННЫЙ ИНТЕРФЕЙС') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Для СПД(статика) нет переключения на GPON');
   END IF;
   irbis_is_core.write_irbis_activity_log('CreateChangeTechTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ResourceID="' || TO_CHAR(ResourceID) ||
                            '", oldConnectionType="' || oldConnectionType ||
                            '", newConnectionType="' || newConnectionType ||
                            '", PhoneNumber="' || PhoneNumber ||
                            '", AuthenticationType="' || AuthenticationType ||
                            '", TarifficationType="' || TarifficationType ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '", DeviceType="' || DeviceType ||
                            '"',
                            RequestID);

   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'        THEN mClientID        := TO_NUMBER(x.value);
         WHEN 'AccountID'       THEN mAbonentID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractTCID'    THEN mTCID            := TO_NUMBER(x.value);
         WHEN 'ClientPhones'    THEN mContactPhone    := x.value;
         WHEN 'RequestCreator'  THEN mOperatorName    := x.value;
         ELSE NULL;
      END CASE;
   END LOOP;

  -- Поиск и проверка типа, филиала, состояния технической карты, адресов установки,
   --   абонотдела
   irbis_utl.assertNotNull(mTCID, 'Не указан номер технической карты!');
   irbis_is_core.get_tk_info(mTCID, mTelzone_ID, mTK_type);
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTCID;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');
   irbis_is_core.get_address_by_tk(mTCID, mAddress_ID, mAddress2_ID);
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
   mProc := 21;
   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mParentExists := 0;
   SELECT COUNT(id) INTO mParentExists
     FROM ad_papers p
    WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
      AND p.object_code = 'D';

   -- Разбор XML
      FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonType' THEN mContractCommonType  := x.VALUE;
         ELSE NULL;
      END CASE;
     END LOOP;

      IF UPPER(mContractCommonType) = 'КАБЕЛЬНОЕ ТЕЛЕВИДЕНИЕ' THEN
         oldConType:='КТВ';
         newConType:='ЦКТВ';
      ELSIF UPPER(mContractCommonType) = 'ЦИФРОВОЕ ТЕЛЕВИДЕНИЕ' THEN
         oldConType:='ЦКТВ';
         newConType:='КТВ';
      ELSE
         oldConType:=oldConnectionType;
         newConType:=newConnectionType;
      END IF;
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mParentExists > 0) THEN
      SELECT p.id INTO mDeclar_ID FROM ad_papers p
       WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
         AND p.object_code = 'D'
         AND ROWNUM < 2;
      irbis_utl.setPaper7Data(mDeclar_ID,
                              mClientID,
                              mAbonentID,
                              mAddress_ID,
                              mAddress2_ID,
                              mAbonementID,
                              '');
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="D";' ||
                                               'CONNECTION="' || UPPER(newConType) ||'";' ||
                                               'OLDCONNECTION="' || UPPER(oldConType) ||'";' ||
                                               'LINE="' || TO_CHAR(SIGN(ResourceID)) || '";' ||
                                               'AUTHENTICATION="' || UPPER(AuthenticationType) ||
                                               '"');
      irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
      irbis_utl.assertTrue((mCategID = 7), 'Функциональность не реализована');

      -- СПД
      IF (mTK_type IN (tk_type_dsl_old,
                       tk_type_dsl_new,
                       tk_type_wimax,
                       tk_type_etth,
                       tk_type_ethernet,
                       tk_type_gpon)) THEN
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
      ELSIF mTK_type IN (tk_type_tel, tk_type_voip, tk_type_sip) THEN
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
      -- охранная сигнализация
      ELSIF (mTK_type = tk_type_oxr) then
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_POH';
      ELSIF (mTK_type IN (tk_type_cable, tk_type_digitalcable)) then
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
      ELSIF (mTK_type = tk_type_iptv) then
         SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_IPTV';
      ELSE
         mCuslType_ID := NULL;
      END IF;

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '',
                                            mTelzone_ID, irbis_user_id, mCuslType_ID,
                                            mClientID, 'IRBIS_CONTRAGENT',
                                            mAbonentID, 'IRBIS_ABONENT',
                                            mAddress_ID, 'M2000_ADDRESS',
                                            mAddress2_ID, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);
      -- привязка абонемента, техкарты к заявлению
      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = mTCID
       WHERE id = mContent_ID;


      SELECT DECODE(TarifficationType, 'RADIUS accounting', 1, 'NetFlow по ip', 2, 'SNMP', 3, TarifficationType) INTO iTarifficationType FROM dual;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'AUTHENTICATION_TYPE', AuthenticationType, AuthenticationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TARIFFICATION_TYPE', iTarifficationType, TarifficationType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', newConType, newConType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_CONNECTION_TYPE', oldConType, oldConType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_TK_TYPE', mTK_type, mTK_type);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);

      -- корректировка отдела-создателя с учетом вида работ
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
   END IF;

   mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
   -- при переключении с традиционной телефонии
   --   на SIP по GPON, скопировать порты из ТК GPON
   --   на xDSL, скопировать порты DSL
   -- при смене технологии IPTV добавить в ТК порт и ЛД--убрали 27.12.2013
   IF mTK_type = tk_type_tel THEN
      -- убедиться, что переданный ресурс = порт или ЛД в ТК СПД по данному адресу
      SELECT NVL((SELECT t.tk_id
                    FROM rm_tk_data d, rm_tk t
                   WHERE d.tkd_resource = ResourceID
                     AND d.tkd_res_class IN (2, 7)
                     AND d.tkd_tk = t.tk_id
                     AND t.tk_type IN (tk_type_gpon, tk_type_dsl_new, tk_type_dsl_old, tk_type_etth, tk_type_ethernet, tk_type_wifiguest, tk_type_wimax)
                     AND t.tk_status_id != 0
                     AND EXISTS (SELECT 1 FROM rm_tk_address WHERE adr_tk = t.tk_id AND adr_id = mAddress_ID
                     AND ROWNUM < 2)), NULL)
        INTO mTemp FROM dual;
      -- скопировать все ресурсы из ТК СПД в качестве добавленных ресурсов
      IF mTemp IS NOT NULL THEN
        for v1 in (SELECT mTCID tk_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 npp
                     FROM (SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                             FROM rm_tk_data d
                            WHERE d.tkd_tk = mTemp
                              AND d.tkd_isdel = 0
                              AND d.tkd_is_new_res != 2  -- не удаляемый
                              -- ресурс не является заменяемым
                              AND NOT EXISTS (SELECT 1 FROM rm_tk_data d2 WHERE d2.tkd_tk = mTemp AND d2.tkd_parent_id = d.tkd_id )
                              -- ресурс не содержится уже в текущей ТК
                              AND NOT EXISTS (SELECT 1 FROM rm_tk_data d3 WHERE d3.tkd_tk = mTCID AND d3.tkd_res_class = d.tkd_res_class AND d3.tkd_resource = d.tkd_resource)
                            ) dd)
        loop
          mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => v1.tk_ID,
                                                         xClass_ID => v1.tkd_res_class,
                                                         xRes_ID   => v1.tkd_resource,
                                                         xPos      => v1.npp,
                                                         xDoc_ID   => mRMDocID,
                                                         xUser_ID  => irbis_user_id);
        end loop;
        /*        SELECT rm_gen_tk_data.nextval INTO mTkd_id FROM dual;
            INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                    tkd_isdel, tkd_is_new_res, tkd_parent_id)
            SELECT mTkd_id, mTCID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1,
                   0, 1, NULL
              FROM (SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                      FROM rm_tk_data d
                     WHERE d.tkd_tk = mTemp
                       AND d.tkd_isdel = 0
                       AND d.tkd_is_new_res != 2  -- не удаляемый
                       -- ресурс не является заменяемым
                       AND NOT EXISTS (SELECT 1 FROM rm_tk_data d2 WHERE d2.tkd_tk = mTemp AND d2.tkd_parent_id = d.tkd_id )
                       -- ресурс не содержится уже в текущей ТК
                       AND NOT EXISTS (SELECT 1 FROM rm_tk_data d3 WHERE d3.tkd_tk = mTCID AND d3.tkd_res_class = d.tkd_res_class AND d3.tkd_resource = d.tkd_resource)
                   ) dd;

                irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
      END IF;
   END IF;

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'OBJECT="T";' ||
                                            'CONNECTION="' || UPPER(newConType) ||'";' ||
                                            'OLDCONNECTION="' || UPPER(oldConType) ||'";' ||
                                            'LINE="' || TO_CHAR(SIGN(ResourceID)) || '";' ||
                                            'AUTHENTICATION="' || UPPER(AuthenticationType) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   /*-- Проверка
   IF (EquipmentNumber is not NULL) AND (mTK_type != tk_type_cable) THEN
    RAISE_APPLICATION_ERROR(-20001, 'Устройство предоставляется только для Цифрового телевидения!');
   END IF;*/

   -- Добавление устройства в ТК------------------------------------------------
  IF mTK_type = tk_type_cable THEN -- или TO DO: (UPPER(ConnectionType) = 'ЦИФРОВОЕ ТЕЛЕВИДЕНИЕ')
      SELECT NVL((SELECT e.equ_id
                    FROM rm_equipment e
                   WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1
                     AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 2535 AND LOWER(v.rvl_value) = LOWER(EquipmentNumber))
                   --  AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 2534 AND LOWER(v.rvl_value) = LOWER(DeviceType))
                 ), NULL) INTO mTemp FROM dual;
      irbis_utl.assertNotNull(mTemp, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);
      IF rm_pkg.GetResState(mTemp, 1) != 0 THEN
         SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                            '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                       FROM rm_tk_data d, rm_tk t
                      WHERE d.tkd_resource = mTemp
                        AND d.tkd_res_class = 1
                        AND d.tkd_tk = t.tk_id
                        AND t.tk_status_id != 0
                        AND rownum < 2), NULL)
           INTO mMessage FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Устройство не свободно, закреплено за ТК ' || mMessage);
      END IF;
      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTCID,
                                                     xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                     xRes_ID   => mTemp,
                                                     xPos      => 1,
                                                     xDoc_ID   => mRMDocID,
                                                     xUser_ID  => irbis_user_id);
      if (mTD_ID is null) then null; end if;

      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
      VALUES (rm_gen_tk_data.NEXTVAL, mTCID, 1, mTemp, 1, 0, 1, NULL)
        RETURNING tkd_id INTO mTkd_id;
      irbis_utl.addTKHisData(mTkd_id,irbis_user_id);*/
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
   END IF;

   -- Удаление устройства из ТК------------------------------------------------
  IF mTK_type = tk_type_digitalcable THEN -- или TO DO: (UPPER(ConnectionType) = 'ЦИФРОВОЕ ТЕЛЕВИДЕНИЕ')
      SELECT NVL((SELECT d.tkd_id
                    FROM rm_tk_data d
                   WHERE d.tkd_tk=mTCID
                     AND d.tkd_res_class=1
                     AND d.tkd_is_new_res=0
                 ), NULL) INTO mTemp FROM dual;
      irbis_utl.assertNotNull(mTemp, 'В тех.карте нет оборудования!');
      mTD_ID := RM_TK_PKG.LazyUnbindResourceFromData(xTK_ID     => mTCID,
                                                     xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                     xRes_ID    => 0,
                                                     xParent_ID => mTemp,
                                                     xPos       => 0,
                                                     xDoc_ID    => mRMDocID,
                                                     xUser_ID   => irbis_user_id);
      if (mTD_ID is null) then null; end if;

      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
      VALUES (rm_gen_tk_data.NEXTVAL, mTCID, 1, 0, 0, 0, 2, mTemp)
        RETURNING tkd_id INTO mTkd_id;
      irbis_utl.addTKHisData(mTkd_id,irbis_user_id);*/
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateChangeTechTC;

/*
 * Смена технологии подключения (21-й БП)
 * Создание наряда
 */
PROCEDURE CreateChangeTechOrder
(
   RequestID           IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontWish        IN DATE,     -- желаемая дата подключения
   DateMontComment     IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment      IN VARCHAR2, -- комментарий оператора к наряду
   NewContractCommonID IN NUMBER, -- идентификатор  нового абонемента
   MainParam           IN VARCHAR2 DEFAULT NULL  -- набор XML-данных, содержащий универсальные параметры
)
IS
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;

   CURSOR getNewTariffPlan(cRequestID NUMBER) IS
        SELECT tp.tariffplan_name
        FROM billing.trequestfield@irbis rf
        JOIN irb_ttariffplan tp ON rf.field_value = tp.object_no
        WHERE rf.request_id = cRequestID
        AND rf.field_id = 413280004;    --ID поля Новый ТП в заявке IRBIS

   mParent_ID    ad_papers.id%TYPE;
   mSubtype_ID   ad_subtypes.id%TYPE;
   mTelzone_ID   ad_papers.telzone_id%TYPE;
   mOtdel_ID     ad_papers.department_id%TYPE;
   mAbonOtdelID  ad_papers.department_id%TYPE;
   mChildSubtype ad_subtypes.id%TYPE;
   mOrder_ID     ad_papers.id%TYPE;
   mSourceOfSales   VARCHAR2(300);
   oldConnectionType   VARCHAR2(200); -- текущий тип подключения (voip, аналог и т.п.)
   newConnectionType   VARCHAR2(200); -- выбранный тип подключения (voip, аналог и т.п.)
   AuthenticationType  VARCHAR2(200);
   mResult       BOOLEAN;
   mLineID       NUMBER;
   mRequestCreator VARCHAR2(200);
   mTK_ID rm_tk.tk_id%TYPE;
   mTariffPlanName VARCHAR2(200);
   mNewTariffPlanName VARCHAR2(200);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateChangeTechOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", NewContractCommonID="' || NewContractCommonID ||
                            '"',
                            RequestID);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   IF MainParam IS NOT NULL THEN
    FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
              XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
           ) LOOP
     CASE x.param_name
        WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.VALUE;
        WHEN 'RequestCreator'     THEN mRequestCreator  := x.VALUE;
        WHEN 'ContractTCID'       THEN mTK_ID           := TO_NUMBER(x.VALUE);
        WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
        ELSE NULL;
     END CASE;
    END LOOP;
   END IF;

   -- поиск родительского документа
   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mSubtype_ID;
   CLOSE GetParentPaper;
   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

   ad_rules.get_attr_value(mParent_ID, 'CONNECTION_TYPE', mResult, newConnectionType);
   ad_rules.get_attr_value(mParent_ID, 'OLD_CONNECTION_TYPE', mResult, oldConnectionType);
   ad_rules.get_attr_value(mParent_ID, 'AUTHENTICATION_TYPE', mResult, AuthenticationType);

   SELECT COUNT(1) INTO mLineID
   FROM ad_paper_attr
   WHERE paper_id = mParent_ID AND strcod = 'CUSL_NUM';

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(21) || '";' ||
                                            'OBJECT="O";' ||
                                            'CONNECTION="' || UPPER(newConnectionType) || '";' ||
                                            'OLDCONNECTION="' || UPPER(oldConnectionType) || '";' ||
                                            'AUTHENTICATION="' || UPPER(AuthenticationType) || '";' ||
                                            'PARENT_SUBTYPE="' || TO_CHAR(mSubtype_ID) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   -- изменение ссылки на новый абонемент Irbis в техкарту
   IF (NewContractCommonID IS NOT NULL) THEN
     for v1 in (select u.usl_idext, u.usl_id, u.usl_name from rm_tk_usl u where u.usl_tk = mTK_ID) loop
       RM_TK_PKG.ChangeServiceData(xTK_ID      => mTK_ID,
                                   xExt_ID     => v1.usl_idext,
                                   xNewSvc_ID  => NewContractCommonID,
                                   xOldSvc_ID  => v1.usl_id,
                                   xNewSvcName => v1.usl_name);
       end loop;

      /*UPDATE rm_tk_usl SET usl_id = NewContractCommonID WHERE usl_tk=mTK_ID;*/
   END IF;

   IF mChildSubtype IN (9707, 10147, 10587, 10707, 11690, 11789) THEN
        --Поиск значения нового тарифного плана
        OPEN getNewTariffPlan(RequestID);
        FETCH getNewTariffPlan INTO mNewTariffPlanName;
        IF getNewTariffPlan%NOTFOUND THEN
            mNewTariffPlanName := NULL;
        END IF;
        CLOSE getNewTariffPlan;
        --Заполнение соответсвующего атриубта
        irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_TP', mNewTariffPlanName, mNewTariffPlanName);
   END IF;

   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mRequestCreator, mRequestCreator);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateChangeTechOrder;


/*
   Назначение: Определение технической возможности по адресу, типу услуги

   Примечание: процедура get_line (внутри GetTechnicalFeasibility) сделана по
               подобию этой процедуры, поэтому любые изменения здесь должны
               отражаться и там
   Входные параметры
     aADDRESS_ID    -  ID предположительного адреса установки услуги
     aCUSL_TYPE_ID  -  1 - телефон, 2 - прямой провод, 3 - DSL
     aTEL_NUMBER    -  номер телефона (при заполнении поля, предполагается,
                       что запрашивается услуга xDSL

   Возвращаемые параметры
     aRESULT        - Результат: 0 - нет тех возможности, 1 - есть тех возможность
     aTECH_DATA     - Технические данные по адресу (в виде строки)
     aSTATE      - код состояния (ошибки):
                   0 - нормальное завершение,
                   1 - общая ошибка,
                   2 - неправильно указан один из параметров
     aMESSAGE    - Сообщение об ошибке (в некоторых случаях может быть не заполнено)
*/
PROCEDURE get_technical_feasibility
(
   -- предположительный адрес установки
   aREGION_TYPE    IN  VARCHAR2,
   aREGION_NAME    IN  VARCHAR2,
   aREGZONE_TYPE   IN  VARCHAR2,
   aREGZONE_NAME   IN  VARCHAR2,
   aCITY_TYPE      IN  VARCHAR2,
   aCITY_NAME      IN  VARCHAR2,
   aDISTRICT_TYPE  IN  VARCHAR2,
   aDISTRICT_NAME  IN  VARCHAR2,
   aSTREET_TYPE    IN  VARCHAR2,
   aSTREET_NAME    IN  VARCHAR2,
   aHOUSE          IN  VARCHAR2,
   aCORPUS         IN  VARCHAR2,
   aSTROENIE       IN  VARCHAR2,
   aAPART          IN  VARCHAR2,
   aROOM           IN  VARCHAR2,

   aCUSL_TYPE_ID   IN  NUMBER,
   aTEL_NUMBER     IN  VARCHAR2,
   aRESULT         OUT NUMBER,
   aTECH_DATA      OUT VARCHAR2,
   aSTATE          OUT NUMBER,
   aMESSAGE        OUT VARCHAR2
)
IS
   mAddress_ID   ao_address.id%TYPE;

   CURSOR GetAddrUzl(aADDRESS_ID rm_service_zone.address_id%TYPE) IS
      SELECT uzl_id
        FROM rm_service_zone
       WHERE address_id = aADDRESS_ID;
   mAddrUzl      rm_service_zone.uzl_id%TYPE;
   --mStartObj     rm_comm_unit.uzl_obj%TYPE;
   mTechData     VARCHAR2(30000);
   mKross        rm_object.obj_id%TYPE;

BEGIN
   aRESULT      := 0;
   aTECH_DATA   := '';
   aSTATE       := 0;
   aMESSAGE     := '';

   -- 1. Определение адреса
   irbis_is_core.get_address_id(aREGION_TYPE,
                  aREGION_NAME,
                  aREGZONE_TYPE,
                  aREGZONE_NAME,
                  aCITY_TYPE,
                  aCITY_NAME,
                  aDISTRICT_TYPE,
                  aDISTRICT_NAME,
                  aSTREET_TYPE,
                  aSTREET_NAME,
                  aHOUSE,
                  aCORPUS,
                  aSTROENIE,
                  aAPART,
                  aROOM,
                  mADDRESS_ID,
                  aSTATE,
                  aMESSAGE);
   IF aSTATE > 0 THEN
      RETURN;
   END IF;
   -- 2. выяснение id коробочек, соответствующих адресу - Принадлежность RM_SERVICE_ZONE
   OPEN GetAddrUzl(mAddress_ID);
   FETCH GetAddrUzl INTO mAddrUzl;
   IF GetAddrUzl%NOTFOUND OR (mAddrUzl IS NULL) OR (mAddrUzl < 1) THEN
      aSTATE   := 2;
      aMESSAGE := 'Отсутствуют распределительные коробки, соответствующие указанному адресу!';
      CLOSE GetAddrUzl;
      RETURN;
   END IF;
   CLOSE GetAddrUzl;

   -- 3. определение id объекта (дома)
   --SELECT uzl_obj INTO mStartObj FROM rm_comm_unit WHERE uzl_id = mAddrUzl;


   -- 4. Поиск пути до ближайшей АТС (кросс, class=1)
   -- Поиск ведется по узлам через связи к объектам, имеющим подходящий класс
   -- т.е. объекты с классом меньше текущего не интересуют - от шкафа к шкафу, но не к дому
   --   Поиск завершается, когда будет
   --   т.е. от коробки к шкафам. От шкафов к кроссам и другим шкафам НО НЕ к коробкам.

   mTechData := irbis_is_core.generate_cross_line(mAddress_ID, 2, 2, mKross);
   IF LENGTH(mTechData) > 0 THEN
--      IF LENGTH(mTechData) > 2000 THEN
--         aTECH_DATA := SUBSTR(mTechData, 1, 1900);
--      ELSE
         aTECH_DATA := mTechData;
--      END IF;
      aSTATE     := 0;
      aRESULT    := 1;
      aMESSAGE   := 'Техническая возможность есть';
   ELSE
      aSTATE     := 0;
      aRESULT    := 0;
      aMESSAGE   := 'Нет технической возможности';
   END IF;

END get_technical_feasibility;

-- Обработка одного документа М2000: отправка уведомления в систему IRBiS
-- Функция НЕ обрабатывает исключения
-- Функция НЕ проверяет текущее состояние документа в списке соответствий, т.е.
--    пытается отправить уведомление, даже если оно уже было отправлено ранее.
-- Функция изменяет текущее состояние документа в списке соответствий
--    документов и заявок IRBiS
-- Возвращаемые значения:
--    0 = уведомление не было отправлено
--    1 = уведомление было отправлено
--    Кроме того, разумеется, возможны исключительные ситуации - это забота вызывающего
FUNCTION SendToIrbis (
   aPAPER      IN NUMBER,    -- ID документа M2000
   aIS_SUCCESS IN NUMBER     -- 1 - отправить уведомление об успехе / 0 - отправить о неуспехе
) RETURN NUMBER
IS
   CURSOR GetPaperInfo(aID  NUMBER) IS
      SELECT r.id, r.paper_id, r.request_id, r.state_id, r.attempts, r.last_attempt,
             r.proc,
             (SELECT p.object_code FROM ad_papers p WHERE p.id = aID) object_code
        FROM irbis_request_papers r
       WHERE r.paper_id = aID;

   mItemID    irbis_request_papers.id%TYPE;
   mPaperID   irbis_request_papers.paper_id%TYPE;
   mRequestID irbis_request_papers.request_id%TYPE;
   mStateID   irbis_request_papers.state_id%TYPE;
   mAttempts  irbis_request_papers.attempts%TYPE;
   mLastTime  irbis_request_papers.last_attempt%TYPE;
   mProc      irbis_subtypes.proc%TYPE;
   mObject    ad_papers.object_code%TYPE;
   mPnumber   ad_papers.pnumber%TYPE;
   mProcName  VARCHAR2(100);
   mNumberVATS VARCHAR2(300);
   mSubtypeID ad_papers.subtype_id%TYPE;

   CURSOR GetPaperTK (aPAPER  ad_papers.id%TYPE) IS
      SELECT DECODE(ad_get.get_paper_category(aPAPER),
                    3, (SELECT c.bron_id FROM ad_paper_content c WHERE c.paper_id = aPAPER AND ROWNUM < 2),
                    7, (SELECT e.tk_id FROM ad_paper_extended e WHERE e.paper_id = aPAPER AND ROWNUM < 2),
                    NULL) tk_id
        FROM dual;
   mTK         rm_tk.tk_id%TYPE;

   mLineID     rm_tk_data.tkd_resource%TYPE;
   mPortID     rm_tk_data.tkd_resource%TYPE;

   -- номер телефона из ТК в 10-значном виде
   CURSOR GetPhone(aTK rm_tk_data.tkd_tk%TYPE) IS
      SELECT DECODE(LENGTH(n.num_number),
                    10, '',
                    (SELECT TO_CHAR(t.numcode) FROM list_telcode t WHERE t.id = n.num_telcode)) ||
             n.num_number
        FROM rm_tk_data d, rm_numbers n
       WHERE d.tkd_tk = aTK
         AND n.num_id = d.tkd_resource
         AND d.tkd_res_class = 6
         AND d.tkd_is_new_res = 0;
   -- НОВЫЙ телефон из ТК в 10-значном виде (при большом переносе / замене номера)
   CURSOR GetNewPhone(aTK rm_tk_data.tkd_tk%TYPE) IS
      SELECT DECODE(LENGTH(n.num_number),
                    10, '',
                    (SELECT TO_CHAR(t.numcode) FROM list_telcode t WHERE t.id = n.num_telcode)) ||
             n.num_number
        FROM rm_tk_data d, rm_numbers n
       WHERE d.tkd_tk = aTK
         AND n.num_id = d.tkd_resource
         AND d.tkd_res_class = 6
         AND d.tkd_is_new_res = 1;
   CURSOR GetPhoneNewFirst(aTK rm_tk_data.tkd_tk%TYPE) IS
      SELECT DECODE(LENGTH(n.num_number),
                    10, '',
                    (SELECT TO_CHAR(t.numcode) FROM list_telcode t WHERE t.id = n.num_telcode)) ||
             n.num_number
        FROM rm_tk_data d, rm_numbers n
       WHERE d.tkd_tk = aTK
         AND n.num_id = d.tkd_resource
         AND d.tkd_res_class = 6
         AND d.tkd_is_new_res != 2
      ORDER BY d.tkd_is_new_res DESC;
   mPhone      rm_numbers.num_number%TYPE;

   CURSOR GetTKResource(aTK    rm_tk_data.tkd_tk%TYPE,
                        aClass rm_tk_data.tkd_res_class%TYPE) IS
      SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = aClass AND tkd_isdel = 0 AND tkd_is_new_res = 0;
   CURSOR GetTKNewRes(aTK    rm_tk_data.tkd_tk%TYPE,
                      aClass rm_tk_data.tkd_res_class%TYPE) IS
      SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = aClass AND tkd_isdel = 0 AND tkd_is_new_res = 1;
   CURSOR GetTKResNewFirst(aTK    rm_tk_data.tkd_tk%TYPE,
                           aClass rm_tk_data.tkd_res_class%TYPE) IS
      SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = aClass AND tkd_isdel = 0 AND tkd_is_new_res != 2
      ORDER BY tkd_is_new_res DESC;


   -- граница облуживания
   CURSOR GetServArea(aPAPER ad_paper_attr.paper_id%TYPE) IS
      SELECT value_long
        FROM ad_paper_attr
       WHERE paper_id = aPAPER
         AND UPPER(strcod) = 'GRANICA_OBSLUG';
   mServArea  ad_paper_attr.value_long%TYPE;

   mRKPlace     VARCHAR2(250);

   CURSOR GetMakeDate(aPAPER ad_paper_attr.paper_id%TYPE) IS
      SELECT TO_DATE(value, 'DD.MM.YYYY HH24:MI:SS')
        FROM ad_paper_attr
       WHERE paper_id = aPAPER
         AND UPPER(strcod) = 'MAKE_DATE';
   CURSOR GetMaxDate(aPAPER ad_paper_attr.paper_id%TYPE) IS
      SELECT MAX(TO_DATE(value, 'DD.MM.YYYY HH24:MI:SS'))
        FROM ad_paper_attr
       WHERE paper_id = aPAPER
         AND UPPER(strcod) IN ('DATEMONT_WISH', 'MAKE_DATE');
   CURSOR GetCloseDate(aPAPER ad_paper_history.paper_id%TYPE) IS
      SELECT h.event_date
        FROM ad_paper_history h
       WHERE h.paper_id = aPAPER
         AND h.state_id = 'C'
         AND h.state_id_old IN ('W', 'Q', 'F')
      ORDER BY h.id DESC;

   mDate       DATE;
   mTemp       NUMBER;
   mNum        VARCHAR2(100);
   mResClass   NUMBER;

   mTK_type    rm_tk.tk_type%TYPE;
   mTK_telzone rm_tk.tk_telzone%TYPE;

   CURSOR GetCloseReason(aPAPER ad_papers.id%TYPE) IS
      --SELECT SUBSTR(r.name || ': ' || h.remm, 1, 255) AS reason
      SELECT SUBSTR(
                DECODE(TRIM(h.remm), '', '',
                       REPLACE(name, 'Техническая возможность есть', 'ТВ есть') || ': ' || h.remm),
                1, 300) AS reason
        FROM ad_paper_history h, ad_list_resolution r
       WHERE h.id = (SELECT MAX(hh.id)
                       FROM ad_paper_history hh
                      WHERE hh.paper_id = aPAPER
                        AND hh.state_id = 'C'
                        AND hh.state_id_old = 'W')
         AND r.id = h.resolution_id;
   mResName    VARCHAR2(300); --VARCHAR2(255);
   mLineLength NUMBER;
   mPPNumb     VARCHAR2(500);
   mRezObsl    ad_paper_attr.value_long%TYPE;

   mEquipID          rm_tk_data.tkd_resource%TYPE; -- идентификатор оборудования
   mEquipmentLicense VARCHAR2(100); -- внутренний номер устройства ЦКТВ
    CURSOR GetTKResourceLast(aTK    rm_tk_data.tkd_tk%TYPE, --MCreateChangeModemTS
                          aClass rm_tk_data.tkd_res_class%TYPE) IS
    SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = aClass AND tkd_isdel = 0 AND tkd_is_new_res = 0 order by tkd_id desc;
   -- причина направления в отдел-создатель
   CURSOR GetReasonToOS(aPAPER ad_paper_attr.paper_id%TYPE) IS
      SELECT value
        FROM ad_paper_attr
       WHERE paper_id = aPAPER
         AND UPPER(strcod) = 'REASON_TO_OS';
   mReasonToOS  ad_paper_attr.value_long%TYPE;
   mActionType NUMBER; --MReturnEquip
   m_get_value_result BOOLEAN; --MRefusalEquip
   m_attr_value ad_paper_attr.VALUE_LONG%TYPE; --значение атрибута --MRefusalEquip

   -- формирование строки результата обследования
   FUNCTION GetRezObsl(aPaperID ad_papers.id%TYPE) RETURN VARCHAR2 IS
   mObsl   ad_paper_attr.value%TYPE;
   mDopRab ad_paper_attr.value%TYPE;
   mResult ad_paper_attr.value_long%TYPE;
   BEGIN
      SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = aPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mObsl FROM dual;
      SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = aPaperID AND strcod = 'DOP_RABOTA'), NULL) INTO mDopRab FROM dual;
      IF (mObsl IS NULL AND mDopRab IS NULL) THEN
         mResult := '';
      ELSIF (mObsl IS NULL) THEN
         mResult := 'СВЕРХПОСТР: ' || mDopRab;
      ELSIF (mDopRab IS NULL) THEN
         mResult := mObsl;
      ELSE
         mResult := mObsl || '. СВЕРХПОСТР: ' || mDopRab;
      END IF;
      RETURN mResult;
   END GetRezObsl;

BEGIN
   -- проверка входных параметров
   IF (aPAPER IS NULL) OR (aPAPER <= 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан документ для отправки');
   END IF;
   IF NOT (aIS_SUCCESS IN (0, 1)) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Неизвестный признак успешности');
   END IF;

   -- инфо по документу
   OPEN GetPaperInfo(aPAPER);
   FETCH GetPaperInfo INTO mItemID, mPaperID, mRequestID, mStateID, mAttempts,
                           mLastTime, mProc, mObject;
   IF GetPaperInfo%NOTFOUND THEN
      CLOSE GetPaperInfo;
      RAISE_APPLICATION_ERROR(-20001, 'Документу не соответствует заявка IRBiS');
   END IF;
   CLOSE GetPaperInfo;
   IF mProc IS NULL THEN
      mProc := irbis_is_core.get_proc_by_paper(aPAPER);
   END IF;

   IF aIS_SUCCESS = 1 THEN
      -- установка Телефона
      IF    mProc = irbis_utl.BP_TEL THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                         WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                       0)
              INTO mTemp
              FROM dual;

            IF mTemp = 1 THEN
               mLineID  := 1;
               mRKPlace := NULL;
            ELSE
               SELECT NVL((SELECT tkd_resource
                             FROM (SELECT tkd_resource FROM rm_tk_data d, rm_equip_port p
                                    WHERE d.tkd_tk = mTK
                                      AND d.tkd_res_class = 2
                                      AND d.tkd_isdel = 0
                                      AND d.tkd_is_new_res IN (0, 1)
                                      AND p.prt_id = d.tkd_resource
                                      -- Ethernet, FastEthernet, Сектор WiMAX, GPON, FC optic
                                      AND p.prt_type IN (43, 543, 843, 1023, 383)
                                   ORDER BY d.tkd_is_new_res DESC)
                            WHERE ROWNUM < 2), NULL)
                 INTO mPortID FROM dual;

               IF mPortID IS NOT NULL THEN
                  mLineID := mPortID;
               ELSE
                  OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
                  mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
               END IF;
            END IF;

            --OPEN GetPhone(mTK);        FETCH GetPhone INTO mPhone; CLOSE GetPhone;
            OPEN GetPhoneNewFirst(mTK); FETCH GetPhoneNewFirst INTO mPhone; CLOSE GetPhoneNewFirst;
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);

            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfPSTNTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mLineID) ||
                                     '", PhoneNumb="' || mPhone ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfPSTNTCComplete@irbis(:RequestID, :TC, :LineID, :PhoneNumb, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mPhone, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineID;
         END IF;
      -- установка прямого провода
      ELSIF mProc = 2 THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                         WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                       0)
              INTO mTemp
              FROM dual;

            IF mTemp = 1 THEN
               mLineID  := 1;
               mRKPlace := NULL;
            ELSE
               OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            END IF;
            -- граница облуживания
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            IF mLineID > 1 THEN mLineLength := rm_pkg.getlinelen(mLineID); END IF;
            SELECT NVL((SELECT v.value
                          FROM rm_tk_property p, rm_tk_prop_value v
                         WHERE p.strcod = 'PP_NUM'
                           AND v.prop_id = p.id
                           AND v.tk_id = mTK),
                       '')
              INTO mPPNumb
              FROM dual;
            irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            IF mTK_type = tk_type_vats THEN
                SELECT ac.account_numb||'-'||cc.contract_numb||'.vatstest.letai.ru'
                INTO mPPNumb
                FROM ad_paper_extended ext
                JOIN irb_tcontractcommon cc ON ext.usl_id = cc.object_no
                JOIN irb_taccount ac ON cc.account_id = ac.object_no
                WHERE ext.paper_id = mPaperID;
                --mPPNumb := mTK; -- Чтобы для ВАТС не возникало ошибок, условно передаем ID ТК
            END IF;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreateDirWireTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mLineID) ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", PPNumb="' || mPPNumb ||
                                     '", LineLength="' || TO_CHAR(mLineLength) ||
                                     '", Prim="' || mRezObsl ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreateDirWireTCComplete@irbis(:RequestID, :TC, :LineID, :ServiceZone, :RKFloor, :PPNumb, :LineLength, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mServArea, IN mRKPlace, IN mPPNumb, IN mLineLength, IN mRezObsl;

         -- успех в наряде
         ELSIF mObject = 'O' THEN
            mDate := SYSDATE;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                         WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                       0)
              INTO mTemp
              FROM dual;

            IF mTemp = 1 THEN
               mLineID  := 1;
            ELSE
               OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
            END IF;
            IF mLineID > 1 THEN mLineLength := rm_pkg.getlinelen(mLineID); END IF;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ConnectDirWireOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", LineLength="' || mLineLength ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ConnectDirWireOrderComplete@irbis(:RequestID, :OrderFinishDate, :LineLength, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineLength, IN mResName;
         END IF;
      -- установка СПД
      ELSIF mProc = irbis_utl.BP_INTERNET THEN
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                      WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                    0)
           INTO mTemp
           FROM dual;

         IF mTemp = 1 THEN
            mLineID  := 1;
            mRKPlace := NULL;
         ELSE
            -- в случае установки "Оптики в дом", WiMax, Ethernet
            -- в качестве базового ресурса должен быть передан порт, а не ЛД
            irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            IF mTK_type IN (tk_type_etth, tk_type_wimax, tk_type_ethernet, tk_type_gpon, tk_type_wifimetroethernet, tk_type_wifistreet) THEN
               OPEN GetTKResNewFirst(mTK, 2); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := NULL;
            ELSIF mTK_type = tk_type_wifiguest THEN
               OPEN GetTKResNewFirst(mTK, 1); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := NULL;
            ELSE
               OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            END IF;
         END IF;
         -- успех в техсправке
         IF    mObject = 'T' THEN

            -- граница облуживания
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfTCComplete@irbis(:RequestID, :TC, :ResourceID, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
--                              '   Billing.Amfitel.CreationOfTCComplete@irbis(:RequestID, :TC, :ResourceID, :ServiceZone, :RKFloor, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
--                              USING IN mRequestID, IN mTK, IN mLineID, IN mServArea, IN mRKPlace, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            mDate := SYSDATE;
          /*  irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineID;*/
          -- Получаем из атрибута информацию о подключении интернета с/без оборудования --MRefusalEquip
            ad_rules.get_attr_value (mPaperID,'CONN_WITH_EQUIP',m_get_value_result,m_attr_value);
            IF (m_get_value_result) AND (m_attr_value='0') THEN
             irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ConnOrderCompleteEquipReturn',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", Reason="' || mResName ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ConnOrderCompleteEquipReturn@irbis(:RequestID, :OrderFinishDate, :Reason, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mResName, IN mLineID;
            ELSE
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis_main(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineID;
            END IF;
         END IF;
      -- успех при снятии
      ELSIF mProc = 4 THEN
         SELECT subtype_id
         INTO mSubtypeID
         FROM ad_papers
         WHERE id = mPaperID;

         IF mSubtypeID = 12006 THEN
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            SELECT pnumber INTO mPnumber FROM ad_papers WHERE id = mPaperID;
            irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_OVN_DISABLE.OVN_m2000_Success',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Prim="' || mResName ||
                                  '"',
                                  mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   TTK_CRM_GROUP.PKG_OVN_DISABLE.OVN_m2000_Success@irbis(:RequestID, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN 'Наряд Н-'||mPnumber||'. '||mResName;
         ELSE
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TCCloseComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.TCCloseComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate;
         END IF;
      -- успех в заявке на обследование
      ELSIF mProc = 5 THEN
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
         -- граница облуживания
         OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
         mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfTCComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", TC="' || TO_CHAR(mTK) ||
                                  '", ResourceID="' || TO_CHAR(mLineID) ||
                                  '", ServiceZone="' || mServArea ||
                                  '", RKFloor="' || mRKPlace ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.CreationOfTCComplete@irbis(:RequestID, :TC, :ResourceID, :ServiceZone, :RKFloor); ' ||
                           'END;'
                           USING IN mRequestID, IN mTK, IN mLineID, IN mRKPlace;
      -- Изменение оператора дальней связи (категории АОН)
      ELSIF mProc = 6 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.SetPhoneCategoryComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.SetPhoneCategoryComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate;
      -- Изменение статуса исходящей связи
      ELSIF mProc = 7 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.SetSetCallBarringStateComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.SetSetCallBarringStateComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate;
      -- Постановка на охранную сигнализацию
      ELSIF mProc = 8 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate;   CLOSE GetMakeDate;
         OPEN GetPaperTK(mPaperID);  FETCH GetPaperTK  INTO mTK;     CLOSE GetPaperTK;
         --OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
         SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                      WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                    0)
           INTO mTemp
           FROM dual;
         IF mTemp = 1 THEN
            mLineID  := 1;
         ELSE
            OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
         END IF;

         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PlantAlarmOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '", TC="' || TO_CHAR(mTK) ||
                                  '", ResourceID="' || TO_CHAR(mLineID) ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.PlantAlarmOrderComplete@irbis(:RequestID, :OrderFinishDate, :TC, :ResourceID); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate, IN mTK, IN mLineID;
      -- Перенос (малый или большой)
      ELSIF (mProc = 9) OR (mProc = 10) THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         OPEN GetPaperTK(mPaperID);  FETCH GetPaperTK  INTO mTK;     CLOSE GetPaperTK;

         SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                      WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                    0)
           INTO mTemp
           FROM dual;

         IF mTemp = 1 THEN
            mLineID  := 1;
            mRKPlace := NULL;
         ELSE
            -- в случае установки "Оптики в дом", WiMax, Ethernet
            -- в качестве базового ресурса должен быть передан порт, а не ЛД
            irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            IF mTK_type IN (tk_type_etth, tk_type_wimax, tk_type_ethernet, tk_type_gpon, tk_type_iptv, tk_type_cable, tk_type_voip, tk_type_digitalcable, tk_type_wifimetroethernet) THEN  --24.08.2012    Balmasova
               OPEN GetTKResNewFirst(mTK, 2); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := NULL;
            ELSIF mTK_type = tk_type_wifiguest THEN
               OPEN GetTKResNewFirst(mTK, 1); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := NULL;
            ELSIF mTK_type = tk_type_sip THEN
               -- Базовый ресурс - линия (Sip устанолен по xDSL) либо порт (Sip установлен по Ethernet/WiMAX)
               SELECT NVL((SELECT tkd_resource FROM
                             (SELECT tkd_resource FROM rm_tk_data d, rm_equip_port p
                               WHERE d.tkd_tk = mTK AND d.tkd_res_class = 2
                                 AND d.tkd_isdel = 0 AND d.tkd_is_new_res in (0,1)
                                 AND p.prt_id = d.tkd_resource
                                 -- тип порта : Ethernet, FastEthernet, Сектор WiMAX
                                 AND p.prt_type IN (43, 543, 843, 1023, 383,263)
                              ORDER BY d.tkd_is_new_res DESC)
                            WHERE ROWNUM < 2), NULL)
                 INTO mPortID FROM dual;
               IF mPortID IS NOT NULL THEN
                  mLineID := mPortID;
                  mRKPlace := NULL;
               ELSE
                  OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst; --изменила после
                  mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
               END IF;
            ELSE
               OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            END IF;
         END IF;

         -- Для ВАТС нет ресурса для передачи (несколько номеров только)
         IF mTK_type = tk_type_vats THEN
            mLineID := 1;
         END IF;

/*         -- Поиск НОВЫХ ЛД, теоретически новые могут отсутствовать
         OPEN GetTKNewRes(mTK, 7); FETCH GetTKNewRes  INTO mLineID; CLOSE GetTKNewRes;
         IF mLineID IS NULL THEN OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource; END IF;*/
         -- успех в техсправке
         IF    mObject = 'T' THEN
            -- уточнение бизнес-процесса (теоретически может быть скорректирован оператором)
            SELECT NVL((SELECT 11 - TO_NUMBER(value) FROM ad_paper_attr
                         WHERE paper_id = mPaperID AND strcod = 'TRUNSFER_TYPE'),
                       mProc)
              INTO mProc
              FROM dual;

            -- при большом переносе из ТК выбирается НОВЫЙ номер телефона,
            --   однако в некоторых случаях его не будет - нужно брать действующий
            IF (mProc = 10) THEN
               OPEN GetNewPhone(mTK);   FETCH GetNewPhone INTO mPhone; CLOSE GetNewPhone;
            END IF;
            IF (mPhone IS NULL) AND (mTK_type in (1,183)) THEN
               OPEN GetPhone(mTK);      FETCH GetPhone INTO mPhone; CLOSE GetPhone;
            END IF;
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TransferOfTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mLineID) ||
                                     '", PhoneNumb="' || mPhone ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.TransferOfTCComplete@irbis(:RequestID, :TC, :LineID, :PhoneNumb, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mPhone, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
/*            OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;*/
            mLineLength := rm_pkg.getlinelen(mLineID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TransferOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", LineLength="' || TO_CHAR(mLineLength) ||
                                     '", Prim="' || mResName ||
                                     '", LineID="' || mLineID ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
--                              '   Billing.Amfitel.TransferOrderComplete@irbis(:RequestID, :OrderFinishDate, :LineLength, :Prim); ' ||
                              '   Billing.Amfitel.TransferOrderComplete@irbis(:RequestID, :OrderFinishDate, :LineLength, :LineID, :Prim); ' ||
                              'END;'
--                              USING IN mRequestID, IN mDate, IN mLineLength, IN mResName;
                              USING IN mRequestID, IN mDate, IN mLineLength, IN mLineID, IN mResName;
         END IF;
      -- Замена телефонного номера
      ELSIF mProc = 11 THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            OPEN GetNewPhone(mTK);   FETCH GetNewPhone INTO mNum; CLOSE GetNewPhone;
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;

            OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
            mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ModificationOfTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", PhoneNumb="' || mNum ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ModificationOfTCComplete@irbis(:RequestID, :PhoneNumb, :ServiceZone, :RKFloor); ' ||
                              'END;'
                              USING IN mRequestID, IN mNum, IN mServArea, IN mRKPlace;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CommutationTelNumOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CommutationTelNumOrderComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate;
         END IF;
      -- Перекроссировка охранной сигнализации
      ELSIF mProc = 12 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate;   CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ReCrossAlarmOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ReCrossAlarmOrderComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate;
      -- Переоформление
      /*ELSIF mProc = 13 THEN
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.RenewalTCComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", TC="' || TO_CHAR(mTK) ||
                                  '", LineID="' || TO_CHAR(mLineID) ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.RenewalTCComplete@irbis(:RequestID, :TC, :LineID); ' ||
                           'END;'
                           USING IN mRequestID, IN mTK, IN mLineID;*/
      -- Установка и снятие параллельного аппарата
      ELSIF mProc IN (14, 25) THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ParallelAppOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '", Prim="' || TO_CHAR(mResName) ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ParallelAppOrderComplete@irbis(:RequestID, :OrderFinishDate, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate, IN mResName;
      -- Бронирование телефонного номера
      ELSIF mProc = 15 THEN
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         OPEN GetPhone(mTK);        FETCH GetPhone INTO mPhone; CLOSE GetPhone;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfResNumTCComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", TC="' || TO_CHAR(mTK) ||
                                  '", PhoneNumb="' || mPhone ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.CreationOfResNumTCComplete@irbis(:RequestID, :TC, :PhoneNumb); ' ||
                           'END;'
                           USING IN mRequestID, IN mTK, IN mPhone;
      -- Снятие с брони телефонного номера
      ELSIF mProc = 16 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate;   CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ExemptionResNumOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ExemptionResNumOrderComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate;
      --<nell 05 10 2010>
      -- установка Sip
      ELSIF mProc IN (17, 29) THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;

            SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                         WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                       0)
              INTO mTemp
              FROM dual;

            IF mTemp = 1 THEN
               mLineID  := 1;
               mRKPlace := NULL;
            ELSE
               -- Базовый ресурс - линия (Sip устанолен по xDSL) либо порт (Sip установлен по Ethernet/WiMAX)
               SELECT NVL((SELECT tkd_resource FROM
                             (SELECT tkd_resource FROM rm_tk_data d, rm_equip_port p
                               WHERE d.tkd_tk = mTK AND d.tkd_res_class = 2
                                 AND d.tkd_isdel = 0 AND d.tkd_is_new_res IN (0, 1)
                                 AND p.prt_id = d.tkd_resource
                                 -- тип порта : Ethernet, FastEthernet, Сектор WiMAX
                                 AND p.prt_type IN (43, 543, 843, 1023, 383, 263,793)
                              ORDER BY d.tkd_is_new_res DESC)
                            WHERE ROWNUM < 2), NULL)
                 INTO mPortID FROM dual;
               IF mPortID IS NOT NULL THEN
                  mLineID := mPortID;
               ELSE
                  --OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
                  OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
               END IF;
               mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            END IF;
            --OPEN GetPhone(mTK);        FETCH GetPhone INTO mPhone; CLOSE GetPhone;
            OPEN GetPhoneNewFirst(mTK); FETCH GetPhoneNewFirst INTO mPhone; CLOSE GetPhoneNewFirst;
            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            CASE mProc
               WHEN 17    THEN mProcName := 'CreationOfPSTNTCComplete';
               WHEN 29    THEN mProcName := 'CreationOfSIPTCComplete';
               ELSE NULL;
            END CASE;

            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.' || mProcName,
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mLineID) ||
                                     '", PhoneNumb="' || mPhone ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.' || mProcName || '@irbis(:RequestID, :TC, :LineID, :PhoneNumb, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mPhone, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineID;
         END IF;
      --</nell 05 10 2010>
      -- Подключение IP TV
      ELSIF mProc = 18 THEN
         -- Определение базового ресурса (start)
         SELECT NVL((
               SELECT DECODE(value,
                             'IP TV xDSL', 7,
                             'IP TV Ethernet', 2,
                             'IP TV GPON', 2,   --31.08.2012 Balmasova
                             'IP TV wifistreet', 2,
                             -1)
                 FROM ad_paper_attr
                WHERE paper_id = (SELECT parent_id FROM ad_papers WHERE id = mPaperID)
                  AND strcod   = 'CONNECTION_TYPE'
                    ), -1)
           INTO mResClass
           FROM dual;
         IF mResClass = -1 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить тип подключения');
         END IF;

         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         SELECT NVL((SELECT TO_NUMBER(value) FROM ad_paper_attr
                      WHERE paper_id = mPaperID AND strcod = 'WITHOUT_BASIC_RES'),
                    0)
           INTO mTemp
           FROM dual;

         IF (mTemp = 1) AND (mResClass = 7) THEN
            mLineID  := 1;
            mRKPlace := NULL;
         ELSE
            OPEN GetTKResNewFirst(mTK, mResClass); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
/*
            -- базовый ресурс зависит от типа подключения
            OPEN GetTKResource(mTK, mResClass); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;

            -- не удалось найти базовый ресурс в ТК, но возможно он был добавлен
            IF (mLineID IS NULL) THEN
                OPEN GetTKNewRes(mTK, mResClass); FETCH GetTKNewRes INTO mLineID; CLOSE GetTKNewRes;
            END IF;
*/
            mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
         END IF;
         -- -- Определение базового ресурса (end)

         -- успех в техсправке
         IF    mObject = 'T' THEN

            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfTCComplete@irbis(:RequestID, :TC, :ResourceID, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mLineID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mLineID;
         END IF;
      -- Подключение КТВ и цифрового КТВ
      ELSIF mProc in (19,30) THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            -- в качестве первичного ресурса должен передаваться порт
            OPEN GetTKResource(mTK, 2); FETCH GetTKResource INTO mPortID; CLOSE GetTKResource;
            OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
            mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;

            OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            --получение внутреннего номера оборудования
            IF mTK_type = tk_type_digitalcable THEN
             OPEN GetTKResource(mTK, 1); FETCH GetTKResource INTO mEquipID; CLOSE GetTKResource;
               SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                           WHERE v.rvl_res = mEquipID
                             AND v.rvl_prop_id = rp.rpr_id --id свойства
                             AND v.rvl_res_type = rp.rpr_restype --тип оборудования
                             AND rp.rpr_strcod = 'S_C_NO'
                             AND rp.rpr_restype = 2574), -- тип оборудования "Оборудование ЦКТВ"), --TO DO: WORK 2574
                    NULL) INTO mEquipmentLicense FROM dual;
            ELSIF mTK_type = tk_type_cable THEN
            mEquipmentLicense := NULL;
            END IF;
            IF mTK_type = tk_type_ckpt THEN
            mPortID:=1;
            END IF;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfKTVTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", ResourceID="' || TO_CHAR(mPortID) ||
                                     '", EquipmentLicense="' || TO_CHAR(mEquipmentLicense) || --внутренний номер оборудования
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfKTVTCComplete@irbis(:RequestID, :TC, :ResourceID, :EquipmentLicense, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mPortID, IN mEquipmentLicense, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mPortID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mPortID;
         END IF;
      --<nell 05 10 2010>
      -- установка VoIP
      ELSIF mProc = 20 THEN
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         OPEN GetTKResNewFirst(mTK, 2); FETCH GetTKResNewFirst INTO mPortID; CLOSE GetTKResNewFirst;
         OPEN GetPhoneNewFirst(mTK); FETCH GetPhoneNewFirst INTO mPhone; CLOSE GetPhoneNewFirst;
         OPEN GetServArea(mPaperID); FETCH GetServArea INTO mServArea; CLOSE GetServArea;
         OPEN GetTKResNewFirst(mTK, 7); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
         mRKPlace := irbis_is_core.get_rk_place_by_ld(mLineID);
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         mRezObsl := GetRezObsl(mPaperID);
         -- успех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfPSTNTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mPortID) ||
                                     '", PhoneNumb="' || mPhone ||
                                     '", ServiceZone="' || mServArea ||
                                     '", RKFloor="' || mRKPlace ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfPSTNTCComplete@irbis(:RequestID, :TC, :LineID, :PhoneNumb, :ServiceZone, :RKFloor, :RezObsl, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mPortID, IN mPhone, IN mServArea, IN mRKPlace, IN mRezObsl, IN mResName;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", ResourceID="' || TO_CHAR(mPortID) ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.PrimaryConnectionOrderComplete@irbis(:RequestID, :OrderFinishDate, :ResourceID); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mPortID;
         END IF;
      --</nell 05 10 2010>
      -- Смена технологии подключения
      ELSIF mProc = 21 THEN
         -- успех в техсправке
         IF    mObject = 'T' THEN
            OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
            OPEN GetNewPhone(mTK);     FETCH GetNewPhone INTO mPhone; CLOSE GetNewPhone;
            --OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
            OPEN GetTKResNewFirst(mTK, 2); FETCH GetTKResNewFirst INTO mLineID; CLOSE GetTKResNewFirst;
            OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
            --SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = mPaperID AND strcod = 'REZ_OBSLED'), NULL) INTO mRezObsl FROM dual;
            mRezObsl := GetRezObsl(mPaperID);
            irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            --получение внутреннего номера оборудования
            IF mTK_type in (tk_type_digitalcable) THEN
             OPEN GetTKNewRes(mTK, 1); FETCH GetTKNewRes INTO mEquipID; CLOSE GetTKNewRes;
               SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                           WHERE v.rvl_res = mEquipID
                             AND v.rvl_prop_id = rp.rpr_id --id свойства
                             AND v.rvl_res_type = rp.rpr_restype --тип оборудования
                             AND rp.rpr_strcod = 'S_C_NO'
                             AND rp.rpr_restype = 2574), -- тип оборудования "Оборудование ЦКТВ"), --TO DO: WORK 2574
                    NULL) INTO mEquipmentLicense FROM dual;
            ELSIF mTK_type not in (tk_type_digitalcable) THEN
            mEquipmentLicense := NULL;
            END IF;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfChangeTechTCComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", TC="' || TO_CHAR(mTK) ||
                                     '", LineID="' || TO_CHAR(mLineID) ||
                                     '", PhoneNumb="' || mPhone ||
                                     '", RezObsl="' || mRezObsl ||
                                     '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                     '", EquipmentLicense="' || TO_CHAR(mEquipmentLicense) || --внутренний номер устройства
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfChangeTechTCComplete@irbis(:RequestID, :TC, :LineID, :PhoneNumb, :RezObsl, :Prim,  :EquipmentLicense); ' ||
                              'END;'
                              USING IN mRequestID, IN mTK, IN mLineID, IN mPhone, IN mRezObsl, IN mResName, IN mEquipmentLicense;
         -- успех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ChangeTechOrderComplete',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              --CreationOfChangeTechOrderComplete
                              '   Billing.Amfitel.ChangeTechOrderComplete@irbis(:RequestID, :OrderFinishDate); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate;
         END IF;
      -- Наряд на изменение КТВ
      ELSIF mProc = 22 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.KTVChangeOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.KTVChangeOrderComplete@irbis(:RequestID, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Отключение КТВ по задолженности
      ELSIF mProc = 23 THEN
         OPEN GetMaxDate(mPaperID); FETCH GetMaxDate INTO mDate; CLOSE GetMaxDate;
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.KTVConnDisconnOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '", Prim="' || mResName || -- текстовое поле для доп. Информации в свободном виде
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.KTVConnDisconnOrderComplete@irbis(:RequestID, :OrderFinishDate, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate, IN mResName;
      /*-- замена паспортизированного клиентского оборудования (СРЕ) (модема WiFi Guest или Sip-адптера)
      ELSIF mProc = 24 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;

         irbis_is_core.get_tk_info(mTK, mTK_telzone, mTK_type);
            IF mTK_type = tk_type_wifiguest THEN
               OPEN GetTKResource(mTK, 1); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
               SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                           WHERE v.rvl_res = mLineID
                             AND v.rvl_prop_id = rp.rpr_id --id свойства
                             AND v.rvl_res_type = rp.rpr_restype --тип устройства
                             AND rp.rpr_strcod = 'SERIAL'
                             AND rp.rpr_restype IN (1263, 1083)), -- типы устройств "SIP адаптер" и "Модем SAGEM"),
                    NULL) INTO mNum FROM dual;
            ELSIF mTK_type = tk_type_sip THEN
               -- Базовый ресурс - линия (Sip устанолен по xDSL) либо порт (Sip установлен по Ethernet/WiMAX)
               SELECT NVL((SELECT tkd_resource FROM
                             (SELECT tkd_resource FROM rm_tk_data d, rm_equip_port p
                               WHERE d.tkd_tk = mTK AND d.tkd_res_class = 2
                                 AND d.tkd_isdel = 0 AND d.tkd_is_new_res IN (0, 1)
                                 AND p.prt_id = d.tkd_resource
                                 -- тип порта : Ethernet, FastEthernet, Сектор WiMAX
                                 AND p.prt_type IN (43, 543, 843, 1023, 383,263)
                              ORDER BY d.tkd_is_new_res DESC)
                            WHERE ROWNUM < 2), NULL)
                 INTO mPortID FROM dual;
               IF mPortID IS NOT NULL THEN
                  mLineID := mPortID;
               ELSE
                  OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
               END IF;

              SELECT NVL((SELECT v.rvl_value
                      FROM rm_res_prop_value v, rm_res_property rp,
                           rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d
                     WHERE d.tkd_tk = mTK
                       AND d.tkd_res_class = 2
                       AND d.tkd_resource = ep.prt_id
                       AND ep.prt_type = 1323
                       AND eu.un_id = ep.prt_unit
                       AND e.equ_id = eu.un_equip
                       AND v.rvl_res = e.equ_id
                       AND v.rvl_prop_id = rp.rpr_id --id свойства
                       AND v.rvl_res_type = rp.rpr_restype --тип устройства
                       AND rp.rpr_strcod = 'SERIAL'
                       AND rp.rpr_restype IN (1263, 1083)), -- типы устройств "SIP адаптер" и "Модем SAGEM"),
              NULL) INTO mNum FROM dual;

            ELSIF mTK_type = tk_type_digitalcable THEN
             OPEN GetTKResource(mTK, 2); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
            END IF;

         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ChangeModemOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", EquipmentNumber="' || mNum ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '", LineID="' || TO_CHAR(mLineID) ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ChangeModemOrderComplete@irbis(:RequestID, :EquipmentNumber, :OrderFinishDate, :LineID); ' ||
                           'END;'
                           USING IN mRequestID, IN mNum, IN mDate, IN mLineID;*/
            -- замена/выдача паспортизированного клиентского оборудования (СРЕ) --MCreateChangeModemTS
      ELSIF mProc in (24,31) THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK;
         OPEN GetTKResourceLast(mTK, 1); FETCH GetTKResourceLast INTO mEquipID; CLOSE GetTKResourceLast; --оборудование, добавленное последним
       /*  SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                     WHERE v.rvl_res = mEquipID
                       AND v.rvl_prop_id = rp.rpr_id --id свойства
                       AND v.rvl_res_type = rp.rpr_restype --тип устройства
                       AND rp.rpr_strcod in ( 'SERIAL','S_NUMBER')
                       AND rp.rpr_restype IN (2574, 1083)), -- типы устройств "CPE" или "Оборудование ЦКТВ"
              NULL) INTO mNum FROM dual;*/
              --MReturnEquip
         SELECT NVL((SELECT value FROM ad_paper_attr WHERE paper_id = (SELECT parent_id FROM ad_papers WHERE id = mPaperID) AND UPPER(strcod) = 'ACTIONTYPE'),
        NULL) INTO mActionType FROM dual;
        IF mActionType!=12 THEN
         SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                     WHERE v.rvl_res = mEquipID
                       AND v.rvl_prop_id = rp.rpr_id --id свойства
                       AND v.rvl_res_type = rp.rpr_restype --тип устройства
                       AND rp.rpr_strcod in ( 'SERIAL','S_NUMBER')
                       AND rp.rpr_restype IN (2574, 1083)), -- типы устройств "CPE" или "Оборудование ЦКТВ"
              NULL) INTO mNum FROM dual;
        ELSE mNum := NULL;
        END IF;

         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ChangeModemOrderComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", EquipmentNumber="' || mNum ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ChangeModemOrderComplete@irbis_main(:RequestID, :EquipmentNumber, :OrderFinishDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mNum, IN mDate;
            -- подключения и отключения дополнительного номера --MExtraNumber
      ELSIF mProc=32 THEN
      OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK;  CLOSE GetPaperTK; --MExtraNumberAdd
         mDate := SYSDATE;
          SELECT NVL((SELECT num_number FROM
                      (SELECT n.num_number
                        FROM rm_rub_value r, rm_tk_data d, rm_numbers n
                        WHERE d.tkd_tk = mTK
                          AND d.tkd_res_class = 6
                          AND r.rbv_entity = d.tkd_resource
                          AND r.rbv_record = 463
                          AND d.tkd_resource = n.num_id
                          ORDER BY d.tkd_id desc)
                        WHERE ROWNUM<2),
           NULL) INTO mPhone FROM DUAL;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ModifyTCAddNumberComplete',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", MobileNumber ="' || mPhone ||
                                  '", ExecuteDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ModifyTCAddNumberComplete@irbis(:RequestID, :MobileNumber, :ExecuteDate); ' ||
                           'END;'
                           USING IN mRequestID, IN mPhone, IN mDate;
        --- смена скорости
        ELSIF mProc=34 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log(' TTK_CRM_GROUP.REQ_PUBLIC.AMF_SPEEDSUCCESS',
                                  'mRequestID="' || TO_CHAR(mRequestID) ||
                                 -- '", mDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   TTK_CRM_GROUP.REQ_PUBLIC.AMF_SPEEDSUCCESS@irbis(:mRequestID); ' ||
                           'END;'
                           USING IN mRequestID; --, IN mDate;
       -- Смена скорости 100+
      ELSIF mProc = 35 THEN
        -- Смена скорости 100+ успех в ТС
        IF mObject = 'T' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('BILLING.PREQUEST_INTERNAL.SETREQUESTSTATUS',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",23303820, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_Change_TP100.Method_and_Comment@irbis(:mRequestID, 23303820, NULL); ' ||
                               'END;'
                               USING IN mRequestID;
        -- Смена скорости 100+ успех в наряде
        ELSIF mObject = 'O' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('BILLING.PREQUEST_INTERNAL.SETREQUESTSTATUS',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",23303829, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_Change_TP100.Method_and_Comment@irbis(:mRequestID, 23303829, NULL); ' ||
                               'END;'
                               USING IN mRequestID;
        END IF;

       -- Добавление/удаление номеров ВАТС
      ELSIF mProc = 36 THEN
        -- Успех в ТС
        SELECT LISTAGG(num.num_number, ', ') WITHIN GROUP (ORDER BY rm.tkd_resource) INTO mNumberVATS
        FROM ad_paper_extended ape
        JOIN rm_tk_data rm ON ape.tk_id = rm.tkd_tk AND rm.tkd_res_class = 6 AND rm.tkd_is_new_res = 1
        JOIN rm_numbers num ON rm.tkd_resource = num.num_id
        WHERE ape.paper_id = mPaperID;
        IF mObject = 'T' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",335186854, NULL, mNumberVATS: ' || mNumberVATS,
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment@irbis(:mRequestID, 335186854, NULL, :mNumberVATS); ' ||
                               'END;'
                               USING IN mRequestID, IN mNumberVATS;
        -- Успех в наряде
        ELSIF mObject = 'O' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",335187428, NULL, mNumberVATS"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment@irbis(:mRequestID, 335187428, NULL, :mNumberVATS); ' ||
                               'END;'
                               USING IN mRequestID, IN mNumberVATS;
        END IF;

      -- Переключение телефонии на SIP VOIP
      ELSIF mProc = 37 THEN
        -- успех в ТС
        OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
        OPEN GetPaperTK(mPaperID); FETCH GetPaperTK INTO mTK; CLOSE GetPaperTK;
        OPEN GetTKResource(mTK, 7); FETCH GetTKResource INTO mLineID; CLOSE GetTKResource;
        IF mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_Phone_to_SIP_phone.TS_Complete_m2000',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",mLineID="' || mLineID ||
                                      '",mTK="' || mTK ||
                                      '",mResName="' || mResName ||
                                      '"',
                                      mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              'TTK_CRM_GROUP.PKG_Phone_to_SIP_phone.TS_Complete_m2000@irbis(:RequestID, :LineID, :TK_ID, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mLineID, IN mTK, IN mResName;
        -- успех в наряде
        ELSIF mObject = 'O' THEN
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_Phone_to_SIP_phone.Order_Complete_m2000',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",mResName="' || mResName ||
                                      '"',
                                      mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              'TTK_CRM_GROUP.PKG_Phone_to_SIP_phone.Order_Complete_m2000@irbis(:RequestID, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
        END IF;

      -- Установка облачного видеонаблюдения
      ELSIF mProc = 38 THEN
        OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
        SELECT pnumber INTO mPnumber FROM ad_papers WHERE id = mPaperID;
        -- успех в наряде
        IF mObject = 'O' THEN
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_OVN.OVN_m2000_Success',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",Prim="' || mResName ||
                                      '"',
                                      mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              'TTK_CRM_GROUP.PKG_OVN.OVN_m2000_Success@irbis(:RequestID, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN 'Наряд Н-'||mPnumber||'. '||mResName;
        END IF;

      -- неизвестный бизнес-процесс
      ELSE
         irbis_is_core.write_processed_errorlog(mItemID, mStateID, 3, 'Уведомление не отправлено: Не найдено соответствие между документом и бизнес-процессом');
         UPDATE irbis_request_papers SET state_id = 6 WHERE id = mItemID;
         RETURN 0;
      END IF;
      -- изменение состояния в списке соответствия документов и заявок IRBiS
      UPDATE irbis_request_papers SET state_id = 3 WHERE id = mItemID AND state_id = mStateID;
      RETURN 1;
   -- завершено неудачно, документ закрыт , т.е.  aIS_SUCCESS = 0
   ELSE
      -- установка Телефона
      -- установка СПД
      -- Подключение IP TV
      -- Подключение кабельного ТВ
      -- Подключение IP TV
      IF    (mProc IN (1, 3, 17, 18, 19, 20, 29, 30)) THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         -- неуспех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfTCFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfTCFailed@irbis(:RequestID, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         -- неуспех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetCloseDate(mPaperID); FETCH GetCloseDate INTO mDate; CLOSE GetCloseDate;
            OPEN GetReasonToOS(mPaperID); FETCH GetReasonToOS INTO mReasonToOS; CLOSE GetReasonToOS;
            IF (mReasonToOS='16') and (mProc IN (3, 29, 30)) THEN --в случае неисправного оборудования MChangeEquip
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ConnOrderChangeEquipFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
                  EXECUTE IMMEDIATE 'BEGIN ' ||
                                    '   Billing.Amfitel.ConnOrderChangeEquipFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' || -->Billing.Amfitel.PrimaryConnectionOrderFailed@irbis
                                    'END;'
                                    USING IN mRequestID, IN mDate, IN mResName;
            ELSE
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PrimaryConnectionOrderFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                                    '   Billing.Amfitel.PrimaryConnectionOrderFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' ||
                                    'END;'
                                    USING IN mRequestID, IN mDate, IN mResName;
            END IF;
         END IF;
      -- установка прямого провода
      ELSIF mProc = 2 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         -- неуспех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreateDirWireTCFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Prim="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreateDirWireTCFailed@irbis(:RequestID, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         -- неуспех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetCloseDate(mPaperID); FETCH GetCloseDate INTO mDate; CLOSE GetCloseDate;
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ConnectDirWireOrderFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     'OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ConnectDirWireOrderFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mResName;
         END IF;
      -- неуспех при снятии - Такого быть не должно. Снятие всегда должно завершаться успехом
      ELSIF mProc = 4 THEN
         SELECT subtype_id
         INTO mSubtypeID
         FROM ad_papers
         WHERE id = mPaperID;

         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;

         IF mSubtypeID = 12006 THEN
            SELECT pnumber INTO mPnumber FROM ad_papers WHERE id = mPaperID;
            irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_OVN_DISABLE.OVN_m2000_Error',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Prim="' || mResName ||
                                  '"',
                                  mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   TTK_CRM_GROUP.PKG_OVN_DISABLE.OVN_m2000_Error@irbis(:RequestID, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN 'Наряд Н-'||mPnumber||'. '||mResName;
         ELSE
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TCCloseFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.TCCloseFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
         END IF;
      -- неуспех в заявке на обследование
      ELSIF mProc = 5 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfTCFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.CreationOfTCFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Изменение оператора дальней связи (категории АОН)
      ELSIF mProc = 6 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.SetPhoneCategoryFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.SetPhoneCategoryFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Изменение статуса исходящей связи
      ELSIF mProc = 7 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.SetSetCallBarringStateFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.SetSetCallBarringStateFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Постановка на охранную сигнализацию
      ELSIF mProc = 8 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.PlantAlarmOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.PlantAlarmOrderFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Перенос (малый или большой)
      ELSIF (mProc = 9) OR (mProc = 10) THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         OPEN GetCloseDate(mPaperID); FETCH GetCloseDate INTO mDate; CLOSE GetCloseDate;
         -- неуспех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TransferOfTCFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.TransferOfTCFailed@irbis(:RequestID, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         -- неуспех в наряде
         ELSIF mObject = 'O' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.TransferOrderFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.TransferOrderFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mResName;
         END IF;
      -- Замена телефонного номера
      ELSIF mProc = 11 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         -- неуспех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ModificationOfTCFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ModificationOfTCFailed@irbis(:RequestID, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         -- неуспех в наряде
         ELSIF mObject = 'O' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CommutationTelNumOrderFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CommutationTelNumOrderFailed@irbis(:RequestID, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         END IF;
      -- Перекроссировка
      ELSIF mProc = 12 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ReCrossAlarmOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ReCrossAlarmOrderFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Переоформление
      /*ELSIF mProc = 13 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.RenewalTCFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.RenewalTCFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;*/
      -- Установка и снятие параллельного аппарата
      ELSIF mProc IN (14, 25) THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ParallelAppOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(SYSDATE, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '", Prim="' || TO_CHAR(mResName) ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ParallelAppOrderFailed@irbis(:RequestID, :OrderFinishDate,:Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN SYSDATE, IN mResName;
      -- Бронирование телефонного номера
      ELSIF mProc = 15 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfResNumTCFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.CreationOfResNumTCFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;

      -- Смена технологии подключения
      ELSIF mProc = 21 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         -- неуспех в техсправке
         IF    mObject = 'T' THEN
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.CreationOfChangeTechTCFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.CreationOfChangeTechTCFailed@irbis(:RequestID, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mResName;
         -- неуспех в наряде
         ELSIF mObject = 'O' THEN
            OPEN GetCloseDate(mPaperID); FETCH GetCloseDate INTO mDate; CLOSE GetCloseDate;
            OPEN GetReasonToOS(mPaperID); FETCH GetReasonToOS INTO mReasonToOS; CLOSE GetReasonToOS;
            IF mReasonToOS='16' THEN --в случае неисправного оборудования
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ConnOrderChangeEquipFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
                  EXECUTE IMMEDIATE 'BEGIN ' ||
                                    '   Billing.Amfitel.ConnOrderChangeEquipFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' || -->Billing.Amfitel.PrimaryConnectionOrderFailed@irbis
                                    'END;'
                                    USING IN mRequestID, IN mDate, IN mResName;
            ELSE
            irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ChangeTechOrderFailed',
                                     'RequestID="' || TO_CHAR(mRequestID) ||
                                     '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                     '", Reason="' || mResName ||
                                     '"',
                                     mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              '   Billing.Amfitel.ChangeTechOrderFailed@irbis(:RequestID, :OrderFinishDate, :Reason); ' ||
                              'END;'
                              USING IN mRequestID, IN mDate, IN mResName;
            END IF;
         END IF;
      -- Наряд на изменение КТВ
      ELSIF mProc = 22 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.KTVChangeOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.KTVChangeOrderFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName;
      -- Отключение КТВ по задолженности
      ELSIF mProc = 23 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.KTVConnDisconnOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '", Prim="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.KTVConnDisconnOrderFailed@irbis(:RequestID, :OrderFinishDate, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN SYSDATE, IN mResName;
      -- Замена наряда WiFi Guest -- замена/выдача паспортизированного клиентского оборудования (СРЕ) --MCreateChangeModemTS
      ELSIF mProc in  (24,31) THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ChangeModemOrderFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", OrderFinishDate="' || TO_CHAR(mDate, 'DD.MM.YYYY') ||
                                  '", Prim="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ChangeModemOrderFailed@irbis(:RequestID, :OrderFinishDate, :Prim); ' ||
                           'END;'
                           USING IN mRequestID, IN mDate, IN mResName;
      -- подключения и отключения дополнительного номера --MExtraNumber
      ELSIF mProc=32 THEN
         OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
         irbis_is_core.write_irbis_activity_log('Billing.Amfitel.ModifyTCAddNumberFailed',
                                  'RequestID="' || TO_CHAR(mRequestID) ||
                                  '", Reason="' || mResName ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '   Billing.Amfitel.ModifyTCAddNumberFailed@irbis(:RequestID, :Reason); ' ||
                           'END;'
                           USING IN mRequestID, IN mResName; --MExtraNumberAdd
      --Смена скорости
              ELSIF mProc=34 THEN
         OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
         irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.REQ_PUBLIC.AMF_SPEEDfailure',
                                  'mRequestID="' || TO_CHAR(mRequestID) ||
                                --  '", mDate="' || TO_CHAR(mDate, 'DD.MM.YYYY HH24:MI:SS') ||
                                  '"',
                                  mRequestID);
         EXECUTE IMMEDIATE 'BEGIN ' ||
                           '    TTK_CRM_GROUP.REQ_PUBLIC.AMF_SPEEDfailure@irbis(:mRequestID); ' ||
                           'END;'
                           USING IN mRequestID;  --, IN mDate;
      --Ссмена скорости 100+
      ELSIF mProc = 35 THEN
        -- Cмена скорости 100+ не успех в ТС
        IF mObject = 'T' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('BILLING.PREQUEST_INTERNAL.SETREQUESTSTATUS',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",23303821, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_Change_TP100.Method_and_Comment@irbis (:mRequestID, 23303821, NULL); ' ||
                               'END;'
                               USING IN mRequestID;
        -- Смена скорости 100+ не успех в наряде
        ELSIF mObject = 'O' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('BILLING.PREQUEST_INTERNAL.SETREQUESTSTATUS',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",23303831, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_Change_TP100.Method_and_Comment@irbis(:mRequestID, 23303831, NULL); ' ||
                               'END;'
                               USING IN mRequestID;
        END IF;

      -- Добавление/удаление номеров ВАТС
      ELSIF mProc = 36 THEN
        OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
        -- Не успех в ТС
        IF mObject = 'T' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",335186856, NULL, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment@irbis(:mRequestID, 335186856, :Prim, NULL); ' ||
                               'END;'
                               USING IN mRequestID, IN mResName;
        -- Не успех в наряде
        ELSIF mObject = 'O' THEN
             OPEN GetMakeDate(mPaperID); FETCH GetMakeDate INTO mDate; CLOSE GetMakeDate;
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",335187429, NULL, NULL"',
                                      mRequestID);
             EXECUTE IMMEDIATE 'BEGIN ' ||
                               'TTK_CRM_GROUP.PKG_VATC_ADD_PHONE.Method_and_Comment@irbis(:mRequestID, 335187429, :Prim, NULL); ' ||
                               'END;'
                               USING IN mRequestID, IN mResName;
        END IF;

      -- Установка облачного видеонаблюдения
      ELSIF mProc = 38 THEN
        OPEN GetCloseReason(mPaperID); FETCH GetCloseReason INTO mResName; CLOSE GetCloseReason;
        SELECT pnumber INTO mPnumber FROM ad_papers WHERE id = mPaperID;
        -- Не успех в наряде
        IF mObject = 'O' THEN
             irbis_is_core.write_irbis_activity_log('TTK_CRM_GROUP.PKG_OVN.OVN_m2000_Error',
                                      'mRequestID="' || TO_CHAR(mRequestID) ||
                                      '",Prim="' || mResName ||
                                      '"',
                                      mRequestID);
            EXECUTE IMMEDIATE 'BEGIN ' ||
                              'TTK_CRM_GROUP.PKG_OVN.OVN_m2000_Error@irbis(:RequestID, :Prim); ' ||
                              'END;'
                              USING IN mRequestID, IN 'Наряд Н-'||mPnumber||'. '||mResName;
        END IF;

      -- не определен бизнес-процесс, не выбрана процедура для отправки уведомления в IRBiS
      ELSE
         irbis_is_core.write_processed_errorlog(mItemID, mStateID, 5, 'Уведомление не отправлено: Не найдено соответствие между документом и бизнес-процессом');
         UPDATE irbis_request_papers SET state_id = 7 WHERE id = mItemID;
         RETURN 0;
      END IF;
      -- изменение состояния в списке соответствия документов и заявок IRBiS
      UPDATE irbis_request_papers SET state_id = 5 WHERE id = mItemID AND state_id = mStateID;
      RETURN 1;

   END IF;

END SendToIrbis;


-- Создание заявления и технической карты для БП "Установка IPTV"
PROCEDURE CreateIPTVTC
(
   RequestID      IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID     IN NUMBER,   -- идентификатор первичного ресурса (ЛД в случае xDSL, порт в случае Ethernet) на который следует произвести подключение. Если 0 ? то IPTV устанавливается без интернета
   ConnectionType IN VARCHAR2, -- тип подключения (IP TV xDSL, IP TV Ethernet)
   MainParam      IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   mContragentID    NUMBER;
   mAccountID       NUMBER;
   mAbonementID     NUMBER;
   mContactPhone    ad_paper_attr.value_long%TYPE;
   mOperatorName    ad_paper_attr.value_long%TYPE;

   mTelzone_ID      ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID     ad_papers.department_id%TYPE;

   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)

   mContractHouse   NUMBER;
   mContractApart   VARCHAR2(50);

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;               -- id содержания созданного документа
   mChildSubtype  ad_subtypes.id%TYPE;

   mHouseOnly       NUMBER := 0;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse    NUMBER := 0;           -- признак того, что дом является частным (без квартир)
   mState           NUMBER;
   mAddress_ID      NUMBER;
   mAddress2_ID     NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);

   mResExists       NUMBER;
   mTemp            NUMBER;
   mTkd_id          NUMBER;
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTkd_res_class rm_tk_data.tkd_res_class%TYPE; -- тип базового ресурса в ТК, зависит от ConnectionType
   mTK_SPD          NUMBER;  -- id ТК СПД, в которой находятся порты СПД, которые следует добавить
                             --   в новую ТК (когда происходит установка на существующий СПД)
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000
   mKeyParams     irbis_activity_log.parameters%TYPE;
   mRes           NUMBER;

   mConnectionReason  VARCHAR2(300);

   mTD_ID         number;
   mRMDocID       number;

BEGIN
   mKeyParams := 'ResourceID="' || TO_CHAR(ResourceID) ||
                 '", ConnectionType="' || ConnectionType ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreateIPTVTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'           THEN mContragentID    := TO_NUMBER(x.value);
         WHEN 'AccountID'          THEN mAccountID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         --WHEN 'ContractTCID'       THEN mTK              := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mContractHouse   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mContractApart   := x.value;
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         --WHEN 'AccountNumber'      THEN mAccountNumber   := x.value;
         --WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.value;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mContractHouse);
   mTK_type    := tk_type_iptv;

   irbis_is_core.GetAddressID(mContractHouse, mContractApart, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
   mAddress2_ID  := NULL;

   -- В зависимости от типа подключения определяется какой вид ресурса передается.
   --   в дальнейшем используется для определения вида и для копирования ресурсов в новую ТК
   IF ConnectionType = 'IP TV xDSL' THEN
      mTkd_res_class := 7;
      -- Заявление на установку IP TV с установкой xDSL по выделенной линии
      IF ResourceID IN (-1, 0) THEN
         mResExists := 0;
      ELSE
         -- ПО ЛИНИИ ПРЕДОСТАВЛЯЕТСЯ СПД
         -- переданный ресурс (ЛДН) находится в ТК типа "DSL", "DSL + Тел" и т.д.
         SELECT COUNT(t.tk_id)
           INTO mTemp
           FROM rm_tk_data d, rm_tk t
          WHERE d.tkd_resource = ResourceID
            AND d.tkd_isdel = 0
            AND d.tkd_res_class = 7
            AND d.tkd_tk = t.tk_id
            AND t.tk_status_id != 0
            AND t.tk_type IN (tk_type_dsl_old, tk_type_dsl_new);
         IF mTemp > 0 THEN
            mResExists := 1;
            -- определить ТК СПД
            SELECT (
                  SELECT t.tk_id FROM rm_tk_data d, rm_tk t
                   WHERE d.tkd_resource = ResourceID AND d.tkd_isdel = 0
                     AND d.tkd_res_class = 7
                     AND d.tkd_tk = t.tk_id          AND t.tk_status_id != 0
                     AND t.tk_type IN (tk_type_dsl_old, tk_type_dsl_new)
                     AND ROWNUM = 1
                   ) INTO mTK_SPD FROM dual;
         ELSE
            -- ЛИНИЯ ЕСТЬ, НО СПД НЕ ПРЕДОСТАВЛЯЕТСЯ
            -- переданный ресурс находится в ТК типа "Телефон"
            SELECT COUNT(t.tk_id)
              INTO mTemp
              FROM rm_tk_data d, rm_tk t
             WHERE d.tkd_resource = ResourceID
               AND d.tkd_isdel = 0
               AND d.tkd_res_class = 7
               AND d.tkd_tk = t.tk_id
               AND t.tk_status_id != 0
               AND t.tk_type IN (tk_type_tel, tk_type_pp, tk_type_oxr, tk_type_sip);
            IF mTemp > 0 THEN
               mResExists := 2;
            ELSE
               RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти линию в действующих технических картах');
            -- Заявление на установку IP TV по СПД
            END IF;
         END IF;
      END IF;
   ELSIF ConnectionType IN ('IP TV Ethernet','IP TV GPON','IP TV wifistreet') THEN
      mTkd_res_class := 2;
      IF ResourceID IN (-1, 0) THEN
         mResExists := 0;
      ELSE
         SELECT COUNT(p.prt_id) INTO mTemp FROM rm_equip_port p WHERE p.prt_id = ResourceID;
         irbis_utl.assertTrue((mTemp != 0), 'Не существует порта с переданным ID');
         -- дополнительная проверка - этот порт есть в ТК, связанной с переданным адресом
         SELECT COUNT(d.tkd_id) INTO mTemp
           FROM rm_tk_data d, rm_tk_address a
          WHERE d.tkd_resource = ResourceID
            AND d.tkd_res_class = 2
            AND d.tkd_tk = a.adr_tk
            AND a.adr_id = mAddress_ID;
         irbis_utl.assertTrue((mTemp != 0), 'Не существует порта с переданным ID по указанному адресу');
         mResExists := 1;
      END IF;
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Не определен тип подключения');
   END IF;

   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('CreateIPTVTC', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      SELECT NVL((SELECT h.to_depart_id FROM ad_paper_history h WHERE h.paper_id = mDeclar_ID AND h.resolution_id = 1), mAbonOtdelID) INTO mAbonOtdelID FROM dual;
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      mSubtype_ID := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_IPTV) || '";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                             'CONNECTION="' || UPPER(ConnectionType) || '";' ||
                                             'RESOURCE="' || TO_CHAR(mResExists) ||
                                             '"');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_IPTV'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mContragentID, 'IRBIS_CONTRAGENT',
                                               mAccountID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', ConnectionType, ConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_REASON', mConnectionReason, mConnectionReason);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, irbis_utl.BP_IPTV, MainParam);
   END IF;

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_IPTV) || '";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'CONNECTION="' || UPPER(ConnectionType) || '";' ||
                                            'RESOURCE="' || TO_CHAR(mResExists) ||
                                            '"');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);
   irbis_is_core.update_paper_attr(mTS_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   irbis_is_core.attach_usl_to_tk(mTK_ID, mAbonementID, 'IRBIS', 'Абонемент IRBiS');

   -- при установке на существующую линию/порт в техкарте сразу должны быть соответствующие ресурсы
   -- <nell 07 10 2010> добавлено условие ResourceID <> 0
   IF (ResourceID IS NOT NULL) AND (ResourceID > 0) THEN
     mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
     mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                    xClass_ID => mTkd_res_class,
                                                    xRes_ID   => ResourceID,
                                                    xDoc_ID   => mRMDocID,
                                                    xUser_ID  => irbis_user_id);
     if (mTD_ID is null) then null; end if;

     /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mTkd_res_class, ResourceID, 0, 0, 0, NULL)
         RETURNING tkd_id INTO mTkd_id;

       irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

      IF NOT (mTK_SPD IS NULL) THEN
         SELECT tkd_is_new_res
           INTO mRes
           FROM (SELECT tkd_is_new_res
                   FROM rm_tk_data
                  WHERE tkd_tk = mTK_SPD
                    AND tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                    AND tkd_is_new_res != RM_CONSTS.RM_TK_DATA_WORK_FROM
                  ORDER BY tkd_is_new_res DESC)
          WHERE ROWNUM<2;
         -- добавление портов в новую ТК в случае установки на существующий DSL
         FOR v1 IN (SELECT rm_gen_tk_data.NEXTVAL mTkd_id, mTK_ID, tkd_res_class, tkd_resource, ROWNUM + 1 npp,
                           tkd_isdel, tkd_is_new_res
                      FROM rm_tk_data
                     WHERE tkd_tk = mTK_SPD
                       AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = tkd_tk) != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                       AND tkd_res_class = 2
                       AND tkd_is_new_res = mRes
                       AND tkd_isdel = 0)
         LOOP
           if (mRes = RM_CONSTS.RM_TK_DATA_WORK_NONE) then
             mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                            xClass_ID => v1.tkd_res_class,
                                                            xRes_ID   => v1.tkd_resource,
                                                            xPos      => v1.npp,
                                                            xDoc_ID   => mRMDocID,
                                                            xUser_ID  => irbis_user_id);
           else -- (mRes = RM_CONSTS.RM_TK_DATA_WORK_INTO)
             mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                            xClass_ID => v1.tkd_res_class,
                                                            xRes_ID   => v1.tkd_resource,
                                                            xPos      => v1.npp,
                                                            xDoc_ID   => mRMDocID,
                                                            xUser_ID  => irbis_user_id);
           end if;

         END LOOP;
/*            SELECT rm_gen_tk_data.nextval INTO mTkd_id FROM dual;
         INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                 tkd_isdel, tkd_is_new_res, tkd_parent_id)
         SELECT mTkd_id, mTK_ID, tkd_res_class, tkd_resource, ROWNUM + 1,
                tkd_isdel, tkd_is_new_res, NULL
           FROM rm_tk_data
          WHERE tkd_tk = mTK_SPD
            AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = tkd_tk) != 0
            AND tkd_res_class = 2
            AND tkd_is_new_res != 2
            AND tkd_isdel = 0;

            irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
      END IF;
   END IF;

   -- сохранение созданной техкарты в документе - заявке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mTS_ID);

   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateIPTVTC;

-- Создание наряда на установку IPTV, KTV
PROCEDURE CreatePrimaryConnectionOrder (
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment  IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish    IN DATE,     -- желаемая дата подключения
   MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;
   mParent_ID     ad_papers.id%TYPE;
   mParentSubtype ad_subtypes.id%TYPE;
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;
   mOrder_ID      ad_papers.id%TYPE;
   mPriority      NUMBER;
   mPriorityLong  VARCHAR2(200);
   mActivationDate  DATE;
   mSourceOfSales   VARCHAR2(300);
   mOperatorName  VARCHAR2(200);
   mContactPhone  VARCHAR2(200);
   mProc          irbis_subtypes.proc%TYPE;
   --mAbonementID   NUMBER;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mConnType      ad_paper_attr.value%TYPE;

   mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
   mTariffPlanName VARCHAR2(200);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreatePrimaryConnectionOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

    -- Разбор XML
    IF MainParam IS NOT NULL THEN
     FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'ActivationDate'     THEN mActivationDate  := TO_DATE(x.value, 'DD.MM.YYYY HH24:MI:SS');
         WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.value;
         WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.VALUE;
         ELSE NULL;
      END CASE;
     END LOOP;
    END IF;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
   CLOSE GetParentPaper;
   IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
   END IF;

   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');
   mProc  := irbis_utl.getProcByPaper(mParent_ID);
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);
   SELECT NVL((SELECT tk_type FROM rm_tk WHERE tk_id = mTK_ID), NULL) INTO mTK_type FROM dual;
   mConnType := ad_get.get_paper_attr(mParent_ID, 'CONNECTION_TYPE');

   --необязательная проверка состояния ТК
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

   IF mProc in (19,30) THEN
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'CONNECTION="' || UPPER(mConnType) ||
                                               '"');
   ELSE
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'CONNECTION="' || UPPER(mConnType) || '";' ||
                                               'PARENT_SUBTYPE="' || TO_CHAR(mParentSubtype) ||
                                               '"');
   END IF;
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mParentSubtype,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);


   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_ACTIV', TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONNECTION_TYPE', mConnType, mConnType);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreatePrimaryConnectionOrder;

-- Создание наряда на установку ТФОП, SIP, VOIP
PROCEDURE CreatePrimaryConnectionOrder (
   RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish     IN DATE,     -- желаемая дата подключения
   PhoneCategory    IN NUMBER,   -- категория оператора дальней связи
   CallBarringState IN NUMBER,   -- статус исходящей связи
   MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
BEGIN
   CreatePrimaryConnectionOrder(RequestID, DateMontComment, RequestComment, DateMontWish,
                                PhoneCategory, CallBarringState, NULL, NULL, MainParam);
END;

-- Создание наряда на установку SIP РТУ (а также ТФОП, SIP, VOIP)
PROCEDURE CreatePrimaryConnectionOrder (
   RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish     IN DATE,     -- желаемая дата подключения
   PhoneCategory    IN NUMBER,   -- категория оператора дальней связи
   CallBarringState IN NUMBER,   -- статус исходящей связи
   EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
   PFloor           IN VARCHAR2, -- этаж расположения точки WiFi Sagem
   MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS

   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;
   mParent_ID     ad_papers.id%TYPE;
   mParentSubtype ad_subtypes.id%TYPE;
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;
   mOrder_ID      ad_papers.id%TYPE;

   mProc          irbis_subtypes.proc%TYPE;
   --mAbonementID   NUMBER;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);
   mActivationDate  DATE;
   mSourceOfSales   VARCHAR2(300);
   mOperatorName  VARCHAR2(200);
   mContactPhone  VARCHAR2(200);

   mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
   mTariffPlanName VARCHAR2(200);

BEGIN

   irbis_is_core.write_irbis_activity_log('CreatePrimaryConnectionOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", PhoneCategory="' || TO_CHAR(PhoneCategory) ||
                            '", CallBarringState="' || TO_CHAR(CallBarringState) ||
                            '", EquipmentNumber="' || TO_CHAR(EquipmentNumber) ||
                            '", PFloor="' || TO_CHAR(PFloor) ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'ActivationDate'     THEN mActivationDate  := TO_DATE(x.value, 'DD.MM.YYYY HH24:MI:SS');
         WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.value;
         WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
   CLOSE GetParentPaper;
   IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
   END IF;

   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');
   mProc  := irbis_utl.getProcByPaper(mParent_ID);
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);
   SELECT NVL((SELECT tk_type FROM rm_tk WHERE tk_id = mTK_ID), NULL) INTO mTK_type FROM dual;

   --необязательная проверка состояния ТК
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                            'OBJECT="O";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                            'PARENT_SUBTYPE="' || TO_CHAR(mParentSubtype) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mParentSubtype,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
   irbis_is_core.update_paper_attr(mOrder_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_ACTIV', TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

   -- Отправка данных на платформу PMP
--   IF EquipmentNumber IS NOT NULL THEN
--      pmp_is.installSip(mOrder_ID);
--   END IF;

END CreatePrimaryConnectionOrder;

-- Создание наряда на установку интернета
PROCEDURE CreatePrimaryConnectionOrder (
   RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish     IN DATE,     -- желаемая дата подключения
   PFloor           IN VARCHAR2, -- Этаж расположения точки WiFi Sagem
   MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
  CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL
         and p.STATE_ID !='C';---PovtZap
   mParent_ID     ad_papers.id%TYPE;
   mParentSubtype ad_subtypes.id%TYPE;
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;
   mOrder_ID      ad_papers.id%TYPE;
   mAuthenticationType   ad_paper_attr.value%TYPE;
   mConnectionType       ad_paper_attr.value%TYPE;
   mLineID        NUMBER;
   --mSubtypeID     ad_subtypes.id%TYPE;

   mProc          irbis_subtypes.proc%TYPE;
   --mAbonementID   NUMBER;

   --mAttrValueID   NUMBER;
   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;

   mTK_ID           rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mResult        BOOLEAN;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);
   mActivationDate  DATE;
   mSourceOfSales   VARCHAR2(300);
   mOperatorName  VARCHAR2(200);
   mContactPhone  VARCHAR2(200);

   mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
   mTariffPlanName VARCHAR2(200);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreatePrimaryConnectionOrder',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", PFloor="' || PFloor ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
    IF MainParam IS NOT NULL THEN
     FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'ActivationDate'     THEN mActivationDate  := TO_DATE(x.value, 'DD.MM.YYYY HH24:MI:SS');
         WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.value;
         WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
         ELSE NULL;
      END CASE;
     END LOOP;
    END IF;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
   CLOSE GetParentPaper;
   IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
   END IF;

   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

   ad_rules.get_attr_value(mParent_ID, 'AUTHENTICATION_TYPE', mResult, mAuthenticationType);
   ad_rules.get_attr_value(mParent_ID, 'CONNECTION_TYPE', mResult, mConnectionType);

   SELECT COUNT(1) INTO mLineID
   FROM ad_paper_attr
   WHERE paper_id = mParent_ID AND strcod = 'CUSL_NUM';

   mProc  := irbis_utl.getProcByPaper(mParent_ID);
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);

   --необязательная проверка состояния ТК
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

   SELECT NVL((SELECT tk_type FROM rm_tk WHERE tk_id = mTK_ID), NULL) INTO mTK_type FROM dual;

    IF mTK_type = tk_type_wifiguest THEN
      irbis_utl.assertNotNull( (TRIM(PFloor)), 'Не указан этаж расположения точки WiFi Sagem');
   END IF;

    mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'AUTHENTICATION="' || UPPER(mAuthenticationType) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(mLineID)) || '";' ||
                                               'CONNECTION="' || UPPER(mConnectionType) ||
                                               '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mParentSubtype,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
   irbis_is_core.update_paper_attr(mOrder_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_ACTIV', TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

    IF mTK_type = tk_type_wifiguest THEN
      irbis_is_core.update_paper_attr(mOrder_ID, 'PNT_FLR', PFloor, PFloor);
      -- Save in technical card's property
      MERGE INTO rm_tk_prop_value v
         USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PNT_FLR')
         ON    (v.prop_id = property_id AND v.tk_id   = mTK_ID)
         WHEN MATCHED
            THEN UPDATE
                 SET value = PFloor
         WHEN NOT MATCHED
            THEN INSERT
                 VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, PFloor, 0);
   END IF;

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreatePrimaryConnectionOrder;

-- Создание заявления и техкарты для БП "Установка MVNO"
PROCEDURE CreateMVNOTC
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   PhoneNumber     IN  VARCHAR2, -- обязательный параметр, содержит номер телефона в формате DEF
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   TC              OUT NUMBER,   -- номер тех.карты
   ResourceID      OUT NUMBER    -- идентификатор ресурса
) IS
   /*
   CURSOR GetResourceID(cTelzone_ID NUMBER, cPhoneNumber VARCHAR2) IS
      SELECT num_id
     FROM rm_numbers
    WHERE num_number = cPhoneNumber;
--      AND num_telzona = cTelzone_ID;
*/
   mContragentID    NUMBER;
   mAccountID       NUMBER;
   mAbonementID     NUMBER;
   mOperatorName    ad_paper_attr.value_long%TYPE;

   mTelzone_ID      ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID     ad_papers.department_id%TYPE;

   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)

   mContractHouse   NUMBER;

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;               -- id содержания созданного документа
   mChildSubtype  ad_subtypes.id%TYPE;

   mAddress_ID      NUMBER;
   mAddress2_ID     NUMBER;
   mRem             rm_tk.tk_rem%TYPE;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;

   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTkd_res_class rm_tk_data.tkd_res_class%TYPE; -- тип базового ресурса в ТК, зависит от ConnectionType
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000
   mHoldResult      VARCHAR2(2000);
   --mTkd_id             NUMBER;
   mKeyParams     irbis_activity_log.parameters%TYPE;
   mRubDop NUMBER; --MExtraNumberAdd2
   mResState NUMBER;  --Diana
   mTD_ID         number;
   mRMDocID       number;
BEGIN
   mKeyParams := 'PhoneNumber="' || PhoneNumber || '"';
   irbis_is_core.write_irbis_activity_log('CreateMVNOTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'           THEN mContragentID    := TO_NUMBER(x.value);
         WHEN 'AccountID'          THEN mAccountID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mContractHouse   := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'AccountCompanyBranchCode'      THEN mTelzone_ID   := 103;
         --WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.value;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         ELSE NULL;
      END CASE;
   END LOOP;

--   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mContractHouse);
   mTK_type    := tk_type_mvno;

   mRem          := 'mvno';
   mAddress_ID   := 6392767; -- при создании ТК добавлять единый адрес Казань, Ершова 57В
   mAddress2_ID  := NULL;
   mTkd_res_class := 6;

   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('CreateMVNOTC', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      SELECT NVL((SELECT h.to_depart_id FROM ad_paper_history h WHERE h.paper_id = mDeclar_ID AND h.resolution_id = 1), mAbonOtdelID) INTO mAbonOtdelID FROM dual;
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      mSubtype_ID := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNO) || '";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) ||
                                             '"');
      irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_MVNO'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mContragentID, 'IRBIS_CONTRAGENT',
                                               mAccountID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_NUM', PhoneNumber, PhoneNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), TO_CHAR(mPriority));

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, irbis_utl.BP_MVNO, MainParam);
   END IF;

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNO) || '";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       mRem,          -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   irbis_is_core.attach_usl_to_tk(mTK_ID, mAbonementID, 'IRBIS', 'Абонемент IRBiS');

   TC := mTK_ID;
   /*
   OPEN GetResourceID(mTelzone_ID, PhoneNumber);
   FETCH GetResourceID INTO ResourceID;
   CLOSE GetResourceID;
   */
  --Для Смартс(филиал 103) своя номерная емкость
  IF mTelzone_ID=103 THEN
     SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = PhoneNumber AND num_telzona = 103), NULL) INTO ResourceID  FROM dual;
  ELSE
     SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = PhoneNumber AND num_telzona != 103), NULL) INTO ResourceID  FROM dual;
  END IF;

   IF (ResourceID IS NOT NULL) AND (ResourceID > 0) THEN
      SELECT count(1) INTO mRubDop FROM rm_rub_value WHERE rbv_entity = ResourceID AND rbv_record=463; --MExtraNumberAdd2
      irbis_utl.assertTrue((mRubDop=0), 'Данный номер сотовой связи  ' || PhoneNumber || ' является дополнительным!'); --MExtraNumberAdd2
      select count(1)INTO mResState from rm_resource where res_id=ResourceID and res_class=6 and res_astate=3;    ---Diana
      irbis_utl.assertTrue((mResState=0), 'Данный номер сотовой связи  ' || PhoneNumber || ' невозможно выдать,т.к. номер находится в резерве!'); --Diana
      mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
      mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                     xClass_ID => mTkd_res_class,
                                                     xRes_ID   => ResourceID,
                                                     xDoc_ID   => mRMDocID,
                                                     xUser_ID  => irbis_user_id);
      if (mTD_ID is null) then null; end if;

    /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mTkd_res_class, ResourceID, 0, 0, 0, NULL)
         RETURNING tkd_id INTO mTkd_id;

         irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Телефонный номер ' || PhoneNumber || ' не найден в номерной емкости');
   END IF;

   -- сохранение созданной техкарты в документе - заявке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mTS_ID);

--   irbis_utl.sendPaperNextDepartment(mTS_ID);
   mHoldResult := irbis_is_core.ad_paper_hold(mTS_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
   IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
      RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
   END IF;

   irbis_is_core.write_irbis_activity_log('CreateMVNOTC - end',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", mHoldResult="' || TO_CHAR(mHoldResult) ||
                            '", mTelzone_ID="' || TO_CHAR(mTelzone_ID) ||
                            '", ResourceID="' || TO_CHAR(ResourceID) ||
                            '", TC="' || TO_CHAR(mTK_ID) ||
                            '", TS="' || TO_CHAR(mTS_ID) ||
                            '", PhoneNumber="' || PhoneNumber ||
                            '"',
                            RequestID,
                            NULL);

END CreateMVNOTC;

-- Создание заявления и техсправки для БП "Замена номера MVNO"
PROCEDURE CreateMVNOZmn
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   TKID            IN  NUMBER,   -- идентификатор Тех Карты
   PhoneNumber     IN  VARCHAR2, -- выбранный номер телефона
   MainParam       IN  VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   ResourceID      OUT NUMBER    -- идентификатор ресурса
) IS
/*
   CURSOR GetResourceID(cTelzone_ID NUMBER, cPhoneNumber VARCHAR2) IS
      SELECT num_id
     FROM rm_numbers
    WHERE num_number = cPhoneNumber;
       --AND num_telzona = cTelzone_ID;
*/
   mContragentID    NUMBER;
   mAccountID       NUMBER;
   mAbonementID     NUMBER;
   mOperatorName    ad_paper_attr.value_long%TYPE;

   mTelzone_ID      ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID     ad_papers.department_id%TYPE;

   mTemp            NUMBER;
   mContractHouse   NUMBER;

   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;               -- id содержания созданного документа
   mChildSubtype  ad_subtypes.id%TYPE;

   mAddress_ID      NUMBER;
   mAddress2_ID     NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;

   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTkd_res_class rm_tk_data.tkd_res_class%TYPE; -- тип базового ресурса в ТК, зависит от ConnectionType
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000
   mKeyParams     irbis_activity_log.parameters%TYPE;
   mHoldResult      VARCHAR2(2000);
   mNew_Phone     NUMBER;
   mRubDop NUMBER; --MExtraNumberAdd2
   mResState NUMBER;
   mTD_ID    number;
   mRMDocID  number;
BEGIN
   mKeyParams := 'PhoneNumber="' || PhoneNumber ||
                 '", TKID="' || TO_CHAR(TKID) ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreateMVNOZmn',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'           THEN mContragentID    := TO_NUMBER(x.value);
         WHEN 'AccountID'          THEN mAccountID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mContractHouse   := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'AccountCompanyBranchCode'      THEN mTelzone_ID   := 103;
         --WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.value;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         ELSE NULL;
      END CASE;
   END LOOP;

   mAddress_ID   := NULL;
   mAddress2_ID  := NULL;
   mTkd_res_class := 6;

   -- Проверка существования техкарты и телефонного номера в ней
   SELECT COUNT(1) INTO mTemp FROM rm_tk WHERE tk_id = TKID;
   IF mTemp > 0 THEN
      SELECT COUNT(1) INTO mTemp FROM rm_tk_data WHERE tkd_tk = TKID AND tkd_res_class = mTkd_res_class;
      IF mTemp = 0 THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не найден телефонный номер в техкарте ' || TO_CHAR(TKID));
      END IF;
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Техкарта ' || TO_CHAR(TKID) || ' не найдена');
   END IF;


   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
   mTK_type := tk_type_mvno;
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('CreateMVNOZmn', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      SELECT NVL((SELECT h.to_depart_id FROM ad_paper_history h WHERE h.paper_id = mDeclar_ID AND h.resolution_id = 1), mAbonOtdelID) INTO mAbonOtdelID FROM dual;
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="' || TO_CHAR(irbis_utl.BP_MVNOZmn) || '";' ||
                               'OBJECT="D";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) ||
                               '"',
                               RequestID);
      mSubtype_ID := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNOZmn) || '";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) ||
                                             '"');
      irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_MVNO'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mContragentID, 'IRBIS_CONTRAGENT',
                                               mAccountID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), TO_CHAR(mPriority));

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, irbis_utl.BP_MVNOZmn, MainParam);
   END IF;

   irbis_is_core.write_irbis_activity_log('defineSubtype',
                            'BP="' || TO_CHAR(irbis_utl.BP_MVNOZmn) || '";' ||
                            'OBJECT="T";' ||
                            'TKTYPE="' || TO_CHAR(mTK_type) ||
                            '"',
                            RequestID);
   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNOZmn) || '";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   -- ИЗМЕНЕНИЕ ТЕХКАРТЫ --------------------------------------------------------
/*
   OPEN GetResourceID(mTelzone_ID, PhoneNumber);
   FETCH GetResourceID INTO ResourceID;
   CLOSE GetResourceID;
*/

     --Для Смартс(филиал 103) своя номерная емкость
  IF mTelzone_ID=103 THEN
     SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = PhoneNumber AND num_telzona = 103), NULL) INTO ResourceID  FROM dual;
  ELSE
     SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = PhoneNumber AND num_telzona != 103), NULL) INTO ResourceID  FROM dual;
  END IF;

   mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
   IF (ResourceID IS NOT NULL) AND (ResourceID > 0) THEN
     SELECT count(1) INTO mRubDop FROM rm_rub_value WHERE rbv_entity = ResourceID AND rbv_record=463; --MExtraNumberAdd2
     irbis_utl.assertTrue((mRubDop=0), 'Данный номер сотовой связи  ' || PhoneNumber || ' является дополнительным!'); --MExtraNumberAdd2
    select count(1) INTO mResState from rm_resource where res_id=ResourceID and res_class=6 and res_astate=3;    ---Diana
    irbis_utl.assertTrue((mResState=0), 'Данный номер сотовой связи  ' || PhoneNumber || ' невозможно выдать,т.к. номер находится в резерве!'); --Diana

      for v1 in (select d.tkd_resource
                   from rm_tk_data d
                  where d.tkd_tk = TKID
                    and d.tkd_res_class = mTkd_res_class
                    and EXISTS (SELECT 1 FROM rm_rub_value WHERE rbv_entity = tkd_resource and rbv_record = 358)) loop
        mTD_ID := RM_TK_PKG.PureRebindResourceOntoData(xTK_ID => TKID,
                                                       xClass_ID => mTkd_res_class,
                                                       xNewRes_ID => ResourceID,
                                                       xOldRes_ID => v1.tkd_resource,
                                                       xDoc_ID => mRMDocID,
                                                       xUser_ID => irbis_user_id);
      end loop;
/*
      UPDATE rm_tk_data SET tkd_resource = ResourceID
      WHERE tkd_tk = TKID
      AND tkd_res_class = mTkd_res_class
      AND EXISTS (SELECT 1 FROM rm_rub_value WHERE rbv_entity = tkd_resource and rbv_record = 358); --MExtraNumberAdd2
*/
   ELSE
      IF LENGTH(PhoneNumber)=10 THEN
          SELECT rm_gen_resource.nextval into mNew_Phone FROM dual;
          INSERT INTO rm_resource
                  (res_id, res_class, res_astate, res_otdel,
                   last_move_type)
          VALUES (mNew_Phone, mTkd_res_class, 0, 1331,
                   0);
          --добавляем номер
          INSERT INTO rm_numbers
                  (num_id, num_number, num_telcode, num_telzona,
                   num_aon)
          VALUES (mNew_Phone, PhoneNumber, 58, 103,
                   0);
          --рублики
          INSERT INTO rm_rub_value (rbv_id, rbv_ecode, rbv_entity,rbv_record)
          VALUES (rm_gen_rub_value.nextval,8,mNew_Phone,358);
          for v1 in (select d.tkd_resource from rm_tk_data d where d.tkd_tk = TKID and d.tkd_res_class = mTkd_res_class) loop
            mTD_ID := RM_TK_PKG.PureRebindResourceOntoData(xTK_ID => TKID,
                                                           xClass_ID => mTkd_res_class,
                                                           xNewRes_ID => mNew_Phone,
                                                           xOldRes_ID => v1.tkd_resource,
                                                           xDoc_ID => mRMDocID,
                                                           xUser_ID => irbis_user_id);
          end loop;
          /*UPDATE rm_tk_data SET tkd_resource = mNew_Phone
          WHERE tkd_tk = TKID
          AND tkd_res_class = mTkd_res_class;*/
      ELSE
          RAISE_APPLICATION_ERROR(-20001, 'Телефонный номер ' || PhoneNumber || ' не найден в номерной емкости');
      END IF;
   END IF;

   -- сохранение созданной техкарты в документе - заявке
    irbis_is_core.attach_tk_to_paper(TKID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
    irbis_is_core.attach_tk_to_paper(TKID, mTS_ID);

   --irbis_utl.sendPaperNextDepartment(mTS_ID);
   mHoldResult := irbis_is_core.ad_paper_hold(mTS_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
   IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
      RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
   END IF;

END CreateMVNOZmn;

-- Закрытие MVNO
PROCEDURE TCCloseMVNO
(
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   TKID            IN  NUMBER,   -- идентификатор Тех Карты
   MainParam       IN  VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_type, tk_telzone, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID;

   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mTelzone_ID    ad_papers.telzone_id%TYPE;    -- id филиала
   mTK_status     rm_tk.tk_status_id%TYPE;      -- наименование (номер) техкарты

   mContragentID    NUMBER;
   mAccountID       NUMBER;
   mAbonementID     NUMBER;
   mContractHouse   NUMBER;
   mOperatorName    ad_paper_attr.value_long%TYPE;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;

   mAbonOtdelID     ad_papers.department_id%TYPE;
   mOrder_ID        ad_papers.id%TYPE;            -- id наряда

   mDeclar_ID       ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;               -- id содержания созданного документа
   mChildSubtype  ad_subtypes.id%TYPE;

   mAddress_ID      NUMBER;
   mAddress2_ID     NUMBER;

   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTkd_res_class rm_tk_data.tkd_res_class%TYPE; -- тип базового ресурса в ТК, зависит от ConnectionType
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000
   mHoldResult      VARCHAR2(2000);
   mKeyParams     irbis_activity_log.parameters%TYPE;

BEGIN
   mKeyParams := 'TKID="' || TO_CHAR(TKID) || '"';
   irbis_is_core.write_irbis_activity_log('TCCloseMVNO',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'           THEN mContragentID    := TO_NUMBER(x.value);
         WHEN 'AccountID'          THEN mAccountID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mContractHouse   := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
--         WHEN 'AccountCompanyBranchCode'      THEN mTelzone_ID   := 103;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         ELSE NULL;
      END CASE;
   END LOOP;

   mAddress_ID   := NULL;
   mAddress2_ID  := NULL;
   mTkd_res_class := 6;

   -- ПОИСК ТЕХНИЧЕСКОЙ КАРТЫ И ФИЛИАЛА ----------------------------------------
   IF TKID IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(TKID);
   FETCH GetTK INTO mTK_ID, mTK_type, mTelzone_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      checkKeyParams('TCCloseMVNO', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      SELECT NVL((SELECT h.to_depart_id FROM ad_paper_history h WHERE h.paper_id = mDeclar_ID AND h.resolution_id = 1), mAbonOtdelID) INTO mAbonOtdelID FROM dual;
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      mSubtype_ID := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNOClose) || '";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) ||
                                             '"');
      irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_MVNO'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mContragentID, 'IRBIS_CONTRAGENT',
                                               mAccountID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), TO_CHAR(mPriority));

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, irbis_utl.BP_MVNOClose, MainParam);
   END IF;

   mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(irbis_utl.BP_MVNOClose) || '";' ||
                                            'OBJECT="O";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   -- дата исполнения
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_PLAN', TO_CHAR(SYSDATE, 'DD.MM.YYYY'), TO_CHAR(SYSDATE, 'DD.MM.YYYY'));

   -- сохранение созданной техкарты в документе - заявке
   irbis_is_core.attach_tk_to_paper(TKID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - ордере
   irbis_is_core.attach_tk_to_paper(TKID, mOrder_ID);

   mHoldResult := irbis_is_core.ad_paper_hold(mOrder_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
   IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
      RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
   END IF;

   irbis_is_core.write_irbis_activity_log('TCCloseMVNO - end',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", mHoldResult="' || TO_CHAR(mHoldResult) ||
                            '", mTelzone_ID="' || TO_CHAR(mTelzone_ID) ||
                            '", Order="' || TO_CHAR(mOrder_ID) ||
                            '"',
                            RequestID,
                            NULL);

EXCEPTION
   WHEN OTHERS THEN
      irbis_is_core.write_irbis_activity_log('TCCloseMVNO - error',
                               'RequestID="' || TO_CHAR(RequestID) ||
                               '", SQLCODE="' || TO_CHAR(SQLCODE) ||
                               '", SQLERRM="' || SQLERRM ||
                               '"',
                               RequestID,
                               NULL);
      RAISE;
END TCCloseMVNO;

PROCEDURE CreateSIPTC
(
   RequestID        IN  NUMBER,
   LineID           IN  NUMBER,
   PhoneNumber      IN  VARCHAR2,
   PhoneCategory    IN  NUMBER,
   CallBarringState IN  NUMBER,
   ConnectionType   IN  VARCHAR2,
   EquipmentNumber  IN  VARCHAR2,
   Login            IN  VARCHAR2,
   Password         IN  VARCHAR2,
   DeviceType       IN  VARCHAR2,
   MainParam        IN  VARCHAR2
)
IS

   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   vCreatable     NUMBER;                       -- признак возможности создания абонента
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   --mDocType       ad_subtypes.type_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;

   mAbonOtdelID   ad_papers.department_id%TYPE;
   --mIsTel         NUMBER;  -- признак того, что тел. устанавливается на существующую линию (что пока не может быть)
   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mState         NUMBER;
   mMessage       VARCHAR2(2000);
   mSecondName    VARCHAR2(200);
   mFirstName     VARCHAR2(200);
   mPatrName      VARCHAR2(200);
   mOrgName       VARCHAR2(200);
   mTemp          NUMBER;

   mClientID       NUMBER;    -- идентификатор клиента в IRBiS
   mClientName     VARCHAR2(300);  -- наименование клиента
   mClientTypeID   NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
   mAbonementID    NUMBER;    -- идентификатор абонемента
   --mSpecClient     NUMBER;    -- признак спец.абонента (0 - обычный абонент, 1 - спец.абонент)
   mHouseID        NUMBER;    -- идентификатор дома, адрес подключения которого интересует
   mApartment      VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
   mContactPhone   VARCHAR2(200);  -- контактный телефон абонента
   mOperatorName   VARCHAR2(200);   -- ФИО оператора создавшего заявление
   --mTkd_id         NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority       NUMBER;
   mPriorityLong   VARCHAR2(200);
   mPassword       VARCHAR2(200);

   mTD_ID          number;
   mRMDocID        number;

   CURSOR CheckResAtAdr(aADR NUMBER, aCLASS NUMBER, aRES NUMBER) IS
      SELECT COUNT(d.tkd_id)
        FROM rm_tk_address a, rm_tk_data d
       WHERE a.adr_id        = aADR
         AND a.adr_tk        = d.tkd_tk
         AND d.tkd_res_class = aCLASS
         AND d.tkd_resource  = aRES;

   CURSOR GetFXSPort(aEquipmentNumber VARCHAR2) IS
      SELECT ep.prt_id, e.equ_id
        FROM rm_equipment e, rm_res_prop_value v, rm_res_property rp,
             rm_equip_unit eu, rm_equip_port ep
       WHERE v.rvl_res = e.equ_id
         AND v.rvl_prop_id = rp.rpr_id
         AND v.rvl_res_type = rp.rpr_restype
         AND rp.rpr_strcod = 'SERIAL'
         AND rp.rpr_restype IN (1263, 1083)               -- типы устройств "SIP адаптер" и "Модем SAGEM"
         AND LOWER(v.rvl_value) = LOWER(aEquipmentNumber) -- serial number
         AND eu.un_equip = e.equ_id
         AND ep.prt_unit = eu.un_id
         AND ep.prt_type = 1323                           -- порт FXS
         AND rm_pkg.GetResState(ep.prt_id, 2) = 0
    ORDER BY ep.prt_name;

   mVZ            VARCHAR2(5);
   mMG            VARCHAR2(5);
   mMN            VARCHAR2(5);

   mAttrValue     ad_paper_attr.value%TYPE;
   mAttrValuLong  ad_paper_attr.value_long%TYPE;

   mParentExists  NUMBER;
   mCategID       NUMBER;
   mProc          NUMBER;
   mBaseResClass  NUMBER;
   mKeyParams     irbis_activity_log.PARAMETERS%TYPE;

   mAbonent2_ID    ad_paper_content.abonent_id%TYPE; -- идентификатор лицевого счета, который использует новое оборудование
   mAbonent2_numb NUMBER; --номер лицевого счета, который использует новое оборудование
   mTK_info VARCHAR2(300); --полное название ТК, который использует новое оборудование

   mNewEquipID    rm_equipment.equ_id%TYPE; -- id нового оборудования
   --получение информации по занятым FXS-портам для id оборудования
   CURSOR GetInfoUsedPorts (aEquipId rm_equipment.equ_id%TYPE) IS
   SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id, t.tk_id, d.tkd_id
      FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d, rm_tk t
     WHERE e.equ_id = aEquipId
       AND e.equ_id = eu.un_equip
       AND eu.un_id = ep.prt_unit
       AND ep.prt_type = 1323
       AND rm_pkg.GetResState(ep.prt_id, 2) > 0
       AND d.tkd_resource = ep.prt_id
       AND d.tkd_res_class = 2
       AND d.tkd_tk=t.tk_id
       AND t.tk_status_id !=0
       AND t.tk_type = tk_type_sip
       order by ep.prt_name;

   --mProfile  VARCHAR2(200); --наименование профайла
   --mProfileID  NUMBER; -- id профайла
   mVirtual NUMBER; --признак подключения виртуального номера (услуга Многоканальный телефон)
   mNumID NUMBER;    -- идентификатор номерной емкости
   mTariffPlanName  ad_paper_attr.value_long%TYPE;
   mConnectionType       ad_paper_attr.VALUE%TYPE;
   mAddress_otherTK ad_paper_content.address_id%TYPE;
BEGIN
   mPassword := irbis_is_core.get_enc_val(Password, enc_key);
   mKeyParams := 'LineID="' || TO_CHAR(LineID) ||
                 '", PhoneNumber="' || PhoneNumber ||
                 '", PhoneCategory="' || PhoneCategory ||
                 '", CallBarringState="' || CallBarringState ||
                 '", ConnectionType="' || ConnectionType ||
                 '", EquipmentNumber="' || EquipmentNumber ||
                 '", Login="' || Login ||
                 '", Password="' || mPassword ||
                 '", DeviceType="' || DeviceType ||
                 '"';
   irbis_is_core.write_irbis_activity_log('CreateSIPTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ' || mKeyParams,
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mApartment   := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
         WHEN 'ClientName'         THEN mClientName    := x.value;
         WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.value);
         WHEN 'TariffPlanName'     THEN mTariffPlanName    := x.value;
         WHEN 'ConnectionType'     THEN mConnectionType    := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   -- 0 = новая линия, >0 = линия, на которую следует устанавливать, -1 = заявка на обследование
   IF LineID IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Невозможно определить линию!');
   END IF;

   -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
   -- (mState не проверять, т.к. 1=генерировать исключение)
   mHouseOnly    := 0;
   mPrivateHouse := 0;
   irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
   mAddress2_ID  := NULL;

   mBaseResClass := 7;
   -- Если был передан идентификатор первичного ресурса, проверить его существование
   IF LineID > 0 THEN
      -- проверка существования указанной линии на данном адресе
      OPEN CheckResAtAdr(mAddress_ID, 7, LineID); FETCH CheckResAtAdr INTO mTemp; CLOSE CheckResAtAdr;
      IF mTemp = 0 THEN
         -- Установка sip телефона может быть осуществлена на действующее подключение СПД
         IF (UPPER(ConnectionType) LIKE '%ETHERNET%') OR (UPPER(ConnectionType) LIKE '%STREET%') OR (UPPER(ConnectionType) LIKE '%GPON%') THEN
            -- проверка существования указанного порта на данном адресе
            OPEN CheckResAtAdr(mAddress_ID, 2, LineID); FETCH CheckResAtAdr INTO mTemp; CLOSE CheckResAtAdr;
            IF mTemp = 0 THEN
               RAISE_APPLICATION_ERROR(-20001, 'Порт с переданным идентификатором не найден!');
            ELSE
               mBaseResClass := 2;
            END IF;
         ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Линия с переданным идентификатором не найдена!');
         END IF;
      END IF;
   END IF;

   irbis_utl.assertTrue( UPPER(SUBSTR(irbis_utl.getIrbisPhoneCategoryName(PhoneCategory), 1, 4)) != 'ТЕСТ',
                         'Необходимо выбрать другую категорию телефона');

   -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА ------------------------------------------------------
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   IF (ConnectionType LIKE '%virtnum%') THEN
   mVirtual:=1;
   END IF;

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mParentExists := 0;
   SELECT COUNT(id) INTO mParentExists
     FROM ad_papers p
    WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
      AND p.object_code = 'D';

   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mParentExists > 0) THEN
      SELECT p.id INTO mDeclar_ID FROM ad_papers p
       WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
         AND p.object_code = 'D'
         AND ROWNUM < 2;

      checkKeyParams('CreateSIPTC', mDeclar_ID, mKeyParams);      -- проверка, не поменялись ли ключевые параметры
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      --mChildSubtype := irbis_is_core.get_child_subtype(mSubtype_ID, 'T');
      mProc := irbis_is_core.get_proc_by_paper(mDeclar_ID);
      IF mProc = irbis_utl.BP_SIP THEN
         mTK_type := tk_type_sip;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить бизнес-процесс');
      END IF;
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="T";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(LineID)) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      IF (mChildSubtype IS NULL) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не определен вид техсправки');
      END IF;

   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- определение бизнес-процесса
         mProc    := irbis_utl.BP_SIP;
         mTK_type := tk_type_sip;

      -- ОПРЕДЕЛЕНИЕ ВИДА ---------------------------------------------------------

      mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="D";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(LineID)) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'OBJECT="T";' ||
                                               'CLIENTTYPE="' || TO_CHAR(mClientTypeID) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(LineID)) || '";' ||
                                               'CONNECTION="' || UPPER(ConnectionType) || '"');
      IF (mSubtype_ID IS NULL) OR (mChildSubtype IS NULL) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не определен вид документа');
      END IF;

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_TEL'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         --UPDATE ad_papers SET department_id = mAbonOtdelID WHERE id = mDeclar_ID;
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
      ELSE
         -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
         -- тип услуги, необходимая формальность
         IF (LineID = 0) OR (LineID = -1) THEN
            mCuslType_ID := 1;
         ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается.');
         END IF;

         -- КОНТРАГЕНТ, АБОНЕНТ ------------------------------------------------------
         irbis_is_core.get_client_name(mClientTypeID,mClientName, mSecondName, mFirstName, mPatrName, mOrgName);

         -- для устанавливаемых услуг допускается создание контрагента и лицевого счета
         vCreatable := 1;
         irbis_is_core.GetAbonentID(mSecondName,
                      mFirstName,
                      mPatrName,
                      mOrgName,
                      mClientID,
                      mAddress_ID,
                      mTelzone_ID,
                      mClientTypeID - 1,
                      1,
                      mAbonent_ID,
                      mContragent_ID,
                      mState,
                      mMessage,
                      1);
         IF mState <> 0 THEN
            RAISE_APPLICATION_ERROR(-20001, mMessage);
         END IF;

         -- СОЗДАНИЕ ЗАЯВЛЕНИЯ -------------------------------------------------------
         ad_queue.ad_create_single_request(mDeclar_ID,
                                           mContent_ID,
                                           mSubtype_ID,   -- вид документа
                                           SYSDATE,       -- дата создания документа
                                           '',            -- примечание к документу
                                           mTelzone_ID,   -- филиал
                                           irbis_user_id, -- пользователь
                                           mCuslType_ID,  -- тип услуги
                                           mContragent_ID,-- ID контрагента
                                           mAddress_ID,   -- адрес установки
                                           mAbonent_ID,   -- ID лицевого счета
                                           mAddress2_ID,  -- дополнительный адрес
                                           NULL,          -- id кросса
                                           NULL,          -- id шкафа
                                           NULL,          -- дата постановки в очередь
                                           NULL,          -- резолюция (очередь)
                                           NULL,          -- льгота очередника
                                           NULL,          -- примечание к постановке в очередь
                                           0,             -- action code (0=nothing,1=hold,2=hold,...)
                                           NULL,          -- резолюция
                                           NULL,          -- отдел
                                           NULL,          -- текущий пункт прохождения
                                           NULL,          -- новый пункт прохождения
                                           NULL);         -- номер документа
      END IF;

      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      -- Направление ЗАЯВЛЕНИЯ в нужный отдел
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      --  ВЗ,МГ,МН
      mVZ := 'Да';
      mMG := 'Да';
      mMN := 'Да';
      CASE CallBarringState
         WHEN 2 THEN
            mMN := 'Нет';
         WHEN 3 THEN
            mMN := 'Нет';
            mMG := 'Нет';
         WHEN 10 THEN
            mMN := 'Нет';
            mMG := 'Нет';
            mVZ := 'Нет';
         ELSE
            mVZ := 'Да';
            mMG := 'Да';
            mMN := 'Да';
      END CASE;

      -- Заполнение Атрибутов
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTRAAREAL', mVZ, mVZ);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTERCITY', mMG, mMG);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'C_INTERNATIONAL', mMN, mMN);

      mAttrValue := TO_CHAR(PhoneCategory);
      mAttrValuLong := irbis_utl.getIrbisPhoneCategoryName(PhoneCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PHONECATEGORY', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CATEG_AON', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

      mAttrValue := TO_CHAR(CallBarringState);
      CASE CallBarringState
         WHEN 1 THEN
            mAttrValuLong := 'Открыто все - ВЗ,МГ,МН';
         WHEN 2 THEN
            mAttrValuLong := 'Закрыта МН связь';
         WHEN 3 THEN
            mAttrValuLong := 'Закрыты выходы на МГ,МН связь';
         WHEN 10 THEN
            mAttrValuLong := 'Закрыто все - ВЗ,МГ,МН';
         ELSE
            mAttrValuLong := '';
      END CASE;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CALLBARRINGSTATE', mAttrValue, mAttrValuLong);

      IF LineID < 1 THEN
         mAttrValue    := 1;
         mAttrValuLong := 'На новую линию';
      ELSE
         mAttrValue    := 2;
         mAttrValuLong := 'На существующую';
      END IF;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_OPERATION', mAttrValue, mAttrValuLong);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_TP', mTariffPlanName, mTariffPlanName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_NUM', TO_CHAR(PhoneNumber), PhoneNumber);
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
   END IF;

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0);

   -- установка назначенного номера оператором (восстановление)
   irbis_is_core.update_paper_attr(mTS_ID, 'CUSL_NUM', PhoneNumber, PhoneNumber);
   irbis_is_core.update_paper_attr(mTS_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;

   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   IF (mAbonementID IS NOT NULL) THEN
     mTemp := RM_TK_PKG.InsertServiceData(xTK_ID   => mTK_ID,
                                          xExt_ID  => 0,
                                          xSvc_ID  => mAbonementID,
                                          xSvcCode => 'IRBIS',
                                          xSvcName => 'Абонемент IRBiS');
     /* INSERT INTO rm_tk_usl (usl_rec, usl_tk, usl_id, usl_idext, usl_strcod, usl_name)
       VALUES (rm_gen_tk_usl.NEXTVAL, mTK_ID, mAbonementID, 0, 'IRBIS', 'Абонемент IRBiS');*/
   END IF;

 mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
 IF mVirtual = 1 THEN
   -- Добавление номера SIP РТУ в ТК
   --поиск номерной емкости в ТУ в 10-значном виде
   SELECT nvl((SELECT q.id  FROM
                      (SELECT n.num_id as id,
                      DECODE(LENGTH(n.num_number),10, '', TO_CHAR(t.numcode))|| n.num_number as phonenum
                      FROM rm_numbers n, list_telcode t WHERE t.zone_id = n.num_telzona) q
               WHERE q.phonenum = PhoneNumber)
   , NULL) INTO mNumID FROM dual;
   --Проверки выбора номерной емкости
   irbis_utl.assertNotNull(mNumID, 'Телефонный номер ' || PhoneNumber || ' не найден в номерной емкости');
   irbis_utl.assertTrue((rm_pkg.GetResState(mNumID, 6) not in (1,2)), 'Телефонный номер занят!');
   irbis_utl.assertTrue((AD_RULES_EXTENDED.CheckNumberRTU(mNumID)!=0), 'Неправильно выбран Sip-номер!');
   --Добавление номерной емкости в ТК
   mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                  xClass_ID => RM_CONSTS.RM_RES_CLASS_NUMBER,
                                                  xRes_ID   => mNumID,
                                                  xPos      => 0,
                                                  xDoc_ID   => mRMDocID,
                                                  xUser_ID  => irbis_user_id);
   if (mTD_ID is null) then null; end if;
   /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                          tkd_isdel, tkd_is_new_res, tkd_parent_id)
    VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 6, mNumID, 0, 0, 0, NULL)
      RETURNING tkd_id INTO mTkd_id;
   irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

 ELSE
    IF (mChildSubtype = 11665 AND PhoneNumber IS NOT NULL) THEN
       -- Добавление номера SIP РТУ в ТК
       -- поиск номерной емкости в ТУ в 10-значном виде
       SELECT nvl((SELECT q.id  FROM
                          (SELECT n.num_id as id,
                          DECODE(LENGTH(n.num_number),10, '', TO_CHAR(t.numcode))|| n.num_number as phonenum
                          FROM rm_numbers n, list_telcode t WHERE t.zone_id = n.num_telzona) q
                   WHERE q.phonenum = PhoneNumber)
       , NULL) INTO mNumID FROM dual;
       --Проверки выбора номерной емкости
       irbis_utl.assertNotNull(mNumID, 'Телефонный номер ' || PhoneNumber || ' не найден в номерной емкости');
       irbis_utl.assertTrue((rm_pkg.GetResState(mNumID, 6) not in (1,2)), 'Телефонный номер занят!');
       irbis_utl.assertTrue((AD_RULES_EXTENDED.CheckNumberRTU(mNumID)!=0), 'Неправильно выбран Sip-номер!');
       --Добавление номерной емкости в ТК
       mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                      xClass_ID => RM_CONSTS.RM_RES_CLASS_NUMBER,
                                                      xRes_ID   => mNumID,
                                                      xPos      => 0,
                                                      xDoc_ID   => mRMDocID,
                                                      xUser_ID  => irbis_user_id);
       if (mTD_ID is null) then null; end if;
   END IF;
   -- Добавление логина и пароля SIP в свойства ТК
   MERGE INTO rm_tk_prop_value v
      USING (SELECT p.id property_id FROM rm_tk_property p WHERE tktype = tk_type_sip AND p.strcod = 'SIP_LOGIN')
      ON    (v.prop_id = property_id AND v.tk_id   = mTK_ID)
      WHEN MATCHED
         THEN UPDATE
              SET value = Login
      WHEN NOT MATCHED
         THEN INSERT
              VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, Login, 0);

   MERGE INTO rm_tk_prop_value v
      USING (SELECT p.id property_id FROM rm_tk_property p WHERE tktype = tk_type_sip AND p.strcod = 'SIP_PASSWORD')
      ON    (v.prop_id = property_id AND v.tk_id   = mTK_ID)
      WHEN MATCHED
         THEN UPDATE
              SET value = mPassword
      WHEN NOT MATCHED
         THEN INSERT
              VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, mPassword, 0);

   MERGE INTO rm_tk_prop_value v
      USING (SELECT p.id property_id FROM rm_tk_property p WHERE tktype = tk_type_sip AND p.strcod = 'TK_PMP')
      ON    (v.prop_id = property_id AND v.tk_id   = mTK_ID)
      WHEN MATCHED
         THEN UPDATE
              SET value = 'Да'
      WHEN NOT MATCHED
         THEN INSERT
              VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, 'Да', 0);

   IF (mChildSubtype <> 11665) THEN
   -- Добавить порт в ТК
      OPEN GetFXSPort(EquipmentNumber);
      mTemp := NULL;
      FETCH GetFXSPort INTO mTemp,mNewEquipID;
      CLOSE GetFXSPort;

      irbis_utl.assertNotNull(mTemp, '<*-M2000: У оборудования с серийным номером ' || EquipmentNumber
                                  || ' нет свободных портов FXS!-*>');

      -- Проверка, что другие порты оборудования принадлежат данному л/с --TODO
      FOR mNewEquip IN GetInfoUsedPorts(mNewEquipID) LOOP
         -- поиск идентификатора лицевого счета для занятого порта нового оборудования
         /*SELECT NVL((SELECT d.abonent_id FROM
                           (SELECT ape.abonent_id, MAX(ape.paper_id) paperid
                              FROM ad_paper_extended ape
                             WHERE ape.tk_id = mNewEquip.tk_id
                             GROUP BY ape.abonent_id) d, ad_papers ap
                          WHERE ap.ID = paperid AND ap.subtype_id!=8843
              ), NULL)INTO mAbonent2_ID FROM dual;
              IF mAbonent2_ID IS  NULL THEN
                SELECT account_id  INTO mAbonent2_ID FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
                WHERE us.usl_tk = mNewEquip.tk_id AND us.usl_id = cc.object_no;
              END IF;

         IF (mAbonent2_ID IS NOT NULL) AND (mAbonent_ID IS NOT NULL) AND (mAbonent2_ID!=mAbonent_ID) THEN
          SELECT account_numb INTO mAbonent2_numb FROM billing.TAccount@irbis WHERE object_no = mAbonent2_ID;
          SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                       '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                  FROM  rm_tk t WHERE t.tk_id = mNewEquip.tk_id), NULL)INTO mTK_info FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером ' || EquipmentNumber
          || ' используется на другом лицевом счете (' ||mAbonent2_numb||') в ТК '||mTK_info);
         END IF;*/
         -- поиск идентификатора адреса для занятого порта нового оборудования
         SELECT NVL((SELECT adr_id FROM rm_tk_address WHERE adr_tk = mNewEquip.tk_id
                   ), NULL)INTO mAddress_otherTK FROM dual;

         IF (mAddress_otherTK IS NOT NULL) AND (mAddress_ID IS NOT NULL) AND (mAddress_otherTK!=mAddress_ID) THEN
          SELECT account_id  INTO mAbonent2_ID FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
          WHERE us.usl_tk = mNewEquip.tk_id AND us.usl_id = cc.object_no;
          SELECT account_numb INTO mAbonent2_numb FROM billing.TAccount@irbis WHERE object_no = mAbonent2_ID;
          SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                       '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                  FROM  rm_tk t WHERE t.tk_id = mNewEquip.tk_id), NULL)INTO mTK_info FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером ' || EquipmentNumber
          || ' используется по другому адресу, на лицевом счете (' ||mAbonent2_numb||') в ТК '||mTK_info);
         END IF;
      END LOOP;

      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                     xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                     xRes_ID   => mTemp,
                                                     xPos      => 1,
                                                     xDoc_ID   => mRMDocID,
                                                     xUser_ID  => irbis_user_id);
      if (mTD_ID is null) then null; end if;
      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
      VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 2, mTemp, 1, 0, 1, NULL)
        RETURNING tkd_id INTO mTkd_id;*/

/* --mCreateChangeModemTS
     mProfileID:=7;  --для SIP в настоящее время профайл SIP_12
    SELECT NAME INTO mProfile FROM rm_lst_equip_profile WHERE ID = mProfileID;
      --присвоение свойству профайла
      MERGE INTO rm_tk_prop_value v
     USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PROFILE' and p.tktype=tk_type_sip)
     ON    (v.prop_id = property_id AND v.tk_id = mTK_ID)
     WHEN MATCHED
        THEN UPDATE
             SET value = mProfile, value_cod = mProfileID
     WHEN NOT MATCHED
        THEN INSERT
             VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, mProfile, mProfileID);
*/
    --Добавление в ТК оборудование (возможно ниже запись о свойстве профиля можно удалить)
    irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP_ID', mNewEquipID, mNewEquipID);
    AddCPEtoTK(mTK_ID, mNewEquipID, null, mRMDocID); --mCreateChangeModemTS
    END IF;

   -- Добавить в ТК SIP-лицензию
   SELECT MIN(q.res_id)
   INTO mTemp
   FROM (SELECT r.res_id
           FROM rm_resource r, rm_sip_license sl
          WHERE r.res_class = RM_CONSTS.RM_RES_CLASS_SIP_LICENSE -- 12   -- SIP лицензия
            AND r.res_astate = 1
            AND r.res_id = sl.id
            AND r.RES_OTDEL = 1131
            AND rm_pkg.GetResState(r.res_id, r.res_class) = 0) q;
   irbis_utl.assertNotNull(mTemp, 'Не удалось найти свободную SIP лицензию!');

   mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                  xClass_ID => RM_CONSTS.RM_RES_CLASS_SIP_LICENSE,
                                                  xRes_ID   => mTemp,
                                                  xPos      => 1,
                                                  xDoc_ID   => mRMDocID,
                                                  xUser_ID  => irbis_user_id);
   if (mTD_ID is null) then null; end if;
   /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                           tkd_isdel, tkd_is_new_res, tkd_parent_id)
   VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 12, mTemp, 1, 0, 1, NULL)
     RETURNING tkd_id INTO mTkd_id;*/
 END IF;
   -- при установке на существующую линию в техсправке сразу должны быть ЛД
   IF LineID > 0 THEN
     mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                    xClass_ID => mBaseResClass,
                                                    xRes_ID   => LineID,
                                                    xPos      => 0,
                                                    xDoc_ID   => mRMDocID,
                                                    xUser_ID  => irbis_user_id);
     if (mTD_ID is null) then null; end if;
      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id, tkd_algo_switch)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mBaseResClass, LineID, 0, 0, 0, NULL, NULL)
         RETURNING tkd_id INTO mTkd_id;
         irbis_utl.addTKHisData(mTkd_id, irbis_user_id); --сохранение истории ТК*/

      --  на существующий xDSL выполнить копирование портов СПД
      IF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_LINE_DATA) THEN
        for v1 in (SELECT mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 npp
                     FROM (SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                             FROM rm_tk_data d, rm_equip_port p
                            WHERE d.tkd_tk IN (SELECT d2.tkd_tk     -- ТК, имеющая в ресурсах данную линию
                                                 FROM rm_tk_data d2
                                                WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                                                  AND d2.tkd_resource = LineID
                                                  AND d2.tkd_is_new_res = RM_CONSTS.RM_TK_DATA_WORK_NONE)
                              AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                              AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                              AND d.tkd_isdel = 0
                              AND d.tkd_is_new_res != RM_CONSTS.RM_TK_DATA_WORK_FROM
                              AND d.tkd_resource = p.prt_id
                              AND p.prt_type IN (42, 789, 792, 804) ) dd)
          loop
            mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                           xClass_ID => v1.tkd_res_class,
                                                           xRes_ID   => v1.tkd_resource,
                                                           xPos      => v1.npp,
                                                           xDoc_ID   => mRMDocID,
                                                           xUser_ID  => irbis_user_id);
         end loop;
         /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                 tkd_isdel, tkd_is_new_res, tkd_parent_id)
         SELECT rm_gen_tk_data.NEXTVAL, mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1,
                0, 0, NULL
           FROM (
            SELECT DISTINCT d.tkd_resource, d.tkd_res_class
              FROM rm_tk_data d, rm_equip_port p
             WHERE d.tkd_tk IN (SELECT d2.tkd_tk     -- ТК, имеющая в ресурсах данную линию
                                  FROM rm_tk_data d2
                                 WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_LINE_DATA
                                   AND d2.tkd_resource = LineID
                                   AND d2.tkd_is_new_res = RM_CONSTS.RM_TK_DATA_WORK_NONE)
               AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != 0
               AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
               AND d.tkd_isdel = 0
               AND d.tkd_is_new_res != RM_CONSTS.RM_TK_DATA_WORK_FROM
               AND d.tkd_resource = p.prt_id
               AND p.prt_type IN (42, 789, 792, 804) ) dd;*/

      -- на GPON (или Домовые сети), выполнить копирование портов из ТК GPON (или Домовые сети)
      ELSIF (mBaseResClass = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT) THEN
        for v1 in (SELECT mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1 npp
                     FROM (SELECT DISTINCT d.tkd_resource, d.tkd_res_class
                             FROM rm_tk_data d
                              -- действующая ТК типа GPON по данному адресу, имеющая в ресурсах данный порт
                            WHERE d.tkd_tk IN (SELECT d2.tkd_tk
                                                 FROM rm_tk_data d2, rm_tk t2
                                                WHERE d2.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP_PORT
                                                  AND d2.tkd_resource = LineID
                                                  AND d2.tkd_is_new_res = RM_CONSTS.RM_TK_DATA_WORK_NONE
                                                  AND t2.tk_id = d2.tkd_tk
                                                  AND t2.tk_type IN (tk_type_gpon, tk_type_etth, tk_type_ethernet)
                                                  AND t2.tk_status_id != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                                                  AND EXISTS (SELECT 1 FROM rm_tk_address WHERE adr_tk = d2.tkd_tk AND adr_id = mAddress_ID))
                              AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != RM_CONSTS.RM_TK_STATUS_ARCHIVE
                              AND d.tkd_res_class IN (RM_CONSTS.RM_RES_CLASS_EQUIP_PORT, RM_CONSTS.RM_RES_CLASS_LINE_DATA)
                              AND d.tkd_resource != LineID  -- уже был добавлен в ТК
                              AND d.tkd_isdel = 0
                              AND d.tkd_is_new_res = RM_CONSTS.RM_TK_DATA_WORK_NONE ) dd)
        loop
          mTD_ID := RM_TK_PKG.PureEmbindResourceIntoData(xTK_ID    => v1.mTK_ID,
                                                         xClass_ID => v1.tkd_res_class,
                                                         xRes_ID   => v1.tkd_resource,
                                                         xPos      => v1.npp,
                                                         xDoc_ID   => mRMDocID,
                                                         xUser_ID  => irbis_user_id);
        end loop;

        /* INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                 tkd_isdel, tkd_is_new_res, tkd_parent_id)
         SELECT rm_gen_tk_data.NEXTVAL, mTK_ID, dd.tkd_res_class, dd.tkd_resource, ROWNUM + 1,
                0, 0, NULL
           FROM (
            SELECT DISTINCT d.tkd_resource, d.tkd_res_class
              FROM rm_tk_data d
             -- действующая ТК типа GPON по данному адресу, имеющая в ресурсах данный порт
             WHERE d.tkd_tk IN (SELECT d2.tkd_tk
                                  FROM rm_tk_data d2, rm_tk t2
                                 WHERE d2.tkd_res_class = 2
                                   AND d2.tkd_resource = LineID
                                   AND d2.tkd_is_new_res = 0
                                   AND t2.tk_id = d2.tkd_tk
                                   AND t2.tk_type IN (tk_type_gpon, tk_type_etth, tk_type_ethernet)
                                   AND t2.tk_status_id != 0
                                   AND EXISTS (SELECT 1 FROM rm_tk_address WHERE adr_tk = d2.tkd_tk AND adr_id = mAddress_ID))
               AND (SELECT t.tk_status_id FROM rm_tk t WHERE t.tk_id = d.tkd_tk) != 0
               AND d.tkd_res_class IN (2, 7)
               AND d.tkd_resource != LineID  -- уже был добавлен в ТК
               AND d.tkd_isdel = 0
               AND d.tkd_is_new_res = 0 ) dd;*/

      END IF;
   END IF;

   -- сохранение созданной техкарты в документе - заявке
   IF mCategID = 7 THEN
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE id = mContent_ID;
      -- сохранение созданной техкарты в документе - техсправке
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE paper_id = mTS_ID;
   ELSE
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE id = mContent_ID;
      -- сохранение созданной техкарты в документе - техсправке
      UPDATE ad_paper_content SET bron_id = mTK_ID WHERE paper_id = mTS_ID;
   END IF;

   irbis_utl.sendPaperNextDepartment(mTS_ID);

END CreateSIPTC;

PROCEDURE GetAddressID
(
   aIRBIS_HOUSE  IN  NUMBER,              -- идентификатор дома в Ирбис
   aAPARTMENT    IN  VARCHAR2,            -- наименование помещения (квартиры)
   aADDRESS_ID   OUT NUMBER,              -- возвращаемое значение (в случае успешного нахождения)
   aHOUSEONLY    IN OUT NUMBER,           -- возвращаемый признак, что дом содержит квартиры (но не был указан номер квартиры)
   aPRIVATEHOUSE IN OUT NUMBER,           -- возвращаемый признак, что дом не имеет квартир
   aCAN_RAISE    IN  NUMBER DEFAULT 0,    -- определяет, должна ли процедура сама генерировать исключение, когда адрес не найден (1=надо генерировать)
   aSTATE        OUT NUMBER               -- возвращаемое состояние (0=успешно, 1=ошибки)
)
IS
BEGIN
   irbis_is_core.GetAddressID(aIRBIS_HOUSE,
                              aAPARTMENT,
                              aADDRESS_ID,
                              aHOUSEONLY,
                              aPRIVATEHOUSE,
                              aCAN_RAISE,
                              aSTATE);

END;

-- Создание заявления и ТС на подключение КТВ и ЦКТВ
-- 1. Разбор XML-коллекции MainParam
-- 2. Определение филиала, БП и типа ТК
-- 3. Определение отделов, куда будут направлены документы
-- 4. Определение адреса
-- 5. Определение вида заявления, ТС
-- 6. Проверка категории заявления (создание только для 7 категории)
-- 7. Определение типа услуги
-- 8. Создание заявления
-- 9. Отправка заявления в абон отдел
-- 10. Привязка id абонемента и тип услуги к заявлению
-- 11. Заполнение Атрибутов заявления
-- 12. Привязка ID заявки Ирбис к заявлению
-- 13. Создание ТС на основании заявления, заполнение атрибутов ТС
-- 14. Создание ТК
-- 15. Поиск устройства (нахождение id) и проверка, что данное устройство свободно
-- 16. Процесс добавления устройства в ТК
-- 17. Сохранение созданной ТК в заявлении и ТС
-- 18. Отправка ТС в следующий отдел
PROCEDURE CreateKTVTC
(
   RequestID       IN NUMBER,   -- идентификатор заявки в IRBiS
   ResourceID      IN NUMBER,   -- идентификатор первичного ресурса (порта), на который следует произвести подключение
   EquipmentNumber IN VARCHAR2, -- серийный номер оборудования
   DeviceType      IN VARCHAR2, -- тип оборудования
   MainParam       IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE;
   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;     -- id содержания созданного документа
   mAddress_ID    NUMBER;
   mAddress2_ID   NUMBER;
   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mState         NUMBER;
   mTK_type       rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mChildSubtype  ad_subtypes.id%TYPE;
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000
   mAbonent_ID    ad_paper_extended.abonent_id%TYPE; -- идентификатор лицевого счета в IRBiS
   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTK_Number     rm_tk.tk_number%TYPE;         -- наименование (номер) техкарты
   mTK_ID         rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mAbonementID   NUMBER;   -- идентификатор абонемента
   mHouseID       NUMBER;   -- идентификатор дома, адрес подключения которого интересует
   mApartment     VARCHAR2(50); -- номер квартиры (офиса), адрес подключения которого интересует
   mContactPhone  ad_paper_attr.value_long%TYPE; -- контактный телефон абонента
   mOperatorName  ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление
   mClientID      NUMBER;   -- идентификатор клиента  в IRBiS
   mTariffPlanName         VARCHAR2(100); -- текущий ТП КТВ
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);

   mProc          NUMBER;
   mConnectionType       ad_paper_attr.VALUE%TYPE;
   mTemp          NUMBER;
   mMessage       VARCHAR2(300);
   mTkd_id        rm_tk_data.tkd_id%type;
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   mContractTypeID NUMBER; --Идентификатор типа абонемента

   mTD_ID         number;
   mRMDocID       number;
   mHoldResult    VARCHAR2(2000);

   CURSOR GetResourcesFromGPON (ResourceID NUMBER, mAddress_ID NUMBER) IS
    SELECT DISTINCT d.tkd_id,d.tkd_resource
        -- into mTkd_id,mTemp
              FROM rm_tk_data d, rm_tk t
             WHERE d.tkd_tk IN (SELECT d2.tkd_tk FROM rm_tk_data d2
                                 WHERE d2.tkd_resource = ResourceID
                                   AND d2.tkd_res_class = 2
                                   AND d2.tkd_is_new_res != 2)
--               AND d.tkd_res_class = 2  -- только порты
               AND d.tkd_res_class IN (2)  -- только порты и лин. данные
               AND d.tkd_tk = t.tk_id
               AND t.tk_type IN (tk_type_dsl_new, tk_type_dsl_old, tk_type_ethernet, tk_type_etth, tk_type_gpon, tk_type_wimax, tk_type_iptv)  -- только СПД и IPTV
               AND t.tk_status_id != 0  -- действующие ТК
           --    AND (d.tkd_resource NOT IN (0, ResourceID) AND d.tkd_res_class != 2)  -- базовый ресурс был добавлен выше
               AND EXISTS (SELECT 1 FROM rm_tk_address a WHERE a.adr_tk = t.tk_id AND a.adr_id = mAddress_ID)
               AND NOT EXISTS (SELECT 1 FROM rm_tk_data WHERE tkd_is_new_res = 2 AND tkd_parent_id = d.tkd_id)
               AND d.tkd_is_new_res <> 2;

   CURSOR GetResourcesFromGPON_LDN (ResourceID NUMBER, mAddress_ID NUMBER) IS
          SELECT DISTINCT d.tkd_id,d.tkd_resource
          into mTkd_id,mTemp
              FROM rm_tk_data d, rm_tk t
             WHERE d.tkd_tk IN (SELECT d2.tkd_tk FROM rm_tk_data d2
                                 WHERE d2.tkd_resource = ResourceID
                                   AND d2.tkd_res_class = 2
                                   AND d2.tkd_is_new_res != 2)
--               AND d.tkd_res_class = 2  -- только порты
               AND d.tkd_res_class =7  -- только лин. данные
               AND d.tkd_tk = t.tk_id
               AND t.tk_type IN (tk_type_dsl_new, tk_type_dsl_old, tk_type_ethernet, tk_type_etth, tk_type_gpon, tk_type_wimax, tk_type_iptv)  -- только СПД и IPTV
               AND t.tk_status_id != 0  -- действующие ТК
           --    AND (d.tkd_resource NOT IN (0, ResourceID) AND d.tkd_res_class != 2)  -- базовый ресурс был добавлен выше
               AND EXISTS (SELECT 1 FROM rm_tk_address a WHERE a.adr_tk = t.tk_id AND a.adr_id = mAddress_ID)
               AND NOT EXISTS (SELECT 1 FROM rm_tk_data WHERE tkd_is_new_res = 2 AND tkd_parent_id = d.tkd_id);

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateKTVTC',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '", DeviceType="' || DeviceType ||
                            '", ResourceID="' || TO_CHAR(ResourceID) ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID       := TO_NUMBER(x.VALUE);
         WHEN 'ContractHouseID'    THEN mHouseID           := TO_NUMBER(x.VALUE);
         WHEN 'ContractAppartment' THEN mApartment         := x.VALUE;
         WHEN 'ClientPhones'       THEN mContactPhone      := x.VALUE;
         WHEN 'RequestCreator'     THEN mOperatorName      := x.VALUE;
         WHEN 'ClientID'           THEN mClientID          := TO_NUMBER(x.VALUE);
         WHEN 'TariffPlanName'     THEN mTariffPlanName    := x.value;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.VALUE;
         WHEN 'Priority'           THEN mPriority          := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'          THEN mAbonent_ID        := TO_NUMBER(x.VALUE);
         WHEN 'ConnectionType'     THEN mConnectionType    := x.VALUE;
         WHEN 'ContractCommonType' THEN mContractCommonType:= x.VALUE;
         WHEN 'ContractTypeID'     THEN mContractTypeID    := TO_NUMBER(x.VALUE);
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА ------------------------------------------------------
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- Проверка правильного выбора базового ресурса
   IF ResourceID > 0 THEN
         mTemp :=0;
        SELECT nvl((SELECT tkd_tk FROM (
                                SELECT d.tkd_tk
                                  FROM rm_tk_data d, rm_equip_port p
                                 WHERE d.tkd_res_class = 2 --формальность: ресурс должен присутствовать в другой ТК
                                   AND d.tkd_isdel = 0 AND d.tkd_is_new_res IN (0, 1)
                                   and d.tkd_resource  = ResourceID
                                   AND p.prt_id = d.tkd_resource
                                   AND p.prt_type IN (884,1023,383) -- тип порта : КТВ-аб
                                ORDER BY d.tkd_tk DESC)
        WHERE ROWNUM < 2), NULL) INTO mTemp FROM dual;
      irbis_utl.assertNotNull(mTemp, 'Неправильно выбран ресурс!');
   END IF;

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      -- определение бизнес-процесса и типа ТК
      mProc := irbis_is_core.get_proc_by_paper(mDeclar_ID);
      IF mProc = 19 THEN
         IF mConnectionType = 'Линия СКПТ' THEN mTK_type := tk_type_ckpt;
         ELSE mTK_type := tk_type_cable;
         END IF;
      ELSIF mProc = 30 THEN
         mTK_type := tk_type_digitalcable;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить бизнес-процесс');
      END IF;

      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="T";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(ResourceID)) || '";' ||
                                               'CONNECTION="' || UPPER(mConnectionType) || '"');  /* TODO: Проверить дерево!! */
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЯ АДРЕСА ----------------------------------------------------
      -- (mState не проверять, т.к. 1=генерировать исключение)
      mHouseOnly    := 0;
      mPrivateHouse := 0;
      irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
      mAddress2_ID  := NULL;

      -- определение бизнес-процесса и типа ТК
      IF mContractTypeID = 102335284 or mContractTypeID =211526099 THEN --ktvgpon
        mProc:=19;
         IF mConnectionType = 'Линия СКПТ' THEN mTK_type := tk_type_ckpt;
         ELSE mTK_type := tk_type_cable;
         END IF;
      ELSIF mContractTypeID = 418896809 THEN
        mProc:=30;
        mTK_type := tk_type_digitalcable;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Неизвестный тип подключения');
      END IF;

      -- ОПРЕДЕЛЕНИЕ ВИДА ------------------------------------------------------
      mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="D";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(ResourceID)) || '";' ||
                                               'CONNECTION="' || UPPER(mConnectionType) || '"'); /* TODO: Проверить дерево!! */
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления');

      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="T";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(ResourceID)) || '";' ||
                                               'CONNECTION="' || UPPER(mConnectionType) || '"'); /* TODO: Проверить дерево!! */
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
      -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ -----------------------------------------------
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_CABLE'), NULL)
           INTO mCuslType_ID FROM dual;
      -- СОЗДАНИЕ ЗАЯВЛЕНИЯ ----------------------------------------------------
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- привязка ТК, id абонемента и тип услуги к заявлению
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      -- Заполнение Атрибутов заявления
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ABONEMENT_ID', TO_CHAR(mAbonementID), TO_CHAR(mAbonementID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_TP', mTariffPlanName, mTariffPlanName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
      IF mConnectionType = 'Линия СКПТ' THEN
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      elsif mConnectionType = 'Кабельное телевидение GPON' THEN   ----ktvgpon
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mConnectionType, mConnectionType);
      ELSE irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', mContractCommonType, mContractCommonType);
      END IF;
      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
   END IF;
   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0);
   -- Заполнение Атрибутов ТС
   irbis_is_core.update_paper_attr(mTS_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);

   -- СОЗДАНИЕ ТЕХКАРТЫ --------------------------------------------------------
   -- наименование техкарты должно первоначально совпадать с названием документа
   SELECT prefix || '-' || TO_CHAR(pnumber) INTO mTK_Number FROM ad_papers WHERE id = mTS_ID;
   -- создание техкарты
   rm_doc.ad_create_tk(mTK_ID,        -- id тех карты
                       mTK_type,      -- тип тех карты (Телефон, DSL), зависит от устанавливаемой услуги
                       mTelzone_ID,   -- филиал
                       irbis_user_id, -- пользователь
                       mTK_Number,    -- наименование
                       SYSDATE,       -- дата создания тех карты
                       '',            -- примечание
                       mAddress_ID,   -- основной адрес установки
                       mAddress2_ID,  -- дополнительный адрес установки
                       1,             -- тип брони (техсправка, после снятия, ...), в данном случае "тех. справка"
                       NULL
                      );
   -- добавление информации об операторе, создавшем ТК
   irbis_is_core.addTKStateUser(mTK_ID, mOperatorName);
   -- добавление ссылки на абонемент Irbis в техкарту
   irbis_is_core.attach_usl_to_tk(mTK_ID, mAbonementID, 'IRBIS', 'Абонемент IRBiS');

   -- Проверка
   IF (EquipmentNumber is not NULL) AND (mTK_type != tk_type_digitalcable) THEN
    RAISE_APPLICATION_ERROR(-20001, 'Оборудование предоставляется только для Цифрового телевидения!');
   END IF;

   -- Добавление устройства в ТК------------------------------------------------
   IF mTK_type = tk_type_digitalcable THEN
      SELECT NVL((SELECT e.equ_id
                    FROM rm_equipment e
                   WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1
                     AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 2535 AND LOWER(v.rvl_value) = LOWER(EquipmentNumber))
                   --  AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 2534 AND LOWER(v.rvl_value) = LOWER(DeviceType)) --Тенет пока не раелизовал на 04.06.2014
                 ), NULL) INTO mTemp FROM dual;
      irbis_utl.assertNotNull(mTemp, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);
      IF rm_pkg.GetResState(mTemp, 1) != 0 THEN
         SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                            '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                       FROM rm_tk_data d, rm_tk t
                      WHERE d.tkd_resource = mTemp
                        AND d.tkd_res_class = 1
                        AND d.tkd_tk = t.tk_id
                        AND t.tk_status_id != 0
                        AND rownum < 2), NULL)
           INTO mMessage FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование не свободно, закреплено за ТК ' || mMessage);
      END IF;
      mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                     xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                     xRes_ID   => mTemp,
                                                     xPos      => 1,
                                                     xDoc_ID   => mRMDocID,
                                                     xUser_ID  => irbis_user_id);
      if (mTD_ID is null) then null; end if;
      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
      VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 1, mTemp, 1, 0, 1, NULL)
        RETURNING tkd_id INTO mTkd_id;
      irbis_utl.addTKHisData(mTkd_id,irbis_user_id);*/
      IF ResourceID > 0 THEN
        mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                       xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                       xRes_ID   => ResourceID,
                                                       xPos      => 1,
                                                       xDoc_ID   => mRMDocID,
                                                       xUser_ID  => irbis_user_id);
        if (mTD_ID is null) then null; end if;
             /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
             VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 2, ResourceID, 1, 0, 1, NULL)
             RETURNING tkd_id INTO mTkd_id;
       irbis_utl.addTKHisData(mTkd_id,irbis_user_id);*/
      END IF;
   END IF;



  ---Запись порта в тк КТВ GPON из тк СПД  ---Ticket#2018092710404638
     IF mConnectionType = 'Кабельное телевидение GPON'  THEN
         --добавление всех портов из ТК GPON
         OPEN GetResourcesFromGPON(ResourceID, mAddress_ID);
         LOOP
                FETCH GetResourcesFromGPON INTO mTkd_id,mTemp;
                EXIT WHEN GetResourcesFromGPON%NOTFOUND;
                       INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                           tkd_isdel, tkd_is_new_res, tkd_parent_id)
                    values (rm_gen_tk_data.NEXTVAL, mTK_ID, 2, mTemp, 1, 0, 0, NULL)
                     RETURNING tkd_id INTO mTkd_id;

                   irbis_utl.addTKHisData(mTkd_id, irbis_user_id);
          END LOOP;
          CLOSE GetResourcesFromGPON;

         mTkd_id := null;
         OPEN GetResourcesFromGPON_LDN(ResourceID, mAddress_ID);
         LOOP
                FETCH GetResourcesFromGPON_LDN INTO mTkd_id,mTemp;
                EXIT WHEN GetResourcesFromGPON_LDN%NOTFOUND;
                       INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                           tkd_isdel, tkd_is_new_res, tkd_parent_id)
                    values (rm_gen_tk_data.NEXTVAL, mTK_ID, 7, mTemp, 1, 0, 0, NULL)
                     RETURNING tkd_id INTO mTkd_id;

                   irbis_utl.addTKHisData(mTkd_id, irbis_user_id);
          END LOOP;
          CLOSE GetResourcesFromGPON_LDN;
    END IF;

   -- сохранение созданной техкарты в документе - заявлении
   irbis_is_core.attach_tk_to_paper(mTK_ID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
   irbis_is_core.attach_tk_to_paper(mTK_ID, mTS_ID);
   irbis_utl.sendPaperNextDepartment(mTS_ID);
END CreateKTVTC;


-- Получение внутреннего номера оборудования по его серийному номеру
-- Возвращает внутренний номер или -1, если оборудование не найдено
FUNCTION GetEquipmentLicense
(
   EquipmentNumber IN  VARCHAR2  -- серийный номер оборудования
) RETURN VARCHAR2
IS
mEquipID          rm_tk_data.tkd_resource%TYPE; -- идентификатор оборудования
mEquipmentLicense VARCHAR2(100);                -- внутренний номер оборудования ЦКТВ
BEGIN
   irbis_is_core.write_irbis_activity_log('GetEquipmentLicense',
                            'EquipmentNumber="' || EquipmentNumber || '"',
                            NULL);
   SELECT NVL((SELECT e.equ_id
                FROM rm_equipment e
               WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1
                 AND EXISTS (SELECT 1 FROM rm_res_prop_value v WHERE v.rvl_res = e.equ_id AND v.rvl_prop_id = 2535 AND LOWER(v.rvl_value) = LOWER(EquipmentNumber))
             ), NULL) INTO mEquipID FROM dual;
   IF (mEquipID IS NULL) THEN
      RETURN -1;
   ELSE
     SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                 WHERE v.rvl_res = mEquipID
                   AND v.rvl_prop_id = rp.rpr_id --id свойства
                   AND v.rvl_res_type = rp.rpr_restype --тип оборудования
                   AND rp.rpr_strcod = 'S_C_NO'
                   AND rp.rpr_restype = 2574), -- тип оборудования"Оборудование ЦКТВ"), --TO DO: WORK 2574
          NULL) INTO mEquipmentLicense FROM dual;
      RETURN mEquipmentLicense;
   END IF;
END GetEquipmentLicense;

-- Создание повторного наряда на установку SIP РТУ, ЦКТВ в случае замены неисправного оборудования
PROCEDURE CreateConnOrderChangeEquip(
   RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
   DateMontComment  IN VARCHAR2, -- комментарий к дате назначения монтера
   RequestComment   IN VARCHAR2, -- комментарий оператора к наряду
   DateMontWish     IN DATE,     -- желаемая дата подключения
   EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
   DeviceType       IN VARCHAR2, -- тип оборудования
   MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
) IS

   CURSOR GetParentPaper(aREQUEST  NUMBER) IS
      SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
         AND r.paper_id = p.id
         AND p.parent_id IS NULL;
   mParent_ID     ad_papers.id%TYPE;
   mParentSubtype ad_subtypes.id%TYPE;
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mOtdel_ID      ad_papers.department_id%TYPE;
   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;
   mOrder_ID      ad_papers.id%TYPE;

   mProc          irbis_subtypes.proc%TYPE;
   --mAbonementID   NUMBER;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id созданной техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);
   mActivationDate  DATE;
   mSourceOfSales   VARCHAR2(300);
   mOperatorName  VARCHAR2(200);
   mContactPhone  VARCHAR2(200);

   mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты

   oldConnectionType   VARCHAR2(200); -- текущий тип подключения (voip, аналог и т.п.)
   newConnectionType   VARCHAR2(200); -- выбранный тип подключения (voip, аналог и т.п.)
   --AuthenticationType  VARCHAR2(200);
   mResult       BOOLEAN;

   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   mNewEquipID    rm_equipment.equ_id%TYPE; -- id нового оборудования TODO
   mOldEquipID    rm_equipment.equ_id%TYPE; -- id старого оборудования TODO
   mTemp          NUMBER;
   --mPortID        rm_tk_data.tkd_resource%TYPE;
   mMessage       VARCHAR2(300);
   mResOld        rm_tk_data.tkd_id%TYPE;
   --mTkd_id        NUMBER;

   mAbonent2_ID    ad_paper_content.abonent_id%TYPE; -- идентификатор лицевого счета, который использует новое оборудование
   mAbonent2_numb NUMBER; --номер лицевого счета, который использует новое оборудование
   mTK_info VARCHAR2(300); --полное название ТК, который использует новое оборудование

   --Определение id оборудования по серийному номеру для тип устройств "CPE" или "Оборудование ЦКТВ"
   CURSOR GetEquipmentID (aEquipmentNumber rm_res_prop_value.rvl_value%TYPE) IS
   SELECT e.equ_id
     FROM rm_equipment e
    WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1 --возможность добавления устройства в ТК
      AND EXISTS (SELECT 1 FROM rm_res_prop_value v, rm_res_property rp
                   WHERE v.rvl_res = e.equ_id
                     AND v.rvl_prop_id = rp.rpr_id --id свойства
                     AND v.rvl_res_type = rp.rpr_restype --тип устройства
                     AND rp.rpr_strcod in ( 'SERIAL','S_NUMBER')
                     AND rp.rpr_restype IN (2574, 1083) -- типы устройств "CPE" или "Оборудование ЦКТВ"
                     AND LOWER(v.rvl_value) = LOWER(aEquipmentNumber));

   --Определение информации старого оборудования ЦКТВ
   CURSOR GetEquipmentOldID (aTK_ID rm_tk.tk_id%TYPE) IS
   SELECT d.tkd_id, d.tkd_resource
     FROM rm_tk_data d
    WHERE d.tkd_tk = aTK_ID
      AND d.tkd_res_class = 1;

   --Определение информации старого оборудования SIP
   CURSOR GetEquipmentSIPOldID (aTK_ID rm_tk.tk_id%TYPE) IS
     SELECT d.tkd_id, eu.un_equip
       FROM rm_tk_data d, rm_equip_unit eu, rm_equip_port ep
      WHERE d.tkd_tk = aTK_ID
        AND d.tkd_res_class = 2
        AND d.tkd_resource = ep.prt_id
        AND ep.prt_type = 1323    -- FXS порт
        AND ep.prt_unit = eu.un_id;

    CURSOR GetFXSPort(aEquipmentNumber VARCHAR2) IS
      SELECT ep.prt_id
        FROM rm_equipment e, rm_res_prop_value v, rm_res_property rp,
             rm_equip_unit eu, rm_equip_port ep
       WHERE v.rvl_res = e.equ_id
         AND v.rvl_prop_id = rp.rpr_id
         AND v.rvl_res_type = rp.rpr_restype
         AND rp.rpr_strcod = 'SERIAL'
         AND rp.rpr_restype IN ( 1083)               -- типы устройств "SIP адаптер" и "Модем SAGEM"
         AND LOWER(v.rvl_value) = LOWER(aEquipmentNumber) -- serial number
         AND eu.un_equip = e.equ_id
         AND ep.prt_unit = eu.un_id
         AND ep.prt_type = 1323                           -- порт FXS
         AND rm_pkg.GetResState(ep.prt_id, 2) = 0
    ORDER BY ep.prt_name;

       --получение информации по занятым FXS-портам для id оборудования
     CURSOR GetInfoUsedPorts (aEquipId rm_equipment.equ_id%TYPE) IS
     SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id, t.tk_id, d.tkd_id
        FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d, rm_tk t
       WHERE e.equ_id = aEquipId
         AND e.equ_id = eu.un_equip
         AND eu.un_id = ep.prt_unit
         AND ep.prt_type = 1323
         AND rm_pkg.GetResState(ep.prt_id, 2) > 0
         AND d.tkd_resource = ep.prt_id
         AND d.tkd_res_class = 2
         AND d.tkd_tk=t.tk_id
         AND t.tk_status_id !=0
         AND t.tk_type = tk_type_sip
         order by ep.prt_name;

   --mProfile  VARCHAR2(200); --наименование профайла
   --mProfileID  NUMBER; -- id профайла
   mAddress_otherTK ad_paper_content.address_id%TYPE;
   mAddress_ID ad_paper_content.address_id%TYPE;
   mAuthenticationType   ad_paper_attr.value%TYPE; --MChangeEquip
   mConnectionType       ad_paper_attr.value%TYPE; --MChangeEquip
   mLineID        NUMBER; --MChangeEquip

   mTD_ID         number;
   mRMDocID       number;
   mTariffPlanName VARCHAR2(200);

BEGIN

   irbis_is_core.write_irbis_activity_log('CreateConnOrderChangeEquip',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", DateMontComment="' || DateMontComment ||
                            '", RequestComment="' || RequestComment ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '", DeviceType="' || DeviceType ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientPhones'       THEN mContactPhone    := x.VALUE;
         WHEN 'ActivationDate'     THEN mActivationDate  := TO_DATE(x.value, 'DD.MM.YYYY HH24:MI:SS');
         WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.VALUE;
         WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
         WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   OPEN GetParentPaper(RequestID);
   FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
   CLOSE GetParentPaper;
   irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

   mProc  := irbis_utl.getProcByPaper(mParent_ID);
   mTK_ID := irbis_utl.getTKByPaper(mParent_ID);
   SELECT NVL((SELECT tk_type FROM rm_tk WHERE tk_id = mTK_ID), NULL) INTO mTK_type FROM dual;

   --необязательная проверка состояния ТК
   SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
   irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

   IF mProc=29 THEN
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                               'PARENT_SUBTYPE="' || TO_CHAR(mParentSubtype) ||
                                               '"');
   ELSIF mProc=30 THEN
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) ||
                                               '"');
   ELSIF mProc=21 THEN
       ad_rules.get_attr_value(mParent_ID, 'CONNECTION_TYPE', mResult, newConnectionType);
       ad_rules.get_attr_value(mParent_ID, 'OLD_CONNECTION_TYPE', mResult, oldConnectionType);

       mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                                'OBJECT="O";' ||
                                                'CONNECTION="' || UPPER(newConnectionType) || '";' ||
                                                'OLDCONNECTION="' || UPPER(oldConnectionType) ||
                                                '"');
   ELSIF mProc=3 THEN --MChangeEquip
       ad_rules.get_attr_value(mParent_ID, 'AUTHENTICATION_TYPE', mResult, mAuthenticationType);
       ad_rules.get_attr_value(mParent_ID, 'CONNECTION_TYPE', mResult, mConnectionType);
       SELECT COUNT(1) INTO mLineID
       FROM ad_paper_attr
       WHERE paper_id = mParent_ID AND strcod = 'CUSL_NUM';
       mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="O";' ||
                                               'AUTHENTICATION="' || UPPER(mAuthenticationType) || '";' ||
                                               'LINE="' || TO_CHAR(SIGN(mLineID)) || '";' ||
                                               'CONNECTION="' || UPPER(mConnectionType) ||
                                               '"');
   END IF;
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

   -- TODO: обновить заявление

   -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mOrder_ID,
                        mChildSubtype,
                        mParent_ID,
                        mParentSubtype,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_COMMENT', DateMontComment, DateMontComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
   irbis_is_core.update_paper_attr(mOrder_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_ACTIV', TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
   irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
   irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

   mRMDocID := RM_DOC.PaperToRMDocument(mParent_ID);

--1. поиск нового оборудования
   OPEN GetEquipmentID(EquipmentNumber);
   FETCH GetEquipmentID INTO mNewEquipID;
      IF GetEquipmentID%NOTFOUND THEN
      CLOSE GetEquipmentID;
      RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);
      END IF;
   CLOSE GetEquipmentID;

IF    mTK_type IN (tk_type_digitalcable)THEN
    --замена оборудования для ЦКТВ
      --2. проверка существования старого оборудования в ТК
        OPEN GetEquipmentOldID(mTK_ID);
        FETCH GetEquipmentOldID INTO mResOld, mOldEquipID ;
          IF GetEquipmentOldID%NOTFOUND THEN
          CLOSE GetEquipmentOldID;
           RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||'старое оборудование');
          ELSIF mOldEquipID = mNewEquipID THEN
           RAISE_APPLICATION_ERROR(-20001, 'Оборудование с введенным серийным номером уже присутствует в данной ТК');
          END IF;
        CLOSE GetEquipmentOldID;

     --3. Проверка свободности нового оборудования
     IF rm_pkg.GetResState(mNewEquipID, 1) != 0 THEN
        SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                           '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                      FROM rm_tk_data d, rm_tk t
                     WHERE d.tkd_resource = mNewEquipID
                       AND d.tkd_res_class = 1
                       AND d.tkd_tk = t.tk_id
                       AND t.tk_status_id != 0
                       AND rownum < 2), NULL)
          INTO mMessage FROM dual;
        RAISE_APPLICATION_ERROR(-20001, 'Устройство не свободно, закреплено за ТК ' || mMessage);
     END IF;

      --4. Замена на новое оборудование в ТК
      IF mProc=21 THEN
        for v1 in (select d.tkd_res_class res_class, d.tkd_resource from rm_tk_data d where d.tkd_id = mResOld and d.tkd_tk = mTK_ID) loop
          mTD_ID := RM_TK_PKG.PureRebindResourceOntoData(xTK_ID => mTK_ID,
                                                         xClass_ID => v1.res_class,
                                                         xNewRes_ID => mNewEquipID,
                                                         xOldRes_ID => v1.tkd_resource,
                                                         xDoc_ID => mRMDocID,
                                                         xUser_ID => irbis_user_id);
        end loop;
       /*  UPDATE rm_tk_data SET tkd_resource = mNewEquipID
          WHERE tkd_id = mResOld and tkd_tk = mTK_ID
          RETURNING tkd_id INTO mTkd_id;
         irbis_utl.addTKHisData(mTkd_id, irbis_user_id); */
      ELSE
        mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                       xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                       xRes_ID   => mNewEquipID,
                                                       xParent_ID => mResOld,
                                                       xPos      => 1,
                                                       xDoc_ID   => mRMDocID,
                                                       xUser_ID  => irbis_user_id);
        if (mTD_ID is null) then null; end if;
         /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                 tkd_isdel, tkd_is_new_res, tkd_parent_id)
         VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 1, mNewEquipID, 1, 0, 1, mResOld)
          RETURNING tkd_id INTO mTkd_id;*/
      END IF;
     --добавление в историю ТК информацию о добавлении ресурса в ТК
      /*irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

 ELSIF mTK_type = tk_type_sip THEN
    --замена оборудования для SIP
    --2. проверка существования порта старого оборудования в ТК
      OPEN GetEquipmentSIPOldID(mTK_ID);
      FETCH GetEquipmentSIPOldID INTO mResOld, mOldEquipID ;
        IF GetEquipmentSIPOldID%NOTFOUND THEN
        CLOSE GetEquipmentSIPOldID;
         RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||'старое оборудование');
        ELSIF mOldEquipID = mNewEquipID THEN
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование с введенным серийным номером уже присутствует в данной ТК');
        END IF;
      CLOSE GetEquipmentSIPOldID;

    --3. Проверка управляемости PMP нового оборудования
      mTemp:=0;
         SELECT count(1) INTO mTemp
           FROM rm_res_property rp, rm_res_prop_value rpv
          WHERE rpv.rvl_res = mNewEquipID
            AND rpv.rvl_prop_id = rp.rpr_id
            AND rp.rpr_restype = rpv.rvl_res_type
            AND UPPER(rp.rpr_strcod) = UPPER('PMP')
            AND UPPER(rpv.rvl_value) = UPPER('Да');
      IF (mTemp < 1)
      THEN RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером : ' || EquipmentNumber||' не управляется PMP');
      END IF;

    --4. Поиск свободных портов нового оборудования
      OPEN GetFXSPort(EquipmentNumber);
      mTemp := NULL;
      FETCH GetFXSPort INTO mTemp;
      CLOSE GetFXSPort;
      irbis_utl.assertNotNull(mTemp, '<*-M2000: У оборудования с серийным номером ' || EquipmentNumber
                                  || ' нет свободных портов FXS!-*>');

     -- поиск идентификатора адреса для данной ТК
     SELECT NVL((SELECT adr_id FROM rm_tk_address WHERE adr_tk = mTK_ID
               ), NULL)INTO mAddress_ID FROM dual;

    --5. Проверка, что другие порты оборудования принадлежат данному л/с
      FOR mNewEquip IN GetInfoUsedPorts(mNewEquipID) LOOP
         -- поиск идентификатора лицевого счета для занятого порта нового оборудования
         /*SELECT NVL((SELECT d.abonent_id FROM
                           (SELECT ape.abonent_id, MAX(ape.paper_id) paperid
                              FROM ad_paper_extended ape
                             WHERE ape.tk_id = mNewEquip.tk_id
                             GROUP BY ape.abonent_id) d, ad_papers ap
                          WHERE ap.ID = paperid AND ap.subtype_id!=8843
              ), NULL)INTO mAbonent2_ID FROM dual;
              IF mAbonent2_ID IS  NULL THEN
                SELECT account_id  INTO mAbonent2_ID FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
                WHERE us.usl_tk = mNewEquip.tk_id AND us.usl_id = cc.object_no;
              END IF;

         IF (mAbonent2_ID IS NOT NULL) AND (mAbonent_ID IS NOT NULL) AND (mAbonent2_ID!=mAbonent_ID) THEN
          SELECT account_numb INTO mAbonent2_numb FROM billing.TAccount@irbis WHERE object_no = mAbonent2_ID;
          SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                       '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                  FROM  rm_tk t WHERE t.tk_id = mNewEquip.tk_id), NULL)INTO mTK_info FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером ' || EquipmentNumber
          || ' используется на другом лицевом счете (' ||mAbonent2_numb||') в ТК '||mTK_info);
         END IF;*/

         -- поиск идентификатора адреса для занятого порта нового оборудования
         SELECT NVL((SELECT adr_id FROM rm_tk_address WHERE adr_tk = mNewEquip.tk_id
                   ), NULL)INTO mAddress_otherTK FROM dual;

         IF (mAddress_otherTK IS NOT NULL) AND (mAddress_ID IS NOT NULL) AND (mAddress_otherTK!=mAddress_ID) THEN
          SELECT account_id  INTO mAbonent2_ID FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
          WHERE us.usl_tk = mNewEquip.tk_id AND us.usl_id = cc.object_no;
          SELECT account_numb INTO mAbonent2_numb FROM billing.TAccount@irbis WHERE object_no = mAbonent2_ID;
          SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                       '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                  FROM  rm_tk t WHERE t.tk_id = mNewEquip.tk_id), NULL)INTO mTK_info FROM dual;
         RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером ' || EquipmentNumber
          || ' используется по другому адресу, на лицевом счете (' ||mAbonent2_numb||') в ТК '||mTK_info);
         END IF;

      END LOOP;

      --6. Замена порта оборудования в ТК (при свободных портов нового оборудования)
      mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                     xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                     xRes_ID   => mTemp,
                                                     xParent_ID => mResOld,
                                                     xPos      => 1,
                                                     xDoc_ID   => mRMDocID,
                                                     xUser_ID  => irbis_user_id);
      if (mTD_ID is null) then null; end if;
      /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
      VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 2, mTemp, 1, 0, 1,mResOld)
        RETURNING tkd_id INTO mTkd_id;
      --добавление в историю ТК информацию о добавлении ресурса в ТК
      irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

    /*mProfileID:=7;  --для SIP в настоящее время профайл SIP_12
    SELECT NAME INTO mProfile FROM rm_lst_equip_profile WHERE ID = mProfileID;
      --присвоение свойству профайла
      MERGE INTO rm_tk_prop_value v
     USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PROFILE' and p.tktype=tk_type_sip)
     ON    (v.prop_id = property_id AND v.tk_id = mTK_ID)
     WHEN MATCHED
        THEN UPDATE
             SET value = mProfile, value_cod = mProfileID
     WHEN NOT MATCHED
        THEN INSERT
             VALUES (rm_gen_tk_prop_value.NEXTVAL, mTK_ID, property_id, mProfile, mProfileID);*/
     --Замена старого оборудования mOldEquipID на новое mNewEquipID в ТК (есть проверка незанятости оборудования по другому адресу)
     irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_EQUIP_ID', mNewEquipID, mNewEquipID);
     AddCPEtoTK(mTK_ID, mNewEquipID, mOldEquipID, mRMDocID);
        ELSIF  mTK_type in (tk_type_wifiguest,  --MChangeEquip
                    tk_type_etth,
                    tk_type_wimax,
                    tk_type_ethernet,
                    tk_type_gpon,
                    tk_type_dsl_old, tk_type_dsl_new,
                    tk_type_wifimetroethernet, tk_type_wifiadsl,
                    tk_type_iptv) THEN --CPE
      --2. проверка существования старого оборудования в ТК
        OPEN GetEquipmentOldID(mTK_ID);
        FETCH GetEquipmentOldID INTO mResOld, mOldEquipID ;
          IF GetEquipmentOldID%NOTFOUND THEN
          CLOSE GetEquipmentOldID;
           RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||'старое оборудование');
          ELSIF mOldEquipID = mNewEquipID THEN
           RAISE_APPLICATION_ERROR(-20001, 'Оборудование с введенным серийным номером уже присутствует в данной ТК');
          END IF;
        CLOSE GetEquipmentOldID;
      --Замена старого оборудования mOldEquipID на новое mNewEquipID в ТК (есть проверка незанятости оборудования по другому адресу)
     irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_EQUIP_ID', mNewEquipID, mNewEquipID);
     AddCPEtoTK(mTK_ID, mNewEquipID, mOldEquipID, mRMDocID);
 ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Для данной услуги не предусмотрена замена оборудования!');
 END IF;

   --Если установка, то при запуске наряда ресурсы должны быть переключены.
  -- IF mProc in (29,30) THEN
   IF mProc in (3,29,30) and mChildSubtype not in (9528,8733,9607,10228,9788) THEN --MChangeEquip
     -- перевод ресурсов в обычное состояние
     --RM_PKG.DoSwitchResourceTK(mTK_ID, NULL, irbis_user_id, 1);
     RM_TK_PKG.SwitchTechData(xTK_ID => mTK_ID,
                              -- Изменение
                              xDoc_ID => mRMDocID,
                              xUser_ID => irbis_user_id
                             );

   END IF;

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

END CreateConnOrderChangeEquip;

function PrepareParam(ParamName in varchar2,ParamValue in varchar2,ParamDescription in varchar2) return varchar2 is
begin
  return '<PARAM><PARAM_NAME>'||ParamName||'</PARAM_NAME><VALUE>'||ParamValue||'</VALUE><PARAM_DESC>'||ParamDescription||'</PARAM_DESC></PARAM>'; -- dbms_xmlgen.convert(ParamValue)
end;
-- <02.07.2015-Точкасова М.А.> Определение оборудования в данной ТК.
--<02.02.2016-Точкасова М.А.> - учет, что оборудования может быть несколько в ТК (Workorder#: 2015022700005-10)
function GetEquipParam(ContractTCID IN NUMBER) return varchar2 is
  EquipParam varchar2(32767);

  mTK_ID         rm_tk.tk_id%TYPE;             -- id техкарты
  mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
  mRes           rm_tk_data.tkd_resource%TYPE; -- ресурс оборудования
   CURSOR GetTK (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT tk_id, tk_status_id
        FROM rm_tk
       WHERE tk_id = aTK_ID
       and tk_status_id != 0;
   CURSOR GetEquipRes (aTK_ID  rm_tk.tk_id%TYPE) IS
      SELECT distinct e.equ_id
        FROM rm_tk t, rm_tk_data d,rm_equip_unit eu, rm_equip_port ep, rm_equipment e
       WHERE t.tk_id = aTK_ID
         AND d.tkd_tk = t.tk_id
         AND d.tkd_res_class = 2
         AND d.tkd_is_new_res = 0
         AND d.tkd_resource = ep.prt_id
         AND ep.prt_type in (43,1323)             -- порт оборудования необязательное условие (порт FXS, Ethernet)
         AND eu.un_id = ep.prt_unit
         AND eu.un_equip = e.equ_id
         AND e.equ_type in (1083)
   UNION
      SELECT distinct e.equ_id
        FROM rm_tk t, rm_tk_data d, rm_equipment e
       WHERE t.tk_id = aTK_ID
         AND d.tkd_tk = t.tk_id
         AND d.tkd_res_class = 1
         AND d.tkd_is_new_res = 0 --текущий ресурс
         AND d.tkd_resource = e.equ_id
         AND e.equ_type in (2574, 1083, 4214);

   CURSOR GetEquip (aRes rm_tk_data.tkd_resource%TYPE) IS
      SELECT (SELECT v1.rvl_value FROM rm_res_prop_value v1 WHERE v1.rvl_prop_id in (2535,1909,3314) AND aRes = v1.rvl_res) as EquipSerial,
             (SELECT v1.rvl_value FROM rm_res_prop_value v1 WHERE v1.rvl_prop_id in (2477, 3315) AND aRes = v1.rvl_res) as EquipModel,
             (SELECT v1.rvl_value FROM rm_res_prop_value v1 WHERE v1.rvl_prop_id = 2534 AND aRes = v1.rvl_res) as EquipType
         FROM DUAL;
  EquipInfo GetEquip%rowtype;
  k NUMBER DEFAULT 0;

begin
   -- проверка существования и состояния ТК
   IF ContractTCID IS NULL THEN
      RAISE_APPLICATION_ERROR(-20001, 'Не указан номер технической карты!');
   END IF;

   OPEN GetTK(ContractTCID);
   FETCH GetTK INTO mTK_ID, mTK_status;
   IF GetTK%NOTFOUND THEN
      CLOSE GetTK;
      RAISE_APPLICATION_ERROR(-20001, 'Не найдена техническая карта!');
   END IF;
   CLOSE GetTK;
   /*IF (mTK_status IS NULL) OR (mTK_status = 0) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Указанная техническая карта уже не действует!');
   END IF;*/
    --найти ресурс оборудования
     OPEN GetEquipRes(mTK_ID);
     LOOP
        FETCH GetEquipRes INTO mRes;
        EXIT WHEN GetEquipRes%NOTFOUND;
        k:=k+1;
        --найти данные по оборудованию
         OPEN GetEquip(mRes);
        FETCH GetEquip INTO EquipInfo;
        CLOSE GetEquip;
          EquipParam:=EquipParam||PrepareParam('EquipSerial',to_char(EquipInfo.EquipSerial),''||k||'.1.Серийный номер оборудования');
          EquipParam:=EquipParam||PrepareParam('EquipModel',to_char(EquipInfo.EquipModel),''||k||'.2.Модель оборудования');
          EquipParam:=EquipParam||PrepareParam('EquipType',to_char(EquipInfo.EquipType),''||k||'.3.Тип устройства');
    END LOOP;
    CLOSE GetEquipRes;
    return '<PARAMSET>'||EquipParam||'</PARAMSET>';
end;
--MCreateChangeModemTS
--<02.02.2016-Точкасова М.А.> Добавление в текущую ТК оборудованиe СРЕ (R-0005078)
--1.Проверка незанятости оборудования на других ТК с другим адресом
--2.Запись в документ о ТК и в свойствах ТК о профиле оборудования
PROCEDURE AddCPEtoTK
(
   TKID          IN   NUMBER,               --идентификатор тк, для которой ищем связанные тк
   EquipID       IN   NUMBER,               --идентификатор добавляемого оборудовния
   OldEquipID    IN   NUMBER DEFAULT NULL,  --идентификатор старого оборудования MChangeEquip
   xRMDocID      IN   NUMBER DEFAULT NULL   --документ RM
)
IS
    mAdr           NUMBER;
    mProfileID     NUMBER;
    mProfile       VARCHAR2(200);
    mMessage       VARCHAR2(300);
    mTK_type       rm_tk.tk_type%TYPE;
    mTelzone_ID    NUMBER;
    --mTkd_id        NUMBER;
    mEquipOld      rm_tk_data.tkd_id%TYPE; --id записи в ТК

    mTD_ID          number;
    mEquip_type     NUMBER;

BEGIN
 --Поиск профиля оборудования
 SELECT NVL((SELECT p.id
     FROM rm_res_prop_value v, rm_res_property rp, rm_lst_equip_model rm, rm_equip_model_profile mp, rm_lst_equip_profile p
    WHERE v.rvl_res = EquipID
      AND v.rvl_prop_id = rp.rpr_id --id свойства
      AND v.rvl_res_type = rp.rpr_restype --тип устройства
      AND rp.rpr_strcod in ('MODEL')
      AND rp.rpr_restype IN (1083, 1523)
      AND UPPER(v.rvl_value)=UPPER(rm.NAME)
      AND rm.ID = mp.model_id
      AND mp.is_default = 1
      AND mp.profile_id = p.ID
      ), NULL)
 INTO mProfileID FROM dual;
 SELECT equ_type INTO mEquip_type FROM rm_equipment WHERE equ_id = EquipID;
 IF mEquip_type != 4214 THEN    -- Чтобы прошла выдача IPTV приставки
    irbis_utl.assertNotNull(mProfileID, 'Не найден профайл для оборудования с id : ' || EquipID);
 END IF;

--Поиск адреса
 SELECT adr_id INTO mAdr FROM rm_tk_address WHERE adr_tk = TKID;

  --проверка незанятости оборудования на других ТК с другим адресом
  IF rm_pkg.GetResState(EquipID, 1) != 0 THEN
    SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                         '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                    FROM rm_tk_data d, rm_tk t, rm_tk_address addr
                   WHERE d.tkd_resource = EquipID
                     AND d.tkd_res_class = 1
                     AND d.tkd_tk = t.tk_id
                     AND t.tk_status_id != 0
                     AND addr.adr_tk = t.tk_id
                     AND addr.adr_id != mAdr
                     AND rownum < 2), NULL)
    INTO mMessage
    FROM dual;
    irbis_utl.assertTrue((mMessage IS NULL), 'Устройство занято по другому адресу, закреплено за ТК '||mMessage);
  END IF;

  IF (OldEquipID IS NOT NULL) THEN--замена
   SELECT NVL ((SELECT d.tkd_id
                 FROM rm_tk_data d
                WHERE d.tkd_tk = TKID
                 AND d.tkd_res_class = 1
                 AND (d.tkd_is_new_res = 0
                 or d.tkd_is_new_res = 1 )-- MChangeEquip
                 AND d.tkd_resource = OldEquipID),NULL)
   INTO mEquipOld FROM DUAL;
   irbis_utl.assertNotNull(mEquipOld, 'В ТК не найдено старое оборудование с id : ' || OldEquipID);
  END IF;

  --добавление оборудования в ТК
  mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => TKID,
                                                 xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                 xRes_ID    => EquipID,
                                                 xParent_ID => mEquipOld,
                                                 xPos       => 1,
                                                 xDoc_ID    => xRMDocID,
                                                 xUser_ID   => irbis_user_id);
  if (mTD_ID is null) then null; end if;
  /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                         tkd_isdel, tkd_is_new_res, tkd_parent_id)
  VALUES (rm_gen_tk_data.NEXTVAL,TKID, 1, EquipID, 1, 0, 1, mEquipOld)
  RETURNING tkd_id INTO mTkd_id;
  irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
  irbis_is_core.get_tk_info(TKID, mTelzone_ID, mTK_type);
  dbms_output.put_line('Добавление оборудования '||EquipID||' в связанной ТК '||mTK_type||' id='||TKID||' '||' взамен старого '||OldEquipID);

  --запись в свойствах ТК о профиле оборудования
  IF mTK_type in (tk_type_sip) THEN
   mProfileID:=7; --временная корректировка для SIP
  Elsif mTK_type in (tk_type_dsl_new,tk_type_ethernet,tk_type_etth)then
  mProfileID:=1;
  END IF;
  IF mEquip_type != 4214 THEN    -- Чтобы прошла выдача IPTV приставки
      SELECT NAME INTO mProfile FROM rm_lst_equip_profile WHERE ID = mProfileID;
      MERGE INTO rm_tk_prop_value v
      USING (SELECT p.id property_id FROM rm_tk_property p WHERE p.strcod = 'PROFILE' and p.tktype=mTK_type) --CPE
      ON    (v.prop_id = property_id AND v.tk_id = TKID)
      WHEN MATCHED
        THEN UPDATE
             SET value = mProfile, value_cod = mProfileID
        WHEN NOT MATCHED
            THEN INSERT
                 VALUES (rm_gen_tk_prop_value.NEXTVAL,TKID, property_id, mProfile, mProfileID);
  END IF;

END AddCPEtoTK;
--MCreateChangeModemTS
-- <02.02.2016-Точкасова М.А.> Заявка на замену/выдачу паспортизированного клиентского оборудования (СРЕ):
-- 1. Разбор XML-коллекции MainParam
-- 2. Получение филиала и типа техкарты
-- 3. Определение отделов, куда будут направлены документы
-- 4. Определение адресов ТК
-- 5. Определение вида заявления, ТС
-- 6. Проверка категории заявления (создание только для 7 категории)
-- 7. Определение типа услуги
-- 8. Создание заявления
-- 9. Отправка заявления в абон отдел
-- 10. Привязка id абонемента и тип услуги к заявлению+
-- 11. Привязка техкарты к заявлению
-- 12. Заполнение Атрибутов заявления
-- 13. Привязка ID заявки Ирбис к заявлению
-- 14. Создание ТС на основании заявления
-- 15. Поиск нового и старого оборудования(нахождение id)
-- 16. Процесс проверки и добавления ресурса в ТК различный в зависимости от типа ТК
-- 17. Автоматическое проведение ТС
PROCEDURE CreateChangeModemTS
(
   RequestID          IN     NUMBER,   -- идентификатор заявки в IRBiS
   ActionType         IN     NUMBER,   -- тип операции: 10 – Замена паспортизированного клиентского оборудования, 11 – Выдача паспортизированного клиентского оборудования, 12 – Возврат паспортизированного клиентского оборудования --MReturnEquip
   EquipmentNumberOld IN     VARCHAR2, -- серийный номер старого оборудования
   EquipmentNumber    IN     VARCHAR2, -- серийный номер оборудования
   LineID             IN     NUMBER,    -- идентификатор базового ресурса (оборудования)
   MainParam          IN     VARCHAR2, -- набор XML-данных, содержащий универсальные параметры
   EquipmentLicense   OUT    VARCHAR2,  -- внутренний номер устройства ЦКТВ
   EquipmentTIP       OUT    NUMBER     -- тип оборудования
) IS
   mClientID        ad_paper_extended.contragent_id%TYPE;
   mAbonent_ID      ad_paper_extended.abonent_id%TYPE;
   mCuslType_ID      ad_paper_extended.usl_type_id%TYPE; -- тип услуги
   mAbonementID     ad_paper_extended.usl_id%TYPE;
   mTelzone_ID      ad_papers.telzone_id%TYPE;
   mAbonOtdelID     ad_papers.department_id%TYPE;
   mNextOtdel_ID    ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mDeclar_ID       ad_papers.id%TYPE;            -- id созданного документа
   mTS_ID           ad_papers.id%TYPE;            -- id техсправки
   mContent_ID      ad_paper_content.id%TYPE;     -- id содержания созданного документа
   mCategID         ad_subtypes.list_cat_id%TYPE; -- id категории документа
   mSubtype_ID      ad_subtypes.id%TYPE;          -- вид родительского документа
   mAddress_ID      ad_paper_content.address_id%TYPE;
   mAddress2_ID     ad_paper_content.address2_id%TYPE;
   mChildSubtype    ad_subtypes.id%TYPE;
   mTK_ID           rm_tk.tk_id%TYPE;             -- id техкарты
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты (зависит от устанавливаемой услуги)
   mEquipOld        rm_tk_data.tkd_id%TYPE;
   mMessage         VARCHAR2(300);
   mHoldResult      VARCHAR2(2000);
   --mTkd_id               NUMBER;
   --mKeyParams     irbis_activity_log.PARAMETERS%TYPE;

   mOperatorName    ad_paper_attr.value_long%TYPE; -- ФИО оператора создавшего заявление

   mNewEquipID rm_equipment.equ_id%TYPE; -- id нового оборудования TODO
   mOldEquipID rm_equipment.equ_id%TYPE; -- id старого оборудования TODO
   mTemp            NUMBER;
   --mPortID     rm_tk_data.tkd_resource%TYPE;

   mAccountNumber   ad_paper_attr.value_long%TYPE;
   mContactPhone    ad_paper_attr.value_long%TYPE;

   mProc          irbis_subtypes.proc%TYPE;
   mContractCommonType VARCHAR2(255); -- Тип абонемента
   --mBaseResClass  NUMBER; --класс базового ресурса

   mOldEquipID1   rm_tk.tk_id%TYPE;--24
   mOldEquipTK   rm_tk.tk_id%TYPE;--24

   mTD_ID         number;
   mRMDocID       number;

   mTK_status     rm_tk.tk_status_id%TYPE;
   mSnyatie       NUMBER;
   mCountEquip    NUMBER;

   --Определение id оборудования по серийному номеру для тип устройств "SIP адаптер" и "Модем SAGEM"
   CURSOR GetEquipmentID (aEquipmentNumber rm_res_prop_value.rvl_value%TYPE) IS
   SELECT e.equ_id
     FROM rm_equipment e
    WHERE (SELECT rty_can_add_to_tk FROM rm_res_type t WHERE t.rty_id = e.equ_type) = 1 --возможность добавления устройства в ТК
      AND EXISTS (SELECT 1 FROM rm_res_prop_value v, rm_res_property rp
                   WHERE v.rvl_res = e.equ_id
                     AND v.rvl_prop_id = rp.rpr_id --id свойства
                     AND v.rvl_res_type = rp.rpr_restype --тип устройства
                     AND rp.rpr_strcod in ( 'SERIAL','S_NUMBER')
                     AND rp.rpr_restype IN (2574, 1083, 4214, 1523, 4294) -- типы устройств "CPE", "Оборудование ЦКТВ", "Оборуд. радиодоступа", "Абон. терминал GPON"
                     AND LOWER(v.rvl_value) = LOWER(aEquipmentNumber));

          CURSOR GetOldEquip (aTK_ID rm_tk.tk_id%TYPE) IS
         SELECT d.tkd_id,d.tkd_resource
           FROM rm_tk_data d
          WHERE d.tkd_tk = aTK_ID
            AND d.tkd_res_class = 1
            AND d.tkd_is_new_res = 0;


     --получение информации по занятым FXS-портам для id оборудования
     CURSOR GetInfoUsedPorts (aEquipId rm_equipment.equ_id%TYPE) IS
     SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id, t.tk_id, d.tkd_id
        FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d, rm_tk t
       WHERE e.equ_id = aEquipId
         AND e.equ_id = eu.un_equip
         AND eu.un_id = ep.prt_unit
         AND ep.prt_type = 1323
         AND rm_pkg.GetResState(ep.prt_id, 2) > 0
         AND d.tkd_resource = ep.prt_id
         AND d.tkd_res_class = 2
         AND d.tkd_tk=t.tk_id
         AND t.tk_status_id !=0
         AND t.tk_type = tk_type_sip
         ORDER BY ep.prt_name;

     --mProfile  VARCHAR2(200); --наименование профайла
     --mProfileID  NUMBER; -- id профайла
     mAdr           NUMBER;

     CURSOR GetTKResource(aTK    rm_tk_data.tkd_tk%TYPE,
                        aClass rm_tk_data.tkd_res_class%TYPE) IS
      SELECT tkd_resource FROM rm_tk_data WHERE tkd_tk = aTK AND tkd_res_class = aClass AND tkd_isdel = 0 AND tkd_is_new_res = 0;

    -- Проверка нет ли созданных заявлении на снятие или ТК в архиве
    CURSOR CheckForSnyatie (aDeclar_ID NUMBER) IS
    SELECT NVL(
    (SELECT ape.paper_id FROM ad_paper_extended ape
    JOIN ad_papers ap ON ap.id = ape.paper_id
    WHERE ape.tk_id = (SELECT tk_id FROM ad_paper_extended
                    WHERE paper_id = aDeclar_ID)
        AND ap.prefix = 'З'
        AND ap.state_id IN ('С', 'F', 'W')
        AND ap.subtype_id IN (8706,8707,8708,8826,8936,8941,9186,9249,9251,9365,9496,9625,9687,9771,9905,10065,10605,10606,10745,10926,10970,11045)
        AND ape.paper_id <> aDeclar_ID),0) --типы документов на снятие
    FROM dual;

    --количество занятых портов на оборудовании
    FUNCTION GetUsedPorts
    (
       aEquipId      IN  rm_equipment.equ_id%TYPE
    ) RETURN NUMBER
    IS
    mCount     NUMBER;
    BEGIN
       SELECT COUNT(1)
       INTO mCount
       FROM rm_equip_unit eu, rm_equip_port ep
       WHERE eu.un_equip = aEquipId
       AND ep.prt_unit = eu.un_id
       AND ep.prt_type = 1323                           -- порт FXS
       AND rm_pkg.GetResState(ep.prt_id, 2) > 0;

       RETURN mCount;
    END GetUsedPorts;

    --количество всего портов на оборудовании
    FUNCTION CountPorts
    (
       aEquipId      IN  rm_equip_port.prt_unit%TYPE
    ) RETURN NUMBER
    IS
    mCount     NUMBER;
    BEGIN
       SELECT COUNT(1)
       INTO mCount
       FROM rm_equip_unit eu, rm_equip_port ep
       WHERE eu.un_equip = aEquipId
       AND ep.prt_unit = eu.un_id
       AND ep.prt_type = 1323;                          -- порт FXS

       RETURN mCount;
    END CountPorts;

BEGIN
   irbis_is_core.write_irbis_activity_log('CreateChangeModemTS',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ActionType="' || ActionType ||
                            '", EquipmentNumberOld="' || EquipmentNumberOld ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'            THEN mClientID            := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'           THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
         WHEN 'ContractCommonID'    THEN mAbonementID         := TO_NUMBER(x.VALUE);
         WHEN 'ContractTCID'        THEN mTK_ID               := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'      THEN mOperatorName        := x.VALUE;
         WHEN 'ClientPhones'        THEN mContactPhone        := x.VALUE;
         WHEN 'AccountNumber'       THEN mAccountNumber       := x.VALUE;
         WHEN 'ContractCommonType'  THEN mContractCommonType  := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;
   --Получение филиала и типа техкарты
   irbis_is_core.get_tk_info(mTK_ID, mTelzone_ID, mTK_type);
   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   --Замена может быть с паспортизированного или с непаспортизированного на паспортизированное оборудование
   IF ActionType = 10 THEN
          OPEN GetEquipmentID(EquipmentNumberOld);
             FETCH GetEquipmentID INTO mOldEquipID1;
             CLOSE GetEquipmentID;
             if   mOldEquipID1 is null then
                 irbis_is.ad_eq_logs( 'CreateChangeModemTS',RequestID,EquipmentNumberOld,'Не удалось найти cтарое оборудование' ||' '|| ' с серийным номером : ' || EquipmentNumberOld );
             END IF;

         SELECT NVL(( SELECT d.tkd_id -- tkd_resource
                       FROM rm_tk_data d
                      WHERE d.tkd_tk ! = mTK_ID
                        AND d.tkd_res_class = 1
                        AND d.tkd_is_new_res = 0
                        AND d.tkd_resource = mOldEquipID1
                       AND rownum < 2), NULL)
           INTO mOldEquipTK FROM dual;

            if   mOldEquipTK is not null then
                 irbis_is.ad_eq_logs( 'CreateChangeModemTS',RequestID,EquipmentNumberOld,'Оборудование с ' ||' '|| ' с серийным номером : ' || EquipmentNumberOld || ' находится в другой ТК ' || mOldEquipTK || ' и в связанных с ним ТК ' );
             END IF;


     /*  IF EquipmentNumberOld is NOT NULL THEN
       --если информацию о старом оборудовании из Ирбис получили, то поиск его id
            OPEN GetEquipmentID(EquipmentNumberOld);
           FETCH GetEquipmentID INTO mOldEquipID;
              IF GetEquipmentID%NOTFOUND THEN
              CLOSE GetEquipmentID;
              RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти старое оборудование с серийным номером : ' || EquipmentNumberOld);
              END IF;
           CLOSE GetEquipmentID;
         --поиск старого оборудования в ТК
         SELECT NVL((SELECT d.tkd_id -- tkd_resource
                       FROM rm_tk_data d
                      WHERE d.tkd_tk = mTK_ID
                        AND d.tkd_res_class = 1
                        AND d.tkd_is_new_res = 0
                        AND d.tkd_resource = mOldEquipID
                    ), NULL) INTO mEquipOld FROM dual;
         irbis_utl.assertNotNull(mEquipOld, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||
                                       'старое оборудование с серийным номером : ' || EquipmentNumberOld);
      ELSE*/
        --поиск существующего оборудования в ТК
        --если нашли, то это замена паспортизированного на паспортизированное оборудование
        --если нет, значит это замена непаспортизированного на паспортизированного оборудование
        SELECT d.tkd_id into mEquipOld
           FROM rm_tk_data d
          WHERE d.tkd_tk = mTK_ID
            AND d.tkd_res_class = 1
            AND d.tkd_is_new_res = 0
            AND d.tkd_resource = mOldEquipID1;

        mOldEquipID := mOldEquipID1;
    --  END IF;
   END IF;

   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      -- определение бизнес-процесса и типа ТК
      mProc := irbis_is_core.get_proc_by_paper(mDeclar_ID);
       irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="T";' ||
                                               'ACTIONTYPE="' || TO_CHAR(ActionType) || '";' ||
                                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
      irbis_is_core.get_address_by_tk(mTK_ID, mAddress_ID, mAddress2_ID, 1);

      -- определение бизнес-процесса
      IF ActionType = 10 THEN
        --если строго оборудования нет, то для ТУ выдача паспортизированного оборудования взамен непаспортизированного (или если ранее был добавлен)
        --в противном случае чистая замена
        IF mOldEquipID is NULL THEN mProc:=31; ELSE mProc:=24; END IF;
      ELSIF ActionType IN (11,12) THEN --MReturnEquip
        mProc:=31;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Неопределен бизнес-процесс! ('||ActionType||')');
      END IF;

      -- ОПРЕДЕЛЕНИЕ ВИДА --------------------------------------------------------
      mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="D";' ||
                                               'ACTIONTYPE="' || TO_CHAR(ActionType) || '";' ||
                                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mSubtype_ID, 'Не определен вид заявления'||' '||mProc||' '||ActionType||' '||mContractCommonType||' '||mTK_type);

      mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                               'OBJECT="T";' ||
                                               'ACTIONTYPE="' || TO_CHAR(ActionType) || '";' ||
                                               'CONTRACTCOMMONTYPE="' || UPPER(mContractCommonType) || '";' ||
                                               'TKTYPE="' || TO_CHAR(mTK_type) || '"');
      irbis_utl.assertNotNull(mChildSubtype, 'Не определен вид техсправки');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
      irbis_utl.assertTrue(mCategID = 7, 'Функциональность реализована только для категории "Расширенная работа с услугами (id = ' || TO_CHAR(mSubtype_ID) || ')');

      -- ОПРЕДЕЛЕНИЕ ТИПА УСЛУГИ --------------------------------------------------
       IF (mTK_type in (tk_type_wifiguest, tk_type_etth, tk_type_wimax, tk_type_ethernet, tk_type_gpon, tk_type_dsl_old, tk_type_dsl_new, tk_type_wifimetroethernet, tk_type_wifiadsl)) THEN --CPE
          SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
       ELSIF (mTK_type = tk_type_sip) THEN
          SELECT ID INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_TEL';
       ELSIF (mTK_type = tk_type_digitalcable) THEN
          SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
       ELSIF (mTK_type = tk_type_iptv) then
          SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_IPTV';
       ELSIF (mTK_type = tk_type_cable) then
          SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_CABLE';
       ELSIF (mTK_type = tk_type_wifistreet) then
          SELECT id INTO mCuslType_ID FROM ad_list_card_type WHERE strcod = 'IRBIS_INTERNET';
       ELSE
          mCuslType_ID := NULL;
       END IF;

      ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                            SYSDATE, '',
                                            mTelzone_ID, irbis_user_id, mCuslType_ID,
                                            mClientID, 'IRBIS_CONTRAGENT',
                                            mAbonent_ID, 'IRBIS_ABONENT',
                                            mAddress_ID, 'M2000_ADDRESS',
                                            mAddress2_ID, 'M2000_ADDRESS',
                                            0, NULL, NULL, NULL, NULL, NULL);

      -- НАПРАВЛЕНИЕ --------------------------------------------------------------
      -- корректировка отдела-создателя с учетом вида работ
      mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
      irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
      irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

      -- привязка id абонемента и тип услуги к заявлению
      UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE ID = mContent_ID;
      -- привязка техкарты к заявлению и ТС
      UPDATE ad_paper_extended SET tk_id = mTK_ID WHERE id = mContent_ID;

      -- Заполнение Атрибутов заявления
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'ACTIONTYPE', TO_CHAR(ActionType), TO_CHAR(ActionType));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CARDNUM_IRBIS', mAccountNumber, mAccountNumber);
      IF ActionType = 12 THEN
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
      ELSE
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_EQUIP', TO_CHAR(EquipmentNumberOld), EquipmentNumberOld);
      END IF;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'OLD_EQUIP_ID', mOldEquipID, mOldEquipID);


      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
   END IF;
   irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mNextOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);

--1. поиск нового оборудования
    IF (ActionType <> 12) THEN
       OPEN GetEquipmentID(EquipmentNumber);
       FETCH GetEquipmentID INTO mNewEquipID;
          IF GetEquipmentID%NOTFOUND THEN
          CLOSE GetEquipmentID;
          RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);
          END IF;
       CLOSE GetEquipmentID;
       irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP_ID', mNewEquipID, mNewEquipID);
    END IF;

--ЗАМЕНА
IF ActionType = 10 THEN
  IF (mOldEquipID is not NULL) and (mNewEquipID = mOldEquipID) THEN
      RAISE_APPLICATION_ERROR(-20001, 'В ТК уже есть данное оборудование с серийным номером : ' || EquipmentNumber);
  END IF;

  mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);

  IF mTK_type=tk_type_digitalcable THEN --Оборудование ЦКТВ --Для услуги ЦКТВ предусмотрена только замена.

     --Проверка наличия старого оборудования в ТК
     IF mEquipOld is NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'В ТК не обнаружено старое оборудование!');
     END IF;

     --Проверка свободности нового оборудования
     IF rm_pkg.GetResState(mNewEquipID, 1) != 0 THEN
        SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                           '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                      FROM rm_tk_data d, rm_tk t
                     WHERE d.tkd_resource = mNewEquipID
                       AND d.tkd_res_class = 1
                       AND d.tkd_tk = t.tk_id
                       AND t.tk_status_id != 0
                       AND rownum < 2), NULL)
          INTO mMessage FROM dual;
        RAISE_APPLICATION_ERROR(-20001, 'Устройство не свободно, закреплено за ТК ' || mMessage);
     END IF;

     --Добавление нового оборудования в ТК
     mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK_ID,
                                                    xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                    xRes_ID    => mNewEquipID,
                                                    xParent_ID => mEquipOld,
                                                    xPos       => 1,
                                                    xDoc_ID    => mRMDocID,
                                                    xUser_ID   => irbis_user_id);
    if (mTD_ID is null) then null; end if;

     /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                             tkd_isdel, tkd_is_new_res, tkd_parent_id)
     VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, 1, mNewEquipID, 1, 0, 1, mEquipOld)
      RETURNING tkd_id INTO mTkd_id;
     --добавление в историю ТК информацию о добавлении ресурса в ТК
      irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

    --Получение внутреннего номера оборудования
       SELECT NVL((SELECT v.rvl_value FROM rm_res_prop_value v, rm_res_property rp
                   WHERE v.rvl_res = mNewEquipID
                     AND v.rvl_prop_id = rp.rpr_id --id свойства
                     AND v.rvl_res_type = rp.rpr_restype --тип оборудования
                     AND rp.rpr_strcod = 'S_C_NO'
                     AND rp.rpr_restype = 2574), -- тип оборудования "Оборудование ЦКТВ"), --TO DO: WORK 2574
            NULL) INTO EquipmentLicense FROM dual;

  ELSIF (mTK_type = tk_type_sip and UPPER(mContractCommonType) like '%SIP%') THEN  --Для услуги SIP РТУ предусмотрена только замена.
    --замена оборудования для SIP
    --2. проверка существования порта старого оборудования в ТК
      SELECT NVL((SELECT eu.un_equip
       FROM rm_tk_data d, rm_equip_unit eu, rm_equip_port ep
      WHERE d.tkd_tk = mTK_ID
        AND d.tkd_res_class = 2
        AND d.tkd_resource = ep.prt_id
        AND ep.prt_type = 1323    -- FXS порт
        AND ep.prt_unit = eu.un_id
        AND d.tkd_is_new_res = 0
        AND eu.un_equip = mOldEquipID
        ), NULL) INTO mOldEquipID FROM dual;
     irbis_utl.assertNotNull(mOldEquipID, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||'порт старого оборудования с серийным номером : ' || EquipmentNumberOld);

     --3. Проверка свободных портов нового оборудования
     IF (GetUsedPorts(mNewEquipID) > 0)
     THEN RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером : ' || EquipmentNumber||' занято');
     END IF;

    --4. Проверка возможности замены на новое оборудование
     IF (GetUsedPorts(mOldEquipID) > CountPorts(mNewEquipID))
     THEN RAISE_APPLICATION_ERROR(-20001, 'У оборудования с серийным номером : ' || EquipmentNumber||' количество портов меньше, чем у старого оборудования');
     END IF;

    --4.1. Проверка управляемости PMP нового оборудования
    mTemp:=0;
         SELECT count(1) INTO mTemp
           FROM rm_res_property rp, rm_res_prop_value rpv
          WHERE rpv.rvl_res = mNewEquipID
            AND rpv.rvl_prop_id = rp.rpr_id
            AND rp.rpr_restype = rpv.rvl_res_type
            AND UPPER(rp.rpr_strcod) = UPPER('PMP')
            AND UPPER(rpv.rvl_value) = UPPER('Да');
     IF (mTemp < 1)
     THEN RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером : ' || EquipmentNumber||' не управляется PMP');
     END IF;

     --5. Добавление портов нового оборудования и нового оборудования в ТК
     FOR mOldEquip IN GetInfoUsedPorts(mOldEquipID) LOOP
       for v1 in (SELECT mOldEquip.tk_id mTK_ID, RM_CONSTS.RM_RES_CLASS_EQUIP_PORT tkd_res_class, dd.prt_id tkd_resource, mOldEquip.tkd_id tkd_parent_id
                    FROM (SELECT d.prt_id
                            FROM (SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id
                                    FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep
                                   WHERE e.equ_id = mNewEquipID
                                     AND e.equ_id = eu.un_equip
                                     AND eu.un_id = ep.prt_unit
                                     AND ep.prt_type = 1323
                                    --AND rm_pkg.GetResState(ep.prt_id, 2) = 0 --проверка, что занятых портов у оборудования нет, была ранее
                                ORDER BY ep.prt_name) d
                           where d.prt_rownum = mOldEquip.prt_rownum) dd)
       loop
         mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => v1.mTK_ID,
                                                        xClass_ID  => v1.tkd_res_class,
                                                        xRes_ID    => v1.tkd_resource,
                                                        xParent_ID => v1.tkd_parent_id,
                                                        xPos       => 1,
                                                        xDoc_ID    => mRMDocID,
                                                        xUser_ID   => irbis_user_id);
       end loop;

       /*SELECT rm_gen_tk_data.nextval INTO mTkd_id FROM dual;
       INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                               tkd_isdel, tkd_is_new_res, tkd_parent_id)
       SELECT mTkd_id, mOldEquip.tk_id, 2, dd.prt_id, 1, 0, 1, mOldEquip.tkd_id
       FROM (SELECT d.prt_id FROM
          (SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id
              FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep
             WHERE e.equ_id = mNewEquipID
               AND e.equ_id = eu.un_equip
               AND eu.un_id = ep.prt_unit
               AND ep.prt_type = 1323
               --AND rm_pkg.GetResState(ep.prt_id, 2) = 0 --проверка, что занятых портов у оборудования нет, была ранее
               ORDER BY ep.prt_name)d
               where d.prt_rownum=mOldEquip.prt_rownum)dd;
       --добавление в историю ТК информацию о добавлении ресурса в ТК
        irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/

      --6. Замена старого оборудования mOldEquipID на новое mNewEquipID в ТК (есть проверка незанятости оборудования по другому адресу)
     AddCPEtoTK(mOldEquip.tk_id, mNewEquipID, mOldEquipID, mRMDocID);
     END LOOP;
  ELSIF  mTK_type in (tk_type_wifiguest,
                    tk_type_etth,
                    tk_type_wimax,
                    tk_type_ethernet,
                    tk_type_gpon,
                    tk_type_dsl_old, tk_type_dsl_new,
                    tk_type_wifimetroethernet, tk_type_wifiadsl,
                    tk_type_iptv,
                    tk_type_wifistreet)
       OR (mTK_type = tk_type_sip and UPPER(mContractCommonType) not like '%SIP%') THEN --CPE

     --4. Проверка существования занятых портов FXS у старого оборудования
     IF (GetUsedPorts(mOldEquipID) > 0)THEN
       FOR mOldEquip IN GetInfoUsedPorts(mOldEquipID) LOOP
        SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
               '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
          FROM rm_tk t
         WHERE t.tk_id=mOldEquip.tk_id), NULL)
         INTO mMessage FROM dual;
        /* SELECT NVL((SELECT object_name FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
          WHERE us.usl_tk = mOldEquip.tk_id AND us.usl_id = cc.object_no), NULL)
          INTO mMessage FROM dual;*/
       END LOOP;
     RAISE_APPLICATION_ERROR(-20001, 'Существуют занятые порты в ТК '||mMessage||'. Замену старого оборудования необходимо произвести на абонементе SIP-телефонии!');
     END IF;

     --если БП выдача, то добавление оборудования в ТК (есть проверка незанятости оборудования по другому адресу)
     AddCPEtoTK(mTK_ID, mNewEquipID, mOldEquipID, mRMDocID);
  ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Для данной услуги не предусмотрена замена оборудования!');
  END IF;
--ВЫДАЧА
ELSIF ActionType = 11 THEN
  IF  mTK_type in (tk_type_wifiguest,
                    tk_type_etth,
                    tk_type_wimax,
                    tk_type_ethernet,
                    tk_type_gpon,
                    tk_type_dsl_old, tk_type_dsl_new,
                    tk_type_wifimetroethernet, tk_type_wifiadsl,
                    tk_type_iptv,
                    tk_type_wifistreet)
       OR (mTK_type = tk_type_sip and UPPER(mContractCommonType) not like '%SIP%') THEN --CPE
     --если БП выдача, то добавление оборудования в ТК (есть проверка незанятости оборудования по другому адресу)
     AddCPEtoTK(mTK_ID, mNewEquipID, NULL, mRMDocID);
  ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Для данной услуги не предусмотрена выдача оборудования!');
  END IF;
--ВОЗВРАТ
ELSIF ActionType = 12 THEN
-- Начало <13.02.2020 Хузин А.ф.>
    /*OPEN CheckForSnyatie(mDeclar_ID);
    FETCH CheckForSnyatie INTO mSnyatie;
    CLOSE CheckForSnyatie;
    SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
    IF (mSnyatie = 0) AND (mTK_status <> 0) THEN    --если нет заявлении на снятие и ТК не архивная*/
      OPEN GetEquipmentID(EquipmentNumber);
      FETCH GetEquipmentID INTO mNewEquipID;
      IF GetEquipmentID%NOTFOUND THEN
      -- Начало <17.03.2020 Хузин А.Ф.>
        /*CLOSE GetEquipmentID;
        RAISE_APPLICATION_ERROR(-20001, 'Не удалось найти оборудование с серийным номером : ' || EquipmentNumber);*/
        mNewEquipID := NULL;
        --<17.03.2020> конец
      END IF;
      CLOSE GetEquipmentID;
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP_ID', mNewEquipID, mNewEquipID);
-- Конец
      IF  mTK_type in (tk_type_wifiguest,
                        tk_type_etth,
                        tk_type_wimax,
                        tk_type_ethernet,
                        tk_type_gpon,
                        tk_type_dsl_old, tk_type_dsl_new,
                        tk_type_wifimetroethernet, tk_type_wifiadsl,
                        tk_type_iptv,
                        tk_type_sip,
                        tk_type_cable,
                        tk_type_digitalcable,
                        tk_type_wifistreet) THEN --CPE
         --OR (mTK_type = tk_type_sip and UPPER(mContractCommonType) not like '%SIP%') THEN --CPE
         mOldEquipID:=mNewEquipID; --id удаляемого оборудования нашли ранее
         --поиск старого оборудования в ТК
         SELECT NVL((SELECT d.tkd_id -- tkd_resource
                       FROM rm_tk_data d
                      WHERE d.tkd_tk = mTK_ID
                        AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_EQUIP
                        AND d.tkd_is_new_res = RM_CONSTS.RM_TK_DATA_WORK_NONE
                        AND d.tkd_resource = mOldEquipID
                    ), NULL) INTO mEquipOld FROM dual;
         -- Начало <17.03.2020 Хузин А.Ф.>
         IF (mEquipOld IS NULL) THEN
            SELECT COUNT(rmdata.rn) INTO mCountEquip
            FROM (SELECT rm_tk_data.*, row_number() OVER (ORDER BY tkd_tk, tkd_res_class) rn FROM rm_tk_data WHERE tkd_tk = mTK_ID AND tkd_res_class = 1) rmdata;
            SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
            IF (mCountEquip = 1) THEN
                SELECT tkd_id INTO mEquipOld FROM rm_tk_data WHERE tkd_tk = mTK_ID AND tkd_res_class = 1;
            ELSIF (mCountEquip > 1) AND (mTK_status <> 0) THEN
                RAISE_APPLICATION_ERROR(-20001, 'В ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' || 'более одного оборудования и оборудование с серийным номером: ' || EquipmentNumber || 'не паспортизировано');
            END IF;
         END IF;
         /*irbis_utl.assertNotNull(mEquipOld, 'Не удалось найти в ТК' || ' (id=' || TO_CHAR(mTK_ID) || ')' ||
                                       'старое оборудование с серийным номером : ' || EquipmentNumber);*/
         -- Конец <17.03.2020>
         --Проверка существования занятых портов FXS у оборудования
         IF (GetUsedPorts(mOldEquipID) > 0)THEN
           FOR mOldEquip IN GetInfoUsedPorts(mOldEquipID) LOOP
            SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                   '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
              FROM rm_tk t
             WHERE t.tk_id=mOldEquip.tk_id), NULL)
             INTO mMessage FROM dual;
             SELECT adr_id INTO mAdr FROM rm_tk_address WHERE adr_tk = mOldEquip.tk_id;
             IF mAddress_ID = mAdr THEN
                RAISE_APPLICATION_ERROR(-20001, 'Существуют занятые порты возвращаемого оборудования в ТК '||mMessage||' по этому же адресу!');
             END IF;
           END LOOP;
         END IF;
         --пометить на удаление оборудование в ТК
         mTD_ID := RM_TK_PKG.LazyUnbindResourceFromData(xTK_ID     => mTK_ID,
                                                        xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                        xRes_ID    => 0,
                                                        xParent_ID => mEquipOld,
                                                        xPos       => 0,
                                                        xDoc_ID    => mRMDocID,
                                                        xUser_ID   => irbis_user_id);
         if (mTD_ID is null) then null; end if;

         /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                 tkd_isdel, tkd_is_new_res, tkd_parent_id)
         VALUES (rm_gen_tk_data.NEXTVAL,mTK_ID, 1, 0, 0, 0, 2, mEquipOld)
         RETURNING tkd_id INTO mTkd_id;
         irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
      ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Для данной услуги не предусмотрен возврат оборудования!');
      END IF;
    --END IF;
END IF;
   --определение типа оборудования
   SELECT NVL((SELECT t.rty_id FROM rm_res_type t, rm_res_prop_value v
   WHERE t.rty_id = v.rvl_res_type
         AND v.rvl_value = EquipmentNumber), null) INTO EquipmentTIP FROM dual;
   --проведение ТС
   mHoldResult := irbis_is_core.ad_paper_hold(mTS_ID, 0, SYSDATE, 248, SYSDATE, irbis_user_id, '');
   IF SUBSTR(mHoldResult, 1, 2) = '-1' THEN
      RAISE_APPLICATION_ERROR(-20001, SUBSTR(mHoldResult, 4, 2000));
   END IF;

   irbis_is_core.write_irbis_activity_log('CreateChangeModemTS - end',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", ActionType="' || ActionType ||
                            '", EquipmentNumberOld="' || EquipmentNumberOld ||
                            '", EquipmentNumber="' || EquipmentNumber ||
                            '", LineID="' || LineID ||
                            '", EquipmentLicense="' || EquipmentLicense ||
                            '", EquipmentTIP="' || EquipmentTIP ||
                            '"',
                            RequestID,
                            NULL);
END CreateChangeModemTS;


-- <24.05.2016-Точкасова М.А.> Создание заявления и техсправки для БП "Подключения и отключения дополнительного номера MVNO" --MExtraNumber
PROCEDURE CreateDocChangeAddNumber
(
   AttainAddNumberFlag IN BOOLEAN,--тип операции (true – подключение доп. номера, false – отключение доп.номера)
   RequestID       IN  NUMBER,   -- идентификатор заявки в IRBiS
   MobileNumber    IN  VARCHAR2, -- выбранный номер телефона (10 знаков)
   MainParam       IN  VARCHAR2 -- набор XML-данных, содержащий универсальные параметры
) IS
   mContragentID    NUMBER;
   mAccountID       NUMBER;
   mAbonementID     NUMBER;
   mOperatorName    ad_paper_attr.value_long%TYPE;
   mAccountNumber NUMBER;

   mTelzone_ID      ad_papers.telzone_id%TYPE;    -- id филиала
   mAbonOtdelID     ad_papers.department_id%TYPE;

   mTemp            NUMBER;
   mTK_type         rm_tk.tk_type%TYPE;           -- тип техкарты
   mTK_ID NUMBER;
   mResourceID  NUMBER;    -- идентификатор ресурса
   --mTkd_id NUMBER;

   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mCategID       NUMBER;
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mContent_ID    NUMBER;               -- id содержания созданного документа
   mChildSubtype  ad_subtypes.id%TYPE;

   mAddress_ID      NUMBER;
   mAddress2_ID     NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;

   mTS_ID         ad_papers.id%TYPE;            -- id техсправки
   mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   mTkd_res_class rm_tk_data.tkd_res_class%TYPE; -- тип базового ресурса в ТК, зависит от ConnectionType
   mCuslType_ID   ad_paper_extended.usl_type_id%TYPE; -- тип услуги в M2000

   mActionType NUMBER;
   mNum NUMBER;
   mRubDop NUMBER;
   mResState NUMBER;

   mTD_ID         number;
   mRMDocID       number;
BEGIN
   IF AttainAddNumberFlag THEN mActionType:=1; ELSE mActionType:=0; END IF;
   irbis_is_core.write_irbis_activity_log('CreateDocChangeAddNumber',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", AttainAddNumberFlag="' || TO_CHAR(mActionType) ||
                            '", MobileNumber="' || MobileNumber ||
                            '"',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ClientID'           THEN mContragentID    := TO_NUMBER(x.value);
         WHEN 'AccountID'          THEN mAccountID       := TO_NUMBER(x.value);
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'AccountCompanyBranchCode'      THEN mTelzone_ID   := 103;
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
         WHEN 'ContractTCID'       THEN mTK_ID           := TO_NUMBER(x.VALUE);
         WHEN 'AccountNumber'      THEN mAccountNumber  := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mAddress_ID   := NULL;
   mAddress2_ID  := NULL;
   mTkd_res_class := 6;

   -- Проверка существования техкарты и телефонного номера в ней
   SELECT COUNT(1) INTO mTemp FROM rm_tk WHERE tk_id = mTK_ID;
   IF mTemp > 0 THEN
      SELECT COUNT(1) INTO mTemp FROM rm_tk_data WHERE tkd_tk = mTK_ID AND tkd_res_class = mTkd_res_class;
      IF mTemp = 0 THEN
         RAISE_APPLICATION_ERROR(-20001, 'Не найден телефонный номер в техкарте ' || TO_CHAR(mTK_ID));
      END IF;
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Техкарта ' || TO_CHAR(mTK_ID) || ' не найдена');
   END IF;

   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
   mTK_type := tk_type_mvno;
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   IF MobileNumber IS NOT NULL THEN mNum:=1; ELSE mNum:=0; END IF;
   -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
   IF (mDeclar_ID IS NOT NULL) THEN
      irbis_is_core.get_created_paper_data(mDeclar_ID,
                             mCategID,
                             mSubtype_ID,
                             mContent_ID,
                             mAddress_ID,
                             mAddress2_ID);
      SELECT NVL((SELECT h.to_depart_id FROM ad_paper_history h WHERE h.paper_id = mDeclar_ID AND h.resolution_id = 1), mAbonOtdelID) INTO mAbonOtdelID FROM dual;
   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
   ELSE
      irbis_is_core.write_irbis_activity_log('defineSubtype',
                               'BP="32";' ||
                               'OBJECT="D";' ||
                               'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                               'ACTIONTYPE="'|| TO_CHAR(mActionType) ||'";' ||
                               'NUM="'|| TO_CHAR(mNum) ||'";' ||
                               '"',
                               RequestID);
      mSubtype_ID := irbis_utl.defineSubtype('BP="32";' ||
                                             'OBJECT="D";' ||
                                             'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                                             'ACTIONTYPE="'|| TO_CHAR(mActionType) ||'";' ||
                                             'NUM="'|| TO_CHAR(mNum) ||'";' ||
                                             '"');
      irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_MVNO'), NULL)
           INTO mCuslType_ID FROM dual;

         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mContragentID, 'IRBIS_CONTRAGENT',
                                               mAccountID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;
      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), TO_CHAR(mPriority));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_NUM', MobileNumber, MobileNumber);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CARDNUM_IRBIS', mAccountNumber, mAccountNumber);

      -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 32, MainParam);
   END IF;

   irbis_is_core.write_irbis_activity_log('defineSubtype',
                            'BP="32";' ||
                            'OBJECT="T";' ||
                            'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                            'ACTIONTYPE="'|| TO_CHAR(mActionType) ||'";' ||
                            'NUM="'|| TO_CHAR(mNum) ||'";' ||
                            '"',
                            RequestID);
   mChildSubtype := irbis_utl.defineSubtype('BP="32";' ||
                                            'OBJECT="T";' ||
                                            'TKTYPE="' || TO_CHAR(mTK_type) ||'";' ||
                                            'ACTIONTYPE="'|| TO_CHAR(mActionType) ||'";' ||
                                            'NUM="'|| TO_CHAR(mNum) ||'";' ||
                                            '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');

   -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
   irbis_is_core.create_tc_by_request(mTS_ID,
                        mChildSubtype,
                        mDeclar_ID,
                        mSubtype_ID,
                        RequestID,
                        mOtdel_ID,
                        mAbonOtdelID,
                        0,
                        MainParam);


   mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);

   -- ИЗМЕНЕНИЕ ТЕХКАРТЫ --------------------------------------------------------
  IF AttainAddNumberFlag AND MobileNumber IS NOT NULL THEN
    --Для Смартс(филиал 103) своя номерная емкость
    IF mTelzone_ID=103 THEN
       SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = MobileNumber AND num_telzona = 103), NULL) INTO mResourceID  FROM dual;
    ELSE
       SELECT nvl((SELECT num_id  FROM rm_numbers WHERE num_number = MobileNumber AND num_telzona != 103), NULL) INTO mResourceID  FROM dual;
    END IF;
       IF (mResourceID IS NOT NULL) AND (mResourceID > 0) THEN
      select count(1) INTO mResState from rm_resource where res_id=mResourceID and res_class=6 and res_astate=3;    ---Diana
      irbis_utl.assertTrue((mResState=0), 'Данный номер сотовой связи  ' || MobileNumber || ' невозможно выдать,т.к. номер находится в резерве!');
      SELECT count(1) INTO mRubDop FROM rm_rub_value WHERE rbv_entity = mResourceID AND rbv_record = 463;
      IF mRubDop>0 THEN
        mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => mTK_ID,
                                                       xClass_ID => mTkd_res_class,
                                                       xRes_ID   => mResourceID,
                                                       xPos      => 0,
                                                       xDoc_ID   => mRMDocID,
                                                       xUser_ID  => irbis_user_id);
        if (mTD_ID is null) then null; end if;

       /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                              tkd_isdel, tkd_is_new_res, tkd_parent_id)
       VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mTkd_res_class, mResourceID, 0, 0, 1, NULL)
         RETURNING tkd_id INTO mTkd_id;
         irbis_utl.addTKHisData(mTkd_id, irbis_user_id);*/
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Телефонный номер ' || MobileNumber || ' не является дополнительным номером');
      END IF;
   ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Телефонный номер ' || MobileNumber || ' не найден в номерной емкости');
   END IF;
  ELSIF NOT AttainAddNumberFlag THEN
    --определяем ресурс для удаления
    SELECT NVL((SELECT d.tkd_id
                  FROM rm_rub_value r, rm_tk_data d, rm_numbers n
                  WHERE d.tkd_tk = mTK_ID
                    AND d.tkd_res_class = RM_CONSTS.RM_RES_CLASS_NUMBER --6
                    AND d.tkd_is_new_res = 0
                    AND r.rbv_entity = d.tkd_resource
                    AND r.rbv_record = 463
                    AND d.tkd_resource = n.num_id
                    AND n.num_number = MobileNumber),
     NULL) INTO mResourceID FROM DUAL;
     IF (mResourceID IS NOT NULL) AND (mResourceID > 0) THEN
       mTD_ID := RM_TK_PKG.LazyUnbindResourceFromData(xTK_ID     => mTK_ID,
                                                      xClass_ID  => mTkd_res_class,
                                                      xRes_ID    => 0,
                                                      xParent_ID => mResourceID,
                                                      xPos       => 0,
                                                      xDoc_ID    => mRMDocID,
                                                      xUser_ID   => irbis_user_id);
       if (mTD_ID is null) then null; end if;

         /*INSERT INTO rm_tk_data (tkd_id, tkd_tk, tkd_res_class, tkd_resource, tkd_npp,
                                tkd_isdel, tkd_is_new_res, tkd_parent_id)
         VALUES (rm_gen_tk_data.NEXTVAL, mTK_ID, mTkd_res_class, 0, 0, 0, 2, mResourceID)
           RETURNING tkd_id INTO mTkd_id;*/
     ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Телефонный номер ' || MobileNumber || ' не найден ТК');
     END IF;
  END IF;
   -- сохранение созданной техкарты в документе - заявке
    irbis_is_core.attach_tk_to_paper(mTK_ID, mDeclar_ID);
   -- сохранение созданной техкарты в документе - техсправке
    irbis_is_core.attach_tk_to_paper(mTK_ID, mTS_ID);
   --направление в следующий отдел
   irbis_utl.sendPaperNextDepartment(mTS_ID);

END CreateDocChangeAddNumber;

---------- <02.11.2016-Гаппасова Д.А.> Создание заявления и наряда для БП "Вызов техника"
PROCEDURE CreateOrderCall
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
   mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
   Servicetypes    IN VARCHAR2,    -- услуга
   MainParam       IN VARCHAR2,   -- набор XML-данных, содержащий универсальные параметры
   mPNumber        OUT VARCHAR2
) IS
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   --mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;

   --mPaperNumber   ad_papers.pnumber%TYPE;
   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   --mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   --mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mState         NUMBER;
   --mMessage       VARCHAR2(2000);
   mSecondName    VARCHAR2(200);
   mFirstName     VARCHAR2(200);
   mPatrName      VARCHAR2(200);
   mOrgName       VARCHAR2(200);
   --mTemp          NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);

   mClientID             NUMBER;    -- идентификатор клиента в IRBiS
   mClientName           VARCHAR2(300);  -- наименование клиента
   mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
   mAbonementID          NUMBER;    -- идентификатор абонемента
   mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
   mApartment            VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
  -- mContactPhone         VARCHAR2(200);  -- контактный телефон абонента
   mOperatorName         VARCHAR2(200);  -- ФИО оператора создавшего заявление

   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;

   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;

    mCategID       NUMBER;


   --mChildSubtypeOld ad_subtypes.id%TYPE;
   mConnectionReason  VARCHAR2(300);

BEGIN

   irbis_is_core.write_irbis_activity_log('CreateOrderCall',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", RequestComment="' || RequestComment ||
                            '", mContactPhone="' || mContactPhone ||
                            '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                            '", ',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mApartment   := x.value;
        -- WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
         WHEN 'ClientName'         THEN mClientName    := x.value;
         WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
         WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

   -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА ------------------------------------------------------
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

   -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
   -- (mState не проверять, т.к. 1=генерировать исключение)
   mHouseOnly    := 0;
   mPrivateHouse := 0;
   irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
   mAddress2_ID  := NULL;


   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА

        mSubtype_ID := irbis_utl.defineSubtype('BP="33";' ||
                                             'OBJECT="D";' ||
                                             '"');
       irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');


      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_USL'), NULL)
           INTO mCuslType_ID FROM dual;
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         -- корректировка отдела-создателя с учетом вида работ
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
        ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DOC_COMMENT', RequestComment, RequestComment);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_USL', Servicetypes, Servicetypes);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));




       mChildSubtype := irbis_utl.defineSubtype('BP="33";' ||
                                             'OBJECT="O";' ||
                                             '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');




  -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------


      ad_utils.ad_create_paper_cat7_as(mOrder_ID,
                                       mChildSubtype,
                                       mDeclar_ID,
                                       mSubtype_ID,
                                       irbis_user_id,
                                       SYSDATE,
                                       '',
                                       NULL);


   -- корректировка отдела-создателя с учетом вида работ
   mAbonOtdelID := irbis_utl.getDepCreatorByWork(mOrder_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
   irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
   -- НАПРАВЛЕНИЕ --------------------------------------------------------------
   irbis_is_core.move_created_paper(mOrder_ID, mAbonOtdelID);

  -- END СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------


   irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
   irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
   irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
   irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);



   irbis_is_core.write_ts_log(mCuslType_ID,
                mTelzone_ID,
                mSubtype_ID,  -- сохраняется вид документа
                mClientName || '; id=' || TO_CHAR(mClientID),
                mAddress_ID,
                mAddress2_ID,
                mSecondName || ' ' || mFirstName || ' ' || mPatrName,
                mOrgName,
                RequestID,
                Null,
                Null);


   irbis_utl.sendPaperNextDepartment(mOrder_ID);

  select PREFIX ||'-'||PNUMBER
  INTO mPNumber
  from ad_papers
  where id=mOrder_ID;

   END CreateOrderCall;


 PROCEDURE CreateSpeedChange
(
   RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
   RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
   DateSpeed       IN DATE,     -- желаемая дата изменения скорости
   mNEW_SREED       IN VARCHAR2,
   mSPEED           IN VARCHAR2,
   mNAS             IN VARCHAR2,
   mVLAN            IN VARCHAR2,
   MainParam       IN VARCHAR2,   -- набор XML-данных, содержащий универсальные параметры
   mPNumber        OUT VARCHAR2
 --  amessage      IN OUT   VARCHAR2,
  -- astate        IN OUT   NUMBER
) IS
   mCuslType_ID   ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
   mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
   mTelzone_ID    ad_papers.telzone_id%TYPE;
   mAbonent_ID    ad_paper_content.abonent_id%TYPE;
   --mContragent_ID ad_paper_content.contragent_id%TYPE;
   mAddress_ID    ad_paper_content.address_id%TYPE;

   --mPaperNumber   ad_papers.pnumber%TYPE;
   mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
   mOrder_ID      ad_papers.id%TYPE;            -- id наряда
   mContent_ID    ad_paper_content.id%TYPE;     -- id содержания созданного документа
   --mOtdel_ID      ad_papers.department_id%TYPE; -- id отдела, в котором документ должен оказаться сразу после создания
   --mNextOtdel_ID  ad_papers.department_id%TYPE; -- id отдела, в котором наряд должен оказаться сразу после создания

   mHouseOnly     NUMBER;           -- признак того, что для многоквартирного дома не была указана квартира
   mPrivateHouse  NUMBER;           -- признак того, что дом является частным (без квартир)
   mAddress2_ID   ad_paper_content.address2_id%TYPE;
   mState         NUMBER;
   --mMessage       VARCHAR2(2000);
   mSecondName    VARCHAR2(200);
   mFirstName     VARCHAR2(200);
   mPatrName      VARCHAR2(200);
   mOrgName       VARCHAR2(200);
   --mTemp          NUMBER;
   mMarketingCategory VARCHAR2(50);
   mPriority        NUMBER;
   mPriorityLong    VARCHAR2(200);

    mTK_ID           rm_tk.tk_id%TYPE;             -- id техкарты

   mClientID             NUMBER;    -- идентификатор клиента в IRBiS
   mClientName           VARCHAR2(300);  -- наименование клиента
   mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
   mAbonementID          NUMBER;    -- идентификатор абонемента
   mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
   mApartment            VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
  -- mContactPhone         VARCHAR2(200);  -- контактный телефон абонента
   mOperatorName         VARCHAR2(200);  -- ФИО оператора создавшего заявление

   mAbonOtdelID   ad_papers.department_id%TYPE;
   mChildSubtype  ad_subtypes.id%TYPE;

   --mAttrValue     ad_paper_attr.value%TYPE;
   --mAttrValuLong  ad_paper_attr.value_long%TYPE;

    mCategID       NUMBER;


   --mChildSubtypeOld ad_subtypes.id%TYPE;
   mConnectionReason  VARCHAR2(300);

 --   amessage          VARCHAR2(200);
 --  astate            NUMBER ;
 mST       NUMBER;  --stateTK

  CURSOR cur_tk_info IS --stateTK
  SELECT  rt.tk_status_id,rt.tk_id
  FROM rm_tk rt
  WHERE rt.tk_id=mTK_ID;



BEGIN

   irbis_is_core.write_irbis_activity_log('CreateOrderCall',
                            'RequestID="' || TO_CHAR(RequestID) ||
                            '", RequestComment="' || RequestComment ||
                         --   '", mContactPhone="' || mContactPhone ||
                         --   '", Servicetypes="' || Servicetypes ||
                            '", DATE_SPEED="' || TO_CHAR(DateSpeed, 'DD.MM.YYYY HH24:MI:SS') ||
                           '", NEW_SPEED="' || mNEW_SREED ||
                           '", SPEED="' || mSPEED ||
                           '", NAS="' || mNAS ||
                           '", VLAN="' || mVLAN ||
                            '", ',
                            RequestID,
                            MainParam);
   rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

   -- Разбор XML
   FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
               XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
            ) LOOP
      CASE x.param_name
         WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
         WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
         WHEN 'ContractAppartment' THEN mApartment   := x.value;
        -- WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
         WHEN 'ContractTCID'        THEN mTK_ID               := TO_NUMBER(x.VALUE);
         WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
         WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
         WHEN 'ClientName'         THEN mClientName    := x.value;
         WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
         WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
         WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
         WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
         WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
         ELSE NULL;
      END CASE;
   END LOOP;

   mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);


   -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА ------------------------------------------------------
   mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);

   -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ ------------------------------
   mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

    -- ОПРЕДЕЛЕНИЕ АДРЕСОВ ТК ---------------------------------------------------
   --   irbis_is_core.get_address_by_tk(mTK_ID, mAddress_ID, mAddress2_ID, 1);

   -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
   -- (mState не проверять, т.к. 1=генерировать исключение)
   mHouseOnly    := 0;
   mPrivateHouse := 0;
   irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
   mAddress2_ID  := NULL;


   -- Осуществлялись ли попытки создания документов ранее
   -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
   mDeclar_ID := irbis_is_core.is_parent_created(RequestID);


   -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА

                  -- поиск ТК --stateTK
      OPEN cur_tk_info;
      FETCH cur_tk_info INTO mST,mTK_ID;
      IF mST=0 or cur_tk_info%NOTFOUND  THEN
     -- irbis_utl.assertTrue((cur_tk_info%NOTFOUND or mST=0), 'Ресурс с переданным идентификатором не найден!');
      -- irbis_utl.assertNotNull((mTK_ID), 'Невозможно определить ТК!');
       irbis_utl.assertTrue((mST!=0), 'Указанная техническая карта уже не действует!!');
       irbis_utl.assertTrue((mTK_ID IS not NULL), 'Невозможно определить ТК!!!');
      -- RAISE_APPLICATION_ERROR(-20001, 'Невозможно определить ТК!');

       RETURN;
      END IF;
      CLOSE cur_tk_info;

        mSubtype_ID := irbis_utl.defineSubtype('BP="34";' ||
                                             'OBJECT="D";' ||
                                             '"');
       irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');


      SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

      IF mCategID = 7 THEN
         SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_USL'), NULL)
           INTO mCuslType_ID FROM dual;
         ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                               SYSDATE, '',
                                               mTelzone_ID, irbis_user_id, mCuslType_ID,
                                               mClientID, 'IRBIS_CONTRAGENT',
                                               mAbonent_ID, 'IRBIS_ABONENT',
                                               mAddress_ID, 'M2000_ADDRESS',
                                               mAddress2_ID, 'M2000_ADDRESS',
                                               0, NULL, NULL, NULL, NULL, NULL);
         -- НАПРАВЛЕНИЕ --------------------------------------------------------------
         -- корректировка отдела-создателя с учетом вида работ
         mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
         irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
         irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
         UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
        ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
      END IF;

      irbis_is_core.create_paper_attrs(mDeclar_ID);
    --  irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
      irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DOC_COMMENT', RequestComment, RequestComment);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_SPEED', mNEW_SREED, mNEW_SREED);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'SPEED', mSPEED,mSPEED);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'TK_NUM', mTK_ID,mTK_ID);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'NAS', mNAS,mNAS);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'VLAN', mVLAN,mVLAN);
     -- irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_USL', Servicetypes, Servicetypes);
      irbis_is_core.update_paper_attr(mDeclar_ID, 'DATE_SPEED', TO_CHAR(DateSpeed, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateSpeed, 'DD.MM.YYYY HH24:MI:SS'));



       -- привязка ID заявки Ирбис к заявлению
      irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 34, MainParam);

       mChildSubtype := irbis_utl.defineSubtype('BP="34";' ||
                                             'OBJECT="O";' ||
                                             '"');
   irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

  -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------

      ad_utils.ad_create_paper_cat7_as(mOrder_ID,
                                       mChildSubtype,
                                       mDeclar_ID,
                                       mSubtype_ID,
                                       irbis_user_id,
                                       SYSDATE,
                                       '',
                                       NULL);

   -- корректировка отдела-создателя с учетом вида работ
   mAbonOtdelID := irbis_utl.getDepCreatorByWork(mOrder_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
   irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
   -- НАПРАВЛЕНИЕ --------------------------------------------------------------
   irbis_is_core.move_created_paper(mOrder_ID, mAbonOtdelID);

  -- END СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------

    irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
    irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_SPEED', TO_CHAR(DateSpeed, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateSpeed, 'DD.MM.YYYY HH24:MI:SS'));
    irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
    --irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
    irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_SPEED', mNEW_SREED, mNEW_SREED);
    irbis_is_core.update_paper_attr(mOrder_ID, 'SPEED', mSPEED,mSPEED);
    irbis_is_core.update_paper_attr(mOrder_ID, 'TK_NUM', mTK_ID,mTK_ID);
    irbis_is_core.update_paper_attr(mOrder_ID, 'NAS', mNAS,mNAS);
    irbis_is_core.update_paper_attr(mOrder_ID, 'VLAN', mVLAN,mVLAN);

   irbis_is_core.write_ts_log(mCuslType_ID,
                mTelzone_ID,
                mSubtype_ID,  -- сохраняется вид документа
                mClientName || '; id=' || TO_CHAR(mClientID),
                mAddress_ID,
                mAddress2_ID,
                mSecondName || ' ' || mFirstName || ' ' || mPatrName,
                mOrgName,
                RequestID,
                Null,
                Null);

         -- привязка ID заявки Ирбис к наряду
   irbis_is_core.attach_paper_to_request(mOrder_ID, RequestID, 34, MainParam);

   irbis_utl.sendPaperNextDepartment(mOrder_ID);

   select PREFIX ||'-'||PNUMBER
    INTO mPNumber
   from ad_papers
  where id=mOrder_ID;

  END CreateSpeedChange;

    -- <13.04.2020 - Хузин А.Ф.> - Создание заявления и техсправки на смену скорости 100+
    PROCEDURE CreateSpeedChange
    (
        RequestID       IN NUMBER,      -- идентификатор заявки в IRBiS
        RequestComment  IN VARCHAR2,    -- комментарий оператора к наряду
        DateMontWish    IN DATE,        -- желаемая дата прихода специалиста
        mContactPhone   IN VARCHAR2,    -- контактный телефон абонента
        Servicetypes    IN VARCHAR2,    -- услуга
        MainParam       IN VARCHAR2,    -- набор XML-данных, содержащий универсальные параметры
        mPNumber        OUT VARCHAR2    -- результат
    ) IS
        mPriorityLong         VARCHAR2(200);
        mTCID                 rm_tk.tk_id%TYPE; -- идентификатор техкарты
        mAbonementID          NUMBER;    -- идентификатор абонемента
        mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
        mApartment            VARCHAR2(200);    -- номер квартиры (офиса), адрес подключения которого интересует
        mOperatorName         VARCHAR2(200);    -- ФИО оператора создавшего заявление
        mClientID             NUMBER;    -- идентификатор клиента в IRBiS
        mClientName           VARCHAR2(300);    -- наименование клиента
        mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
        mMarketingCategory    VARCHAR2(50);
        mPriority             NUMBER;
        mAbonent_ID           ad_paper_content.abonent_id%TYPE;
        mConnectionReason     VARCHAR2(300);
        mTelzone_ID           ad_papers.telzone_id%TYPE;
        mTK_type              rm_tk.tk_type%TYPE;       -- тип техкарты
        mTK_status            rm_tk.tk_status_id%TYPE;  -- номер техкарты
        mSubtype_ID           ad_subtypes.id%TYPE;      -- идентификатор вида документа (родителя)
        mCategID              NUMBER;
        mCuslType_ID          ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
        mContent_ID           ad_paper_content.id%TYPE; -- id содержания созданного документа
        mAddress_ID           ad_paper_content.address_id%TYPE;
        mAddress2_ID          ad_paper_content.address2_id%TYPE;
        mChildSubtype         ad_subtypes.id%TYPE;      -- идентификатор вида документа (дочернего)
        mTS_ID                ad_papers.id%TYPE;        -- id техсправки
        mDeclar_ID            ad_papers.id%TYPE;        -- id заявления
        mAbonOtdelID          ad_papers.department_id%TYPE;       -- id отдела, в котором заявление должно оказаться сразу после создания
        mOtdel_ID             NUMBER;
        m2_adrid              ao_address.id%TYPE;
        mTemp                 NUMBER;
        mHouseOnly            NUMBER;  -- признак того, что квартиры в доме есть, но для определения тех возможности не был указан номер конкретной квартиры
        mPrivateHouse         NUMBER;  -- признак того, что дом - частный (не содержит помещений)
        mState                NUMBER;

    BEGIN
        irbis_is_core.write_irbis_activity_log('CreateSpeedChange',
                                'RequestID="' || TO_CHAR(RequestID) ||
                                '", RequestComment="' || RequestComment ||
                                '", mContactPhone="' || mContactPhone ||
                                '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                                '", ',
                                RequestID,
                                MainParam);
        rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
                  ) LOOP
            CASE x.param_name
                 WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
                 WHEN 'ContractTCID'       THEN mTCID            := TO_NUMBER(x.value);
                 WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
                 WHEN 'ContractAppartment' THEN mApartment   := x.value;
                 WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
                 WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
                 WHEN 'ClientName'         THEN mClientName    := x.value;
                 WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
                 WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
                 WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
                 WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
                 WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
                 ELSE NULL;
            END CASE;
        END LOOP;

        mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);
        -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
        -- (mState не проверять, т.к. 1=генерировать исключение)
        mHouseOnly    := 0;
        mPrivateHouse := 0;
        irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
        mAddress2_ID  := NULL;
        -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА --------------------------------------------------------
        irbis_is_core.get_tk_info(mTCID, mTelzone_ID, mTK_type);
        irbis_utl.assertNotNull(mTCID, 'Не указан номер технической карты!');
        -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ --------------------------------
        mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
        SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTCID;
        irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

        -- Осуществлялись ли попытки создания документов ранее
        -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
        mDeclar_ID := irbis_is_core.is_parent_created(RequestID);

        -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
        mSubtype_ID := irbis_utl.defineSubtype('BP="35";' ||
                                               'OBJECT="D";' ||
                                               '"');
        irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

        SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
        IF mCategID = 7 THEN
            SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_USL'), NULL)
            INTO mCuslType_ID FROM dual;
            ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                              SYSDATE, '',
                                              mTelzone_ID, irbis_user_id, mCuslType_ID,
                                              mClientID, 'IRBIS_CONTRAGENT',
                                              mAbonent_ID, 'IRBIS_ABONENT',
                                              mAddress_ID, 'M2000_ADDRESS',
                                              mAddress2_ID, 'M2000_ADDRESS',
                                              0, NULL, NULL, NULL, NULL, NULL);
            -- привязка абонемента, техкарты к заявлению
            UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = mTCID
            WHERE id = mContent_ID;

            irbis_is_core.create_paper_attrs(mDeclar_ID);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
            irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'DOC_COMMENT', RequestComment, RequestComment);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'TYPE_USL', Servicetypes, Servicetypes);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));

            -- привязка ID заявки Ирбис к заявлению
            irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 35, MainParam);

            -- НАПРАВЛЕНИЕ --------------------------------------------------------------
            -- корректировка отдела-создателя с учетом вида работ
            mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
            irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
            irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
            UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
        ELSE
             RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
        END IF;

        mChildSubtype := irbis_utl.defineSubtype('BP="35";' ||
                                                 'OBJECT="T";' ||
                                                 '"');
        irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');
        -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ ---------------------------------------
        irbis_is_core.create_tc_by_request(mTS_ID,
                            mChildSubtype,
                            mDeclar_ID,
                            mSubtype_ID,
                            RequestID,
                            mOtdel_ID,
                            mAbonOtdelID,
                            0,
                            MainParam);
        mHouseOnly    := 0;
        mPrivateHouse := 0;
        GetAddressID(mHouseID, mApartment, m2_adrid, mHouseOnly, mPrivateHouse, 1, mTemp);
        IF irbis_is_core.isOver100Available(m2_adrid) = 1 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'FREE_PORT', 1, 'Есть доступные порты');
        ELSE
            irbis_is_core.update_paper_attr(mTS_ID, 'FREE_PORT', 0, 'Нет доступных портов');
        END IF;

        SELECT PREFIX ||'-'||PNUMBER
        INTO mPNumber
        FROM ad_papers
        WHERE id = mTS_ID;

        irbis_utl.sendPaperNextDepartment(mTS_ID);
    END CreateSpeedChange;

    -- <13.04.2020 - Хузин А.Ф.> - Создание наряда на смену скорости 100+
    PROCEDURE CreateSpeedChangeOrder
    (
       RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
       RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
       DateMontWish    IN DATE,     -- желаемая дата прихода специалиста
       mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
       Servicetypes    IN VARCHAR2,    -- услуга
       MainParam       IN VARCHAR2,   -- набор XML-данных, содержащий универсальные параметры
       mPNumber        OUT VARCHAR2
    ) IS
       CURSOR GetSubtypeID IS
       SELECT ap.subtype_id FROM irbis_request_papers irp
       JOIN ad_papers ap ON ap.id = irp.paper_id;
       mSubtype_ID    ad_subtypes.id%TYPE;  -- вид родительского документа
       mTelzone_ID    ad_papers.telzone_id%TYPE;
       mAbonent_ID    ad_paper_content.abonent_id%TYPE;

       CURSOR GetParentPaper(aREQUEST  NUMBER) IS
       SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
       FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
             AND r.paper_id = p.id
             AND p.parent_id IS NULL
             and p.STATE_ID !='C';

       mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
       mOrder_ID      ad_papers.id%TYPE;            -- id наряда

       mMarketingCategory VARCHAR2(50);
       mPriority        NUMBER;
       mPriorityLong    VARCHAR2(200);

       mClientID             NUMBER;    -- идентификатор клиента в IRBiS
       mClientName           VARCHAR2(300);  -- наименование клиента
       mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
       mAbonementID          NUMBER;    -- идентификатор абонемента
       mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
       mApartment            VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
       mOperatorName         VARCHAR2(200);  -- ФИО оператора создавшего заявление

       mAbonOtdelID   ad_papers.department_id%TYPE;
       mChildSubtype  ad_subtypes.id%TYPE;

       mParent_ID     ad_papers.id%TYPE;
       mParentSubtype ad_subtypes.id%TYPE;
       mOtdel_ID      ad_papers.department_id%TYPE;

    BEGIN

       irbis_is_core.write_irbis_activity_log('CreateSpeedChangeOrder',
                                'RequestID="' || TO_CHAR(RequestID) ||
                                '", RequestComment="' || RequestComment ||
                                '", mContactPhone="' || mContactPhone ||
                                '", DateMontWish="' || TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS') ||
                                '", ',
                                RequestID,
                                MainParam);
       rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

       -- Разбор XML
       FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
                ) LOOP
          CASE x.param_name
             WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
             WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
             WHEN 'ContractAppartment' THEN mApartment   := x.value;
             WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
             WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
             WHEN 'ClientName'         THEN mClientName    := x.value;
             WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
             WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
             WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
             WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
             ELSE NULL;
          END CASE;
       END LOOP;

       mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);
       OPEN GetParentPaper(RequestID);
       FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
       CLOSE GetParentPaper;
       IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
          RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
       END IF;
       irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

       mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
       OPEN GetSubtypeID;
       FETCH GetSubtypeID INTO mSubtype_ID;
       CLOSE GetSubtypeID;
       mChildSubtype := irbis_utl.defineSubtype('BP="35";' ||
                                                'OBJECT="O";' ||
                                                '"');
       irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

      -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
          irbis_is_core.create_tc_by_request(mOrder_ID,
                            mChildSubtype,
                            mParent_ID,
                            mParentSubtype,
                            RequestID,
                            mOtdel_ID,
                            mAbonOtdelID,
                            0,
                            MainParam);

          /*ad_utils.ad_create_paper_cat7_as(mOrder_ID,
                                           mChildSubtype,
                                           mDeclar_ID,
                                           mSubtype_ID,
                                           irbis_user_id,
                                           SYSDATE,
                                           '',
                                           NULL);*/


       -- корректировка отдела-создателя с учетом вида работ
       mAbonOtdelID := irbis_utl.getDepCreatorByWork(mOrder_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
       irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
       -- НАПРАВЛЕНИЕ --------------------------------------------------------------
       irbis_is_core.move_created_paper(mOrder_ID, mAbonOtdelID);

       irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
       irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
       irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
       irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);

       irbis_utl.sendPaperNextDepartment(mOrder_ID);

       select PREFIX ||'-'||PNUMBER
       INTO mPNumber
       from ad_papers
       where id=mOrder_ID;

    END CreateSpeedChangeOrder;

    -- <17.12.2020 - Хузин А.Ф.> - Создание заявления и техсправки на выдачу и удаление номеров ВАТС
    PROCEDURE CreateNumberVATS
    (
        RequestID       IN NUMBER,      -- идентификатор заявки в IRBiS
        RequestComment  IN VARCHAR2,    -- комментарий оператора к наряду
        mContactPhone   IN VARCHAR2,    -- контактный телефон абонента
        NumberType      IN VARCHAR2,    -- тип номера: 1 - Внешний номер; 2 - Номер DIZA; 3 - Внутренний номер
        Conditions      IN NUMBER,      -- условие: 1 - добавление 2 - удаление номера
        mPhone          IN VARCHAR2,    -- номера
        MainParam       IN VARCHAR2,    -- набор XML-данных, содержащий универсальные параметры
        mPNumber        OUT VARCHAR2,   -- ТС
        mAccount        IN NUMBER,      -- ЛС
        mDomenVATS      IN VARCHAR2     -- наименование домена ВАТС
    ) IS
        mPriorityLong         VARCHAR2(200);
        mTCID                 rm_tk.tk_id%TYPE; -- идентификатор техкарты
        mAbonementID          NUMBER;    -- идентификатор абонемента
        mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
        mApartment            VARCHAR2(200);    -- номер квартиры (офиса), адрес подключения которого интересует
        mOperatorName         VARCHAR2(200);    -- ФИО оператора создавшего заявление
        mClientID             NUMBER;    -- идентификатор клиента в IRBiS
        mClientName           VARCHAR2(300);    -- наименование клиента
        mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
        mMarketingCategory    VARCHAR2(50);
        mPriority             NUMBER;
        mAbonent_ID           ad_paper_content.abonent_id%TYPE;
        mConnectionReason     VARCHAR2(300);
        mTelzone_ID           ad_papers.telzone_id%TYPE;
        mTK_type              rm_tk.tk_type%TYPE;       -- тип техкарты
        mTK_status            rm_tk.tk_status_id%TYPE;  -- номер техкарты
        mSubtype_ID           ad_subtypes.id%TYPE;      -- идентификатор вида документа (родителя)
        mCategID              NUMBER;
        mCuslType_ID          ad_paper_content.cusl_type_id%TYPE; -- тип услуги в M2000
        mContent_ID           ad_paper_content.id%TYPE; -- id содержания созданного документа
        mAddress_ID           ad_paper_content.address_id%TYPE;
        mAddress2_ID          ad_paper_content.address2_id%TYPE;
        mChildSubtype         ad_subtypes.id%TYPE;      -- идентификатор вида документа (дочернего)
        mTS_ID                ad_papers.id%TYPE;        -- id техсправки
        mDeclar_ID            ad_papers.id%TYPE;        -- id заявления
        mAbonOtdelID          ad_papers.department_id%TYPE;       -- id отдела, в котором заявление должно оказаться сразу после создания
        mOtdel_ID             NUMBER;
        m2_adrid              ao_address.id%TYPE;
        mTemp                 NUMBER;
        mHouseOnly            NUMBER;  -- признак того, что квартиры в доме есть, но для определения тех возможности не был указан номер конкретной квартиры
        mPrivateHouse         NUMBER;  -- признак того, что дом - частный (не содержит помещений)
        mState                NUMBER;

    BEGIN
        irbis_is_core.write_irbis_activity_log('CreateNumberVATS',
                                'RequestID="' || TO_CHAR(RequestID) ||
                                '", RequestComment="' || RequestComment ||
                                '", mContactPhone="' || mContactPhone ||
                                '", NumberType="' || NumberType ||
                                '", Conditions="' || Conditions ||
                                '", mPhone="' || mPhone ||
                                '", mDomenVATS="' || mDomenVATS ||
                                '", ',
                                RequestID,
                                MainParam);
        rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;
        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
                  ) LOOP
            CASE x.param_name
                 WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
                 WHEN 'ContractTCID'       THEN mTCID            := TO_NUMBER(x.value);
                 WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
                 WHEN 'ContractAppartment' THEN mApartment   := x.value;
                 WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
                 WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
                 WHEN 'ClientName'         THEN mClientName    := x.value;
                 WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
                 WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
                 WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
                 WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
                 WHEN 'ConnectionReason'   THEN mConnectionReason := x.VALUE;
                 ELSE NULL;
            END CASE;
        END LOOP;

        mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);
        -- ОПРЕДЕЛЕНИЯ АДРЕСА -------------------------------------------------------
        -- (mState не проверять, т.к. 1=генерировать исключение)
        mHouseOnly    := 0;
        mPrivateHouse := 0;
        irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
        mAddress2_ID  := NULL;
        -- ОПРЕДЕЛЕНИЕ ФИЛИАЛА --------------------------------------------------------
        irbis_is_core.get_tk_info(mTCID, mTelzone_ID, mTK_type);
        irbis_utl.assertNotNull(mTCID, 'Не указан номер технической карты!');
        -- ОТДЕЛ, В КОТОРОМ ДОЛЖНО ОКАЗАТЬСЯ ЗАЯВЛЕНИЕ --------------------------------
        mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);
        SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTCID;
        irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

        -- Осуществлялись ли попытки создания документов ранее
        -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
        mDeclar_ID := irbis_is_core.is_parent_created(RequestID);
        -- ЕСЛИ УЖЕ ПРОИЗВОДИЛИСЬ ПОПЫТКИ СОЗДАНИЯ ЦЕПОЧКИ, ТО РОДИТЕЛЬСКИЙ ДОКУМЕНТ НЕ СОЗДАЕТСЯ ВО ВТОРОЙ РАЗ
        IF (mDeclar_ID IS NOT NULL) THEN
            irbis_is_core.get_created_paper_data(mDeclar_ID,
                                                 mCategID,
                                                 --mDocType,
                                                 mSubtype_ID,
                                                 mContent_ID,
                                                 mAddress_ID,
                                                 mAddress2_ID);
        -- ПЕРВАЯ ПОПЫТКА СОЗДАНИЯ ДОКУМЕНТА
        ELSE
            mSubtype_ID := irbis_utl.defineSubtype('BP="36";' ||
                                                   'OBJECT="D";' ||
                                                   '"');
            irbis_utl.assertTrue((mSubtype_ID IS NOT NULL), 'Не определен вид заявления');

            SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
            IF mCategID = 7 THEN
                SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_USL'), NULL)
                INTO mCuslType_ID FROM dual;
                ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                                  SYSDATE, '',
                                                  mTelzone_ID, irbis_user_id, mCuslType_ID,
                                                  mClientID, 'IRBIS_CONTRAGENT',
                                                  mAbonent_ID, 'IRBIS_ABONENT',
                                                  mAddress_ID, 'M2000_ADDRESS',
                                                  mAddress2_ID, 'M2000_ADDRESS',
                                                  0, NULL, NULL, NULL, NULL, NULL);
                -- привязка абонемента, техкарты к заявлению
                UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = mTCID
                WHERE id = mContent_ID;

                irbis_is_core.create_paper_attrs(mDeclar_ID);
                irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
                irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
                irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
                irbis_is_core.update_paper_attr(mDeclar_ID, 'DOC_COMMENT', RequestComment, RequestComment);
                irbis_is_core.update_paper_attr(mDeclar_ID, 'CARDNUM_IRBIS', mAccount, mAccount);
                IF NumberType = 1 THEN
                    irbis_is_core.update_paper_attr(mDeclar_ID, 'NUM_TYPE', NumberType, 'Внешний номер');
                ELSIF NumberType = 2 THEN
                    irbis_is_core.update_paper_attr(mDeclar_ID, 'NUM_TYPE', NumberType, 'Номер DIZA');
                ELSIF NumberType = 3 THEN
                    irbis_is_core.update_paper_attr(mDeclar_ID, 'NUM_TYPE', NumberType, 'Внутренний номер');
                END IF;
                irbis_is_core.update_paper_attr(mDeclar_ID, 'NAME_VATS', mDomenVATS, mDomenVATS);


                -- привязка ID заявки Ирбис к заявлению
                irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, 36, MainParam);

                -- НАПРАВЛЕНИЕ --------------------------------------------------------------
                -- корректировка отдела-создателя с учетом вида работ
                mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
                irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
                irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);
                UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID WHERE id = mContent_ID;
            ELSE
                 RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
            END IF;
        END IF;

        mChildSubtype := irbis_utl.defineSubtype('BP="36";' ||
                                                 'OBJECT="T";' ||
                                                 '"');
        irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид техсправки');
        -- СОЗДАНИЕ ТЕХСПРАВКИ НА ОСНОВАНИИ ЗАЯВЛЕНИЯ ---------------------------------------
        irbis_is_core.create_tc_by_request(mTS_ID,
                            mChildSubtype,
                            mDeclar_ID,
                            mSubtype_ID,
                            RequestID,
                            mOtdel_ID,
                            mAbonOtdelID,
                            0,
                            MainParam);

        irbis_is_core.update_paper_attr(mTS_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
        irbis_is_core.update_paper_attr(mTS_ID, 'DOC_COMMENT', RequestComment, RequestComment);
        irbis_is_core.update_paper_attr(mTS_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
        irbis_is_core.update_paper_attr(mTS_ID, 'VATS_NUMBERS', mPhone, mPhone);
        irbis_is_core.update_paper_attr(mTS_ID, 'DOC_COMMENT', RequestComment, RequestComment);
        irbis_is_core.update_paper_attr(mTS_ID, 'CARDNUM_IRBIS', mAccount, mAccount);
        IF Conditions = 1 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'CONDITIONS', Conditions, 'Добавление номеров');
        ELSIF Conditions = 2 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'CONDITIONS', Conditions, 'Удаление номеров');
        END IF;
        IF NumberType = 1 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'NUM_TYPE', NumberType, 'Внешний номер');
        ELSIF NumberType = 2 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'NUM_TYPE', NumberType, 'Номер DIZA');
        ELSIF NumberType = 3 THEN
            irbis_is_core.update_paper_attr(mTS_ID, 'NUM_TYPE', NumberType, 'Внутренний номер');
        END IF;
        irbis_is_core.update_paper_attr(mTS_ID, 'NAME_VATS', mDomenVATS, mDomenVATS);

        SELECT PREFIX ||'-'||PNUMBER
        INTO mPNumber
        FROM ad_papers
        WHERE id = mTS_ID;

        irbis_utl.sendPaperNextDepartment(mTS_ID);
    END CreateNumberVATS;

    -- <17.12.2020 - Хузин А.Ф.> - Создание наряда на на выдачу и удаление номеров ВАТС
    PROCEDURE CreateNumbersVATSOrder
    (
       RequestID       IN NUMBER,    -- идентификатор заявки в IRBiS
       RequestComment  IN VARCHAR2,  -- комментарий оператора к наряду
       mContactPhone   IN VARCHAR2,  -- контактный телефон абонента
       NumberType      IN VARCHAR2,  -- тип номера: 1 - Внешний номер; 2 - Номер DIZA; 3 - Внутренний номер
       Conditions      IN NUMBER,    -- условие: 1 - добавление; 2 - удаление номера
       mPhone          IN VARCHAR2,  -- номера
       MainParam       IN VARCHAR2,  -- набор XML-данных, содержащий универсальные параметры
       mPNumber        OUT VARCHAR2, -- наряд
       mAccount        IN NUMBER,    -- ЛС
       mDomenVATS      IN VARCHAR2   -- наименование домена ВАТС
    ) IS




       mTelzone_ID    ad_papers.telzone_id%TYPE;
       mAbonent_ID    ad_paper_content.abonent_id%TYPE;

       CURSOR GetParentPaper(aREQUEST  NUMBER) IS
       SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
       FROM ad_papers p, irbis_request_papers r
       WHERE r.request_id = aREQUEST
             AND r.paper_id = p.id
             AND p.parent_id IS NULL
             and p.STATE_ID !='C';

       mDeclar_ID     ad_papers.id%TYPE;            -- id созданного документа
       mOrder_ID      ad_papers.id%TYPE;            -- id наряда

       mMarketingCategory VARCHAR2(50);
       mPriority        NUMBER;
       mPriorityLong    VARCHAR2(200);

       mClientID             NUMBER;    -- идентификатор клиента в IRBiS
       mClientName           VARCHAR2(300);  -- наименование клиента
       mClientTypeID         NUMBER;    -- тип клиента (1 - физическое лицо, 2 - юридическое лицо)
       mAbonementID          NUMBER;    -- идентификатор абонемента
       mHouseID              NUMBER;    -- идентификатор дома, адрес подключения которого интересует
       mApartment            VARCHAR2(200);  -- номер квартиры (офиса), адрес подключения которого интересует
       mOperatorName         VARCHAR2(200);  -- ФИО оператора создавшего заявление

       mAbonOtdelID   ad_papers.department_id%TYPE;
       mChildSubtype  ad_subtypes.id%TYPE;

       mParent_ID     ad_papers.id%TYPE;
       mParentSubtype ad_subtypes.id%TYPE;
       mOtdel_ID      ad_papers.department_id%TYPE;
       mTariffPlanName       VARCHAR2(200);

    BEGIN

       irbis_is_core.write_irbis_activity_log('CreateNumbersVATSOrder',
                                'RequestID="' || TO_CHAR(RequestID) ||
                                '", RequestComment="' || RequestComment ||
                                '", NumberType="' || NumberType ||
                                '", mContactPhone="' || mContactPhone ||
                                '", Conditions="' || Conditions ||
                                '", mPhone="' || mPhone ||
                                '", mDomenVATS="' || mDomenVATS ||
                                '", ',
                                RequestID,
                                MainParam);
       rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

       -- Разбор XML
       FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE')
                ) LOOP
          CASE x.param_name
             WHEN 'ContractCommonID'   THEN mAbonementID     := TO_NUMBER(x.value);
             WHEN 'ContractHouseID'    THEN mHouseID   := TO_NUMBER(x.value);
             WHEN 'ContractAppartment' THEN mApartment   := x.value;
             WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
             WHEN 'ClientID'           THEN mClientID    := TO_NUMBER(x.value);
             WHEN 'ClientName'         THEN mClientName    := x.value;
             WHEN 'ClientTypeID'       THEN mClientTypeID    := TO_NUMBER(x.value);
             WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
             WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.VALUE);
             WHEN 'AccountID'          THEN mAbonent_ID      := TO_NUMBER(x.VALUE);
             WHEN 'TariffPlanName'     THEN mTariffPlanName  := x.VALUE;
             ELSE NULL;
          END CASE;
       END LOOP;

       mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);
       OPEN GetParentPaper(RequestID);
       FETCH GetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
       CLOSE GetParentPaper;
       IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
          RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
       END IF;
       irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');

       mDeclar_ID := irbis_is_core.is_parent_created(RequestID);



       mChildSubtype := irbis_utl.defineSubtype('BP="36";' ||
                                                'OBJECT="O";' ||
                                                '"');
       irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

      -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
          irbis_is_core.create_tc_by_request(mOrder_ID,
                            mChildSubtype,
                            mParent_ID,
                            mParentSubtype,
                            RequestID,
                            mOtdel_ID,
                            mAbonOtdelID,
                            0,
                            MainParam);

       -- корректировка отдела-создателя с учетом вида работ
       mAbonOtdelID := irbis_utl.getDepCreatorByWork(mOrder_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
       irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
       -- НАПРАВЛЕНИЕ --------------------------------------------------------------
       irbis_is_core.move_created_paper(mOrder_ID, mAbonOtdelID);

       irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
       irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
       irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
       irbis_is_core.update_paper_attr(mOrder_ID, 'VATS_NUMBERS', mPhone, mPhone);
       irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
       irbis_is_core.update_paper_attr(mOrder_ID, 'CARDNUM_IRBIS', mAccount, mAccount);
       irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);
       IF Conditions = 1 THEN
            irbis_is_core.update_paper_attr(mOrder_ID, 'CONDITIONS', Conditions, 'Добавление номеров');
       ELSIF Conditions = 2 THEN
            irbis_is_core.update_paper_attr(mOrder_ID, 'CONDITIONS', Conditions, 'Удаление номеров');
       END IF;
       IF NumberType = 1 THEN
            irbis_is_core.update_paper_attr(mOrder_ID, 'NUM_TYPE', NumberType, 'Внешний номер');
        ELSIF NumberType = 2 THEN
            irbis_is_core.update_paper_attr(mOrder_ID, 'NUM_TYPE', NumberType, 'Номер DIZA');
        ELSIF NumberType = 3 THEN
            irbis_is_core.update_paper_attr(mOrder_ID, 'NUM_TYPE', NumberType, 'Внутренний номер');
        END IF;
        irbis_is_core.update_paper_attr(mOrder_ID, 'NAME_VATS', mDomenVATS, mDomenVATS);

       irbis_utl.sendPaperNextDepartment(mOrder_ID);

       select PREFIX ||'-'||PNUMBER
       INTO mPNumber
       from ad_papers
       where id = mOrder_ID;

    END CreateNumbersVATSOrder;

    -- Процедура логирования
    PROCEDURE ad_eq_logs(--LOG_ID  NUMBER
                         --LOG_DATE DATE
                         OPERATION  VARCHAR2,
                         REQUEST_ID NUMBER,
                         equipmentNumberOld VARCHAR2,
                         LOG_ERRORS VARCHAR2)
    is
    PRAGMA AUTONOMOUS_TRANSACTION;
    begin
    insert into ad_eq_logs(LOG_ID, log_date, OPERATION, REQUEST_ID, equipmentNumberOld, log_errors)
    values (eq_logs_seq.nextval, sysdate, OPERATION, REQUEST_ID, equipmentNumberOld, log_errors);
    commit;
    END;

    -- Получение текущей информации о коммутаторе по связанной техкарте с абонементом  КТВ GPON
    PROCEDURE GetCurrentEquipGpon(  RequestID IN NUMBER,
                                    ContractTCID IN NUMBER,
                                    IPadr OUT VARCHAR2,
                                    OID OUT VARCHAR2,
                                    VirtPort OUT VARCHAR2,
                                    EquipmentNumber OUT VARCHAR2)
    IS
    BEGIN
    OID:='1.3.6.1.4.1.2011.6.128.1.1.2.63.1.2';
     SELECT REPLACE(p.PRT_NAME, 'virtport', '') port_name, ip.RVL_VALUE ip_addr
       INTO VirtPort, IPadr
       FROM RM_EQUIPMENT e,
        rm_res_prop_value ip,
        RM_EQUIP_UNIT u,
        RM_EQUIP_PORT p,
        RM_TK_DATA tk,
        RM_TK t,
        rm_res_type rt
      WHERE ip.rvl_res = e.EQU_ID
        AND e.equ_type = 1003
        AND ip.RVL_PROP_ID = 1971 --свойство АЙПи адрес данного оборудования
        AND u.UN_EQUIP = e.EQU_ID
        AND p.PRT_UNIT = u.UN_ID
        --and t.tk_type in (374,302,82,2,282,42,375,22,342) -- тип ТК
        AND tk.tkd_res_class = 2 --порты в тех карте
        AND t.TK_STATUS_ID = 1   -- ТК В ФИКСАЦИИ
        AND tk.tkd_tk = t.tk_id
        AND tk.tkd_resource = p.prt_id
        AND Rt.Rty_Id = E.Equ_Type
        AND t.tk_id = ContractTCID;

     SELECT ser.RVL_VALUE
       INTO EquipmentNumber
       FROM RM_EQUIPMENT e,
        RM_TK_DATA tk,
        RM_TK t,
        rm_res_type rt,
        rm_res_prop_value ser,
        RM_RES_PROPERTY p
      WHERE e.equ_type = 4294
        AND p.RPR_STRCOD = 'SERIAL'
        AND p.RPR_RESTYPE = e.equ_type
        AND ser.RVL_PROP_ID = p.RPR_ID
        --and t.tk_type in (374,302,82,2,282,42,375,22,342) -- тип ТК
        AND tk.tkd_res_class = 1 -- оборудование в тех карте
        AND t.TK_STATUS_ID = 1   -- ТК В ФИКСАЦИИ
        AND tk.tkd_tk = t.tk_id
        AND tk.tkd_resource = e.equ_id
        AND ser.RVL_RES = e.equ_id
        AND Rt.Rty_Id = E.Equ_Type
        AND t.tk_id = ContractTCID;
    END;

    -- Смена типа номера и типа ТК для переключения телефонии на SIP-VOIP
    PROCEDURE ChangeTypeTKAndNumber
    (
        pTK_ID  IN rm_tk_data.tkd_tk%TYPE,          -- ID ТК
        pNumber IN rm_numbers.num_number%TYPE       -- Номер телефона (не мобилка)
    ) IS
        CURSOR cCheckResToTK(cTK_ID rm_tk_data.tkd_tk%TYPE, cNumber rm_numbers.num_number%TYPE) IS
        SELECT rm.tkd_resource, n.num_id FROM rm_tk_data rm, rm_numbers n
        WHERE rm.tkd_tk = cTK_ID
            AND n.num_number = cNumber
            AND rm.tkd_resource = n.num_id
            AND rm.tkd_res_class = 6;

        mNumberRes      rm_tk_data.tkd_resource%TYPE;
        mNumber_ID      rm_numbers.num_id%TYPE;

    BEGIN
        OPEN cCheckResToTK(pTK_ID, pNumber);
        FETCH cCheckResToTK INTO mNumberRes, mNumber_ID;
        IF cCheckResToTK%NOTFOUND THEN
            CLOSE cCheckResToTK;
            RAISE_APPLICATION_ERROR(-20001, 'Номерная емкость '||pNumber||' не найдена в ТК-'||pTK_ID);
        END IF;
        CLOSE cCheckResToTK;
        IF mNumberRes IS NOT NULL THEN
            -- Меняем тип ТК
            UPDATE rm_tk SET tk_type = 202          -- Тип ТК: SIP - Телефония
            WHERE tk_id = pTK_ID AND tk_type = 1;   -- Тип ТК: Телефон
            -- Меняем тип номера
            UPDATE rm_rub_value SET rbv_record = 267            -- Тип номерной емкости: SIP
            WHERE rbv_entity = mNumberRes AND rbv_record = 266; -- Тип номерной емкости: Аналоговый номер
            -- Меняем Головную АТС на "АТС ОПТС-590" и удаляем привязку к порту АТС
            UPDATE rm_numbers SET num_ats = 10718333, num_port = NULL
            WHERE num_id = mNumber_ID;
            -- Запись в историю ТК о смене типа ТК
            rm_pkg.addTKHistory(pTK_ID, 2400, 'TK_TYPE', NULL, 1, 202, NULL, 0, ' со сменой типа номера и головного АТС');
        END IF;
    END;

    -- Создание ТС на перелючение телефонии на SIP VOIP
    PROCEDURE ChangeOnSIPVOIP
    (
        RequestID        IN  NUMBER,    -- ID заявки
        TK_ID            IN  NUMBER,    -- ID тех.карты
        PhoneNumber      IN  VARCHAR2,  -- номер телефона
        PhoneCategory    IN  NUMBER,    -- Оператор дальней связи
        CallBarringState IN  NUMBER,    -- ВЗ,МГ,МН
        ConnectionType   IN  VARCHAR2,  -- Тип подключения
        EquipmentNumber  IN  VARCHAR2,  -- Серийный номер fake-оборудования
        DeviceType       IN  VARCHAR2,  -- Модель оборудования
        MainParam        IN  VARCHAR2
    ) IS
        CURSOR cGetFXSPort(cEquipmentNumber VARCHAR2) IS
        SELECT ep.prt_id, e.equ_id
        FROM rm_equipment e, rm_res_prop_value v, rm_res_property rp,
                 rm_equip_unit eu, rm_equip_port ep
        WHERE v.rvl_res = e.equ_id
            AND v.rvl_prop_id = rp.rpr_id
            AND v.rvl_res_type = rp.rpr_restype
            --AND rp.rpr_strcod = 'SERIAL'
            AND rp.rpr_restype IN (1263, 1083)               -- типы устройств "SIP адаптер" и "CPE"
            AND LOWER(v.rvl_value) = LOWER(cEquipmentNumber)
            AND eu.un_equip = e.equ_id
            AND ep.prt_unit = eu.un_id
            AND ep.prt_type = 1323                           -- порт FXS
            AND rm_pkg.GetResState(ep.prt_id, 2) = 0
        ORDER BY ep.prt_name;

        -- Получение информации по занятым FXS-портам по ID оборудования
        CURSOR GetInfoUsedPorts (cEquipId rm_equipment.equ_id%TYPE) IS
        SELECT row_number() OVER(ORDER BY ep.prt_name) prt_rownum, ep.prt_id, t.tk_id, d.tkd_id
        FROM rm_equipment e, rm_equip_unit eu, rm_equip_port ep, rm_tk_data d, rm_tk t
        WHERE e.equ_id = cEquipId
            AND e.equ_id = eu.un_equip
            AND eu.un_id = ep.prt_unit
            AND ep.prt_type = 1323      -- порт FXS
            AND rm_pkg.GetResState(ep.prt_id, 2) > 0
            AND d.tkd_resource = ep.prt_id
            AND d.tkd_res_class = 2
            AND d.tkd_tk=t.tk_id
            AND t.tk_status_id !=0
            AND t.tk_type = tk_type_sip
        ORDER BY ep.prt_name;

        mKeyParams          irbis_activity_log.PARAMETERS%TYPE;
        mAddress_ID         ad_paper_content.address_id%TYPE;
        mAddress2_ID        ad_paper_content.address2_id%TYPE;
        mHouseID            NUMBER;    -- ID дома
        mApartment          VARCHAR2(200);  -- ID квартиры
        mState              NUMBER;
        mAbonementID        NUMBER;    -- идентификатор абонемента
        mContactPhone       VARCHAR2(200);  -- Контактный телефон абонента
        mOperatorName       VARCHAR2(200);  -- ФИО оператора создавшего заявление
        mClientID           NUMBER;    -- Идентификатор клиента в IRBiS
        mMarketingCategory  VARCHAR2(50);
        mPriority           NUMBER;
        mPriorityLong       VARCHAR2(200);
        mAbonent_ID         ad_paper_content.abonent_id%TYPE;
        mTariffPlanName     ad_paper_attr.value_long%TYPE;

        mHouseOnly      NUMBER;           -- Признак того, что для многоквартирного дома не была указана квартира
        mPrivateHouse   NUMBER;           -- Признак того, что дом является частным (без квартир)
        mTelzone_ID     ad_papers.telzone_id%TYPE;
        mAbonOtdelID    ad_papers.department_id%TYPE;   -- ID отдела, в котором должно оказаться заявление после создания
        mOtdel_ID       ad_papers.department_id%TYPE;   -- ID отдела, в котором должна оказаться ТС после создания

        mParentExists   NUMBER; -- Количество документов
        mDeclar_ID      ad_papers.id%TYPE; -- ID заявления
        mTS_ID          ad_papers.id%TYPE; -- ID техсправки
        mCategID        NUMBER;
        mSubtype_ID     ad_subtypes.id%TYPE;        -- ID вида заявления
        mChildSubtype   ad_subtypes.id%TYPE;        -- ID вида ТС
        mContent_ID     ad_paper_content.id%TYPE;   -- ID содержания созданного документа

        mProc           NUMBER;
        mTK_type        rm_tk.tk_type%TYPE;
        mRMDocID        NUMBER;
        mPortID         rm_equip_port.prt_id%TYPE;
        mOldAbonementID NUMBER;

        mCuslType_ID    ad_paper_content.cusl_type_id%TYPE; -- Тип услуги в M2000

        mAttrValue      ad_paper_attr.value%TYPE;
        mAttrValuLong   ad_paper_attr.value_long%TYPE;
        mNewEquipID     rm_equipment.equ_id%TYPE; -- ID нового оборудования
        mAddress_otherTK    ad_paper_content.address_id%TYPE;
        mAbonent2_ID    ad_paper_content.abonent_id%TYPE; -- Идентификатор лицевого счета, который использует новое оборудование
        mAbonent2_numb  NUMBER; -- Номер лицевого счета, который использует новое оборудование
        mTK_info        VARCHAR2(300); -- Полное название ТК, который использует новое оборудование
        mTD_ID          NUMBER;


    BEGIN
        mKeyParams := 'TK_ID="' || TK_ID ||
                     '", PhoneNumber="' || PhoneNumber ||
                     '", PhoneCategory="' || PhoneCategory ||
                     '", CallBarringState="' || CallBarringState ||
                     '", ConnectionType="' || ConnectionType ||
                     '", EquipmentNumber="' || EquipmentNumber ||
                     '", DeviceType="' || DeviceType ||
                     '"';
        irbis_is_core.write_irbis_activity_log('ChangeOnSIPVOIP',
                                                'RequestID="' || TO_CHAR(RequestID) ||
                                                '", ' || mKeyParams,
                                                RequestID,
                                                MainParam);
        rm_security.setuser(IRBIS_USER_ID);
        m2_common.appuser_id := IRBIS_USER_ID;
        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE'))
        LOOP
            CASE x.param_name
                WHEN 'ContractCommonID'   THEN mAbonementID         := TO_NUMBER(x.VALUE);
                WHEN 'ContractHouseID'    THEN mHouseID             := TO_NUMBER(x.value);
                WHEN 'ContractAppartment' THEN mApartment           := x.value;
                WHEN 'ClientPhones'       THEN mContactPhone        := x.VALUE;
                WHEN 'RequestCreator'     THEN mOperatorName        := x.VALUE;
                WHEN 'ClientID'           THEN mClientID            := TO_NUMBER(x.VALUE);
                WHEN 'MarketingCategory'  THEN mMarketingCategory   := x.VALUE;
                WHEN 'Priority'           THEN mPriority            := TO_NUMBER(x.VALUE);
                WHEN 'AccountID'          THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
                WHEN 'TariffPlanName'     THEN mTariffPlanName      := x.VALUE;
                ELSE NULL;
            END CASE;
        END LOOP;

        mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

        -- Определение адреса (mState не проверять, т.к. 1=генерировать исключение)
        mHouseOnly    := 0;
        mPrivateHouse := 0;
        mAddress2_ID  := NULL;
        irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
        -- Определение филиала
        mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);
        -- Отдел, в котором должно оказаться заявление
        mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

        -- Осуществлялись ли попытки создания документов ранее
        -- Если да, существует заявление, связанное с заявкой Ирбис и повторно создавать его не нужно
        mParentExists := 0;
        SELECT COUNT(id) INTO mParentExists
        FROM ad_papers p
        WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
            AND p.object_code = 'D';
        -- Если была попытка создания заявления, то берем его ID
        IF (mParentExists > 0) THEN
            SELECT p.id INTO mDeclar_ID FROM ad_papers p
            WHERE EXISTS (SELECT 1 FROM irbis_request_papers r WHERE r.request_id = RequestID AND r.paper_id = p.id)
                AND p.object_code = 'D'
                AND ROWNUM < 2;
            -- Проверка, не поменялись ли ключевые параметры
            checkKeyParams('ChangeOnSIPVOIP', mDeclar_ID, mKeyParams);
            irbis_is_core.get_created_paper_data(mDeclar_ID,
                                                 mCategID,
                                                 mSubtype_ID,
                                                 mContent_ID,
                                                 mAddress_ID,
                                                 mAddress2_ID);
            mProc := irbis_is_core.get_proc_by_paper(mDeclar_ID);

            IF mProc = irbis_utl.BP_SIP THEN
                mTK_type := tk_type_sip;
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'Не удалось определить бизнес-процесс');
            END IF;
        -- Первая попытка создания документов
        ELSE
            mProc    := 37;             -- Новый БП
            mTK_type := tk_type_sip;    -- 202
            mSubtype_ID   := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                                       'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                                       'OBJECT="D";' || '"');
            IF mSubtype_ID IS NULL THEN
                RAISE_APPLICATION_ERROR(-20001, 'Не определен вид заявления');
            END IF;
            mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                                       'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                                       'OBJECT="T";' || '"');
            IF mChildSubtype IS NULL THEN
                RAISE_APPLICATION_ERROR(-20001, 'Не определен вид ТС');
            END IF;

            SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;
            -- СОЗДАНИЕ ЗАЯВЛЕНИЯ
            IF mCategID = 7 THEN
                SELECT NVL((SELECT id FROM ad_list_card_type
                            WHERE card_id = 3 AND strcod = 'IRBIS_TEL'), NULL) INTO mCuslType_ID FROM dual;
                -- Создание заявления
                ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                                       SYSDATE, '',
                                                       mTelzone_ID, IRBIS_USER_ID, mCuslType_ID,
                                                       mClientID, 'IRBIS_CONTRAGENT',
                                                       mAbonent_ID, 'IRBIS_ABONENT',
                                                       mAddress_ID, 'M2000_ADDRESS',
                                                       mAddress2_ID, 'M2000_ADDRESS',
                                                       0, NULL, NULL, NULL, NULL, NULL);
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
            END IF;
            -- Заполнение атрибутов
            irbis_is_core.create_paper_attrs(mDeclar_ID);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', TO_CHAR(RequestID), TO_CHAR(RequestID));
            irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', ConnectionType, ConnectionType);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);
            mAttrValue := TO_CHAR(CallBarringState);
            CASE CallBarringState
                WHEN 1 THEN
                    mAttrValuLong := 'Открыто все - ВЗ,МГ,МН';
                WHEN 2 THEN
                    mAttrValuLong := 'Закрыта МН связь';
                WHEN 3 THEN
                    mAttrValuLong := 'Закрыты выходы на МГ,МН связь';
                WHEN 10 THEN
                    mAttrValuLong := 'Закрыто все - ВЗ,МГ,МН';
                ELSE
                    mAttrValuLong := '';
            END CASE;
            irbis_is_core.update_paper_attr(mDeclar_ID, 'CALLBARRINGSTATE', mAttrValue, mAttrValuLong);
            mAttrValue := TO_CHAR(PhoneCategory);
            mAttrValuLong := irbis_utl.getIrbisPhoneCategoryName(PhoneCategory);
            irbis_is_core.update_paper_attr(mDeclar_ID, 'PHONECATEGORY', mAttrValue, mAttrValuLong);

            -- Привязка абонемента, техкарты к заявлению
            UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = TK_ID
            WHERE id = mContent_ID;
            -- Привязка ID заявки Ирбис к заявлению
            irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
            -- Направление заявления в нужный отдел
            mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
            irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
            irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

            -- СОЗДАНИЕ ТЕХСПРАВКИ
            irbis_is_core.create_tc_by_request(mTS_ID,
                                                mChildSubtype,
                                                mDeclar_ID,
                                                mSubtype_ID,
                                                RequestID,
                                                mOtdel_ID,
                                                mAbonOtdelID,
                                                0);
            -- Обновление ссылки на абонемент IRBIS в ТК
            IF (mAbonementID IS NOT NULL) THEN
                SELECT usl_id INTO mOldAbonementID FROM rm_tk_usl
                WHERE usl_tk = TK_ID;
                RM_TK_PKG.ChangeServiceData (xTK_ID      => TK_ID,
                                                xExt_ID     => 0,
                                                xNewSvc_ID  => mAbonementID,
                                                xOldSvc_ID  => mOldAbonementID,
                                                xNewSvcCode => 'IRBIS',
                                                xNewSvcName => 'Абонемент IRBiS');
            END IF;
            irbis_is_core.update_paper_attr(mTS_ID, 'DOC_COMMENT', 'тел. 8'||PhoneNumber||'. Переключение абонентов всей АТС', 'тел. 8'||PhoneNumber||'. Переключение абонентов всей АТС');
            mRMDocID := RM_DOC.PaperToRMDocument(mDeclar_ID);
            -- Проверка портов FXS
            mPortID := NULL;
            OPEN cGetFXSPort(EquipmentNumber);
            FETCH cGetFXSPort INTO mPortID, mNewEquipID;
            CLOSE cGetFXSPort;
            irbis_utl.assertNotNull(mPortID, '<*-M2000: У оборудования с серийным номером ' || EquipmentNumber
                                      || ' нет свободных портов FXS!-*>');

            -- Проверка, что другие порты оборудования принадлежат данному л/с
            FOR mNewEquip IN GetInfoUsedPorts(mNewEquipID) LOOP
                -- поиск идентификатора адреса для занятого порта нового оборудования
                SELECT NVL((SELECT adr_id FROM rm_tk_address WHERE adr_tk = mNewEquip.tk_id), NULL) INTO mAddress_otherTK FROM dual;
                IF (mAddress_otherTK IS NOT NULL) AND (mAddress_ID IS NOT NULL) AND (mAddress_otherTK != mAddress_ID) THEN
                    SELECT account_id INTO mAbonent2_ID FROM billing.tcontractcommon@irbis cc, rm_tk_usl us
                    WHERE us.usl_tk = mNewEquip.tk_id AND us.usl_id = cc.object_no;
                    SELECT account_numb INTO mAbonent2_numb FROM billing.TAccount@irbis WHERE object_no = mAbonent2_ID;
                    SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) ||
                                    '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                                FROM  rm_tk t WHERE t.tk_id = mNewEquip.tk_id), NULL) INTO mTK_info FROM dual;
                    RAISE_APPLICATION_ERROR(-20001, 'Оборудование с серийным номером ' || EquipmentNumber
                        || ' используется по другому адресу, на лицевом счете (' ||mAbonent2_numb||') в ТК '||mTK_info);
                END IF;
            END LOOP;
            -- Бронирование порта
            mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID    => TK_ID,
                                                         xClass_ID => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                         xRes_ID   => mPortID,
                                                         xPos      => 1,
                                                         xDoc_ID   => mRMDocID,
                                                         xUser_ID  => irbis_user_id);
            IF (mTD_ID IS NULL) THEN NULL; END IF;
            -- Добавление в ТК оборудование
            AddCPEtoTK(TK_ID, mNewEquipID, NULL, mRMDocID);

            -- Сохранение созданной техкарты в документе - заявлении
            irbis_is_core.attach_tk_to_paper(TK_ID, mDeclar_ID);
            -- Сохранение созданной техкарты в документе - техсправке
            irbis_is_core.attach_tk_to_paper(TK_ID, mTS_ID);
            -- Направление ТС в нужный отдел
            irbis_utl.sendPaperNextDepartment(mTS_ID);
        END IF;
    END ChangeOnSIPVOIP;

    -- Создание наряда на переключние телефонии на SIP VOIP
    PROCEDURE ChangeOrderOnSIPVOIP
    (
        RequestID        IN NUMBER,   -- идентификатор заявки в IRBiS
        EquipmentNumber  IN VARCHAR2, -- серийный номер оборудования
        MainParam        IN VARCHAR2  -- набор XML-данных, содержащий универсальные параметры
    ) IS

        CURSOR cGetParentPaper(cRequestID  NUMBER) IS
        SELECT p.id, p.telzone_id, p.department_id, p.subtype_id
        FROM ad_papers p, irbis_request_papers r
        WHERE r.request_id = cRequestID
            AND r.paper_id = p.id
            AND p.parent_id IS NULL;
        mParent_ID     ad_papers.id%TYPE;
        mParentSubtype ad_subtypes.id%TYPE;
        mTelzone_ID    ad_papers.telzone_id%TYPE;
        mOtdel_ID      ad_papers.department_id%TYPE;
        mAbonOtdelID   ad_papers.department_id%TYPE;
        mChildSubtype  ad_subtypes.id%TYPE;
        mOrder_ID      ad_papers.id%TYPE;

        mProc          irbis_subtypes.proc%TYPE;
        mTK_ID           rm_tk.tk_id%TYPE;      -- id созданной техкарты
        mTK_type         rm_tk.tk_type%TYPE;    -- тип техкарты (зависит от устанавливаемой услуги)
        mMarketingCategory VARCHAR2(50);
        mPriority        NUMBER;
        mPriorityLong    VARCHAR2(200);
        mActivationDate  DATE;
        mSourceOfSales   VARCHAR2(300);
        mOperatorName  VARCHAR2(200);
        mContactPhone  VARCHAR2(200);

        mTK_status     rm_tk.tk_status_id%TYPE;      -- состояние техкарты
        mTariffPlanName VARCHAR2(200);

    BEGIN
        irbis_is_core.write_irbis_activity_log('ChangeOrderOnSIPVOIP',
                                'RequestID="' || TO_CHAR(RequestID) ||
                                '", EquipmentNumber="' || TO_CHAR(EquipmentNumber) ||
                                '"',
                                RequestID,
                                MainParam);
        rm_security.setuser(IRBIS_USER_ID); m2_common.appuser_id := IRBIS_USER_ID;

        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                 XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE'))
        LOOP
            CASE x.param_name
                WHEN 'MarketingCategory'  THEN mMarketingCategory := x.value;
                WHEN 'Priority'           THEN mPriority        := TO_NUMBER(x.value);
                WHEN 'RequestCreator'     THEN mOperatorName    := x.value;
                WHEN 'ClientPhones'       THEN mContactPhone    := x.value;
                WHEN 'ActivationDate'     THEN mActivationDate  := TO_DATE(x.value, 'DD.MM.YYYY HH24:MI:SS');
                WHEN 'SourceOfSales'      THEN mSourceOfSales   := x.value;
                WHEN 'TariffPlanName'     THEN mTariffPlanName := x.VALUE;
                ELSE NULL;
            END CASE;
        END LOOP;

        mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

        OPEN cGetParentPaper(RequestID);
        FETCH cGetParentPaper INTO mParent_ID, mTelzone_ID, mAbonOtdelID, mParentSubtype;
        CLOSE cGetParentPaper;
        IF (mParent_ID IS NULL) OR (mTelzone_ID IS NULL) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Невозможно найти Заявление!');
        END IF;

        irbis_utl.assertTrue(((mParent_ID IS NOT NULL) AND (mTelzone_ID IS NOT NULL)), 'Невозможно найти Заявление!');
        mProc  := 37;
        mTK_type := 202;
        mTK_ID := irbis_utl.getTKByPaper(mParent_ID);

        -- Необязательная проверка состояния ТК
        SELECT tk_status_id INTO mTK_status FROM rm_tk WHERE tk_id = mTK_ID;
        irbis_utl.assertTrue((mTK_status IS NOT NULL) AND (mTK_status != 0), 'Указанная техническая карта уже не действует!');

        mChildSubtype := irbis_utl.defineSubtype('BP="' || TO_CHAR(mProc) || '";' ||
                                                 'OBJECT="O";' ||
                                                 'TKTYPE="' || TO_CHAR(mTK_type) || '";' ||
                                                 '"');
        irbis_utl.assertTrue((mChildSubtype IS NOT NULL), 'Не определен вид наряда');

        -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ -------------------------------
        irbis_is_core.create_tc_by_request(mOrder_ID,
                            mChildSubtype,
                            mParent_ID,
                            mParentSubtype,
                            RequestID,
                            mOtdel_ID,
                            mAbonOtdelID,
                            0,
                            MainParam);

        irbis_is_core.update_paper_attr(mOrder_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
        irbis_is_core.update_paper_attr(mOrder_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
        irbis_is_core.update_paper_attr(mOrder_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DATE_ACTIV', TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(mActivationDate, 'DD.MM.YYYY HH24:MI:SS'));
        irbis_is_core.update_paper_attr(mOrder_ID, 'SOURCE_SALE', mSourceOfSales, mSourceOfSales);
        irbis_is_core.update_paper_attr(mOrder_ID, 'NEW_EQUIP', TO_CHAR(EquipmentNumber), EquipmentNumber);
        irbis_is_core.update_paper_attr(mOrder_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', 'тел. 8'||mContactPhone||'. Переключение абонентов всей АТС', 'тел. 8'||mContactPhone||'. Переключение абонентов всей АТС');

        irbis_utl.sendPaperNextDepartment(mOrder_ID);
        /*
        -- Отправка данных на платформу PMP
        IF EquipmentNumber IS NOT NULL THEN
            pmp_is.installSip(mOrder_ID);
        END IF;
        */
    END ChangeOrderOnSIPVOIP;

    -- Транслит адреса установки
    FUNCTION GetTranslit(fValue IN VARCHAR2) RETURN VARCHAR2 IS
        val VARCHAR2(32000) := fValue;
        fValueUpper BOOLEAN := FALSE;
    BEGIN
        IF UPPER(fValue) = fValue THEN
            fValueUpper := TRUE;
        END IF;
        val := TRANSLATE(val, 'АБВГДЕЗИЙКЛМНОПРСТУФХЫЪЬЭ', 'ABVGDEZIYKLMNOPRSTUFHY''''E');
        val := REPLACE(val, 'Ж', 'ZH');
        val := REPLACE(val, 'Ё', 'YO');
        val := REPLACE(val, 'Ц', 'TS');
        val := REPLACE(val, 'Ч', 'CH');
        val := REPLACE(val, 'Ш', 'SH');
        val := REPLACE(val, 'Щ', 'SCH');
        val := REPLACE(val, 'Ю', 'YU');
        val := REPLACE(val, 'Я', 'YA');
        IF fValueUpper THEN
            val := UPPER(val);
        END IF;
        val := TRANSLATE(val, 'абвгдезийклмнопрстуфхыъьэ', 'abvgdeziyklmnoprstufhy''''e');
        val := REPLACE(val, 'ж', 'zh');
        val := REPLACE(val, 'ё', 'yo');
        val := REPLACE(val, 'ц', 'ts');
        val := REPLACE(val, 'ч', 'ch');
        val := REPLACE(val, 'ш', 'sh');
        val := REPLACE(val, 'щ', 'sch');
        val := REPLACE(val, 'ю', 'yu');
        val := REPLACE(val, 'я', 'ya');
        RETURN val;
    END;

    -- Процедура логирования команд на OLT
    PROCEDURE Write_Activity_OLT_log
    (
        pOperation      VARCHAR2,
        pMetod          VARCHAR2,
        pRespCode       VARCHAR2,
        pRequest        VARCHAR2,
        pCommand        VARCHAR2,
        pPesponse_XML   CLOB,
        pPaper_id       NUMBER
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO log_activity_olt(log_id, log_date, operation, metod, resp_code, request, command, response_xml, paper_id)
        VALUES(log_activity_olt_seq.NEXTVAL, SYSDATE, pOperation, pMetod, pRespCode, pRequest, pCommand, pPesponse_XML, pPaper_id);
        COMMIT;
    END;

    -- Вкл/приостановление услуг на OLT
    PROCEDURE ChangeSettingOLT
    (
        pPaperID        IN NUMBER,
        pAction         IN NUMBER,      -- 0-приостановление; 1-включение;
        pService        IN VARCHAR2,
        pOLT_IP         IN VARCHAR2,
        pModul          IN VARCHAR2,
        pVirtPort       IN VARCHAR2,
        pResponseText   OUT CLOB,
        pMessage        OUT VARCHAR2,
        pCode           OUT VARCHAR2
    ) IS
        CURSOR cGetParameters IS
            SELECT curl_host, curl_content_type FROM curl_parameters
            WHERE curl_id = 1;

        mURL            VARCHAR2(50);
        mRequest        UTL_HTTP.req;
        mResponse       UTL_HTTP.resp;
        mContentType    VARCHAR2(150);
        mCommand        VARCHAR2(100);
        mMetod          VARCHAR2(15);
        mOperation      CONSTANT VARCHAR2(50) := 'IRBIS_IS.ChangeSettingOLT';

    BEGIN
        pMessage := '-1';
        pCode := NULL;

        OPEN cGetParameters;
        FETCH cGetParameters INTO mURL, mContentType;
        IF cGetParameters%NOTFOUND THEN
            CLOSE cGetParameters;
            RAISE_APPLICATION_ERROR(-20010, 'Ошибка при вкл/приост. услуг на OLT! Не найден хост в m_ttk.curl_parameters');
        END IF;
        CLOSE cGetParameters;

        IF pAction = 0 THEN
            mMetod := 'DELETE';
        ELSIF pAction = 1 THEN
            mMetod := 'POST';
        END IF;

        mCommand := '{ "service": "'||pService||'", "response": "xml" }';
        -- Логирование запроса
        IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod, NULL, mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mCommand, NULL, pPaperID);
        -- Запрос
        mRequest := UTL_HTTP.begin_request(mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mMetod);
        UTL_HTTP.set_header(mRequest, 'Content-Type', mContentType);
        UTL_HTTP.set_header(mRequest, 'Content-Length', TO_CHAR(LENGTH(mCommand)));
        UTL_HTTP.write_text(mRequest, mCommand);
        mResponse := UTL_HTTP.get_response(mRequest);
        UTL_HTTP.read_text(mResponse, pResponseText);
        pCode := mResponse.status_code;
        UTL_HTTP.end_response(mResponse);
        -- Логирование ответа
        IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod||'-ответ', pCode, mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mCommand, pResponseText, pPaperID);
        SELECT result INTO pMessage FROM XMLTABLE('root' PASSING XMLTYPE(pResponseText) COLUMNS result VARCHAR2(30) PATH 'result');

    EXCEPTION
        WHEN UTL_HTTP.end_of_body OR UTL_HTTP.too_many_requests THEN
            UTL_HTTP.end_response(mResponse);
            RAISE_APPLICATION_ERROR(-20011, 'Ошибка при вкл/приост. услуг на OLT! '||SQLERRM);

        WHEN UTL_HTTP.request_failed THEN
            RAISE_APPLICATION_ERROR(-20012, 'Ошибка при вкл/приост. услуг на OLT! '||SQLERRM);

        WHEN OTHERS THEN
            IF pCode IS NOT NULL THEN
                UTL_HTTP.end_response(mResponse);
            END IF;
            RAISE_APPLICATION_ERROR(-20013, 'Ошибка при вкл/приост. услуг на OLT! '||SQLERRM);
    END;

    -- Снятие услуги с OLT
    PROCEDURE DeleteSettingOLT
    (
        pPaperID        IN NUMBER,
        pOLT_IP         IN VARCHAR2,
        pModul          IN VARCHAR2,
        pVirtPort       IN VARCHAR2,
        pResponseText   OUT CLOB,
        pMessage        OUT VARCHAR2,
        pCode           OUT VARCHAR2
    ) IS

        CURSOR cGetParameters IS
            SELECT curl_host, curl_content_type FROM curl_parameters
            WHERE curl_id = 1;

        CURSOR cGetPort (cIP IN VARCHAR2, cModul IN VARCHAR2, cVirtPort IN VARCHAR2) IS
            SELECT p.prt_id
            FROM rm_res_prop_value res, rm_equip_unit un, rm_equip_port p
            WHERE res.rvl_value = cIP
                AND res.rvl_res = un.un_equip
                AND un.un_id = p.prt_unit
                AND un.un_number = cModul
                AND TO_NUMBER(REGEXP_REPLACE(p.prt_name, '[^[[:digit:]]]*')) = TO_NUMBER(cVirtPort);

        mURL            VARCHAR2(50);
        mRequest        UTL_HTTP.req;
        mResponse       UTL_HTTP.resp;
        mContentType    VARCHAR2(150);
        mCommand        CONSTANT VARCHAR2(100) := '{ "response": "xml" }';
        mMetod          CONSTANT VARCHAR2(15) := 'DELETE';
        mOperation      CONSTANT VARCHAR2(50) := 'IRBIS_IS.DeleteSettingOLT';
        mPortID         rm_equip_port.prt_id%TYPE;

    BEGIN
        pMessage := '-1';
        pCode := NULL;

        OPEN cGetParameters;
        FETCH cGetParameters INTO mURL, mContentType;
        IF cGetParameters%NOTFOUND THEN
            CLOSE cGetParameters;
            RAISE_APPLICATION_ERROR(-20010, 'Ошибка при снятии с OLT! Не найден хост в m_ttk.curl_parameters');
        END IF;
        CLOSE cGetParameters;

        -- Логирование запроса
        IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod, NULL, mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mCommand, NULL, pPaperID);
        -- Запрос
        mRequest := UTL_HTTP.begin_request(mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mMetod);
        UTL_HTTP.set_header(mRequest, 'Content-Type', mContentType);
        UTL_HTTP.set_header(mRequest, 'Content-Length', TO_CHAR(LENGTH(mCommand)));
        UTL_HTTP.write_text(mRequest, mCommand);
        mResponse := UTL_HTTP.get_response(mRequest);
        UTL_HTTP.read_text(mResponse, pResponseText);
        pCode := mResponse.status_code;
        UTL_HTTP.end_response(mResponse);
        -- Логирование ответа
        IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod||'-ответ', pCode, mURL||pOLT_IP||'/'||pModul||'/'||pVirtPort||'/', mCommand, pResponseText, pPaperID);
        SELECT result INTO pMessage FROM XMLTABLE('root' PASSING XMLTYPE(pResponseText) COLUMNS result VARCHAR2(30) PATH 'result');
        --Если удаление настроек успешно
        IF lower(pMessage) = 'ok' THEN
            --Поиск порта коммутатора GPON
            OPEN cGetPort(pOLT_IP, pModul, pVirtPort);
            FETCH cGetPort INTO mPortID;
            IF cGetPort%NOTFOUND THEN
                mPortID := NULL;
            END IF;
            CLOSE cGetPort;
            --Если порт коммутатора GPON найден
            IF mPortID IS NOT NULL THEN
                --Удаление порта из всех ТК
                RM_GESW.Delete_Resource_from_TKData(xID => mPortID, xClassID => 2);
            END IF;
        END IF;

    EXCEPTION
        WHEN UTL_HTTP.end_of_body OR UTL_HTTP.too_many_requests THEN
            UTL_HTTP.end_response(mResponse);
            RAISE_APPLICATION_ERROR(-20011, 'Ошибка при снятии с OLT! '||SQLERRM);

        WHEN UTL_HTTP.request_failed THEN
            RAISE_APPLICATION_ERROR(-20012, 'Ошибка при снятии с OLT! '||SQLERRM);

        WHEN OTHERS THEN
            IF pCode IS NOT NULL THEN
                UTL_HTTP.end_response(mResponse);
            END IF;
            RAISE_APPLICATION_ERROR(-20013, 'Ошибка при снятии с OLT! '||SQLERRM);
    END;

    -- Настройка клиентского оборудования на OLT
    PROCEDURE ConnectionSettingOLT
    (
        pPaperID        IN NUMBER,  -- ID наряда
        pEquipNumber    IN VARCHAR2 DEFAULT NULL -- серийный номер клиентского оборудования
    ) IS
        CURSOR cGetParameters IS
            SELECT curl_host, curl_content_type FROM curl_parameters
            WHERE curl_id = 2;
        CURSOR cGetInfo IS
            SELECT ape.address_id, p.department_id, ape.tk_id FROM ad_papers p
            JOIN ad_paper_extended ape  ON p.id = ape.paper_id
            WHERE p.id = pPaperID;
        -- Все ТК
        CURSOR cGetAllTK(cTK_ID IN NUMBER) IS
            SELECT DISTINCT rm.tk_id FROM rm_tk_data rmc
            JOIN rm_tk_data rml ON rmc.tkd_resource = rml.tkd_resource AND rml.tkd_is_new_res <> 2
            JOIN rm_tk rm       ON rml.tkd_tk = rm.tk_id AND rm.tk_status_id <> 0
            WHERE rmc.tkd_tk = cTK_ID
                AND NOT EXISTS (SELECT * FROM rm_tk_data WHERE rmc.tkd_id = tkd_parent_id)
                AND rmc.tkd_res_class IN (2)
                AND rmc.tkd_is_new_res <> 2;
        -- Связанные ТК
        CURSOR cGetLinkTK(cTK_ID IN NUMBER) IS
            SELECT DISTINCT rm.tk_id FROM rm_tk_data rmc
            JOIN rm_tk_data rml     ON rmc.tkd_resource = rml.tkd_resource AND rmc.tkd_res_class = rml.tkd_res_class
            JOIN rm_tk rm           ON rml.tkd_tk = rm.tk_id AND rm.tk_status_id <> 0 AND rm.tk_id <> cTK_ID AND rm.tk_type NOT IN (1,82)
            WHERE rmc.tkd_tk = cTK_ID
                AND rmc.tkd_res_class IN (2, 7)
                AND rmc.tkd_is_new_res <> 2;
        -- Поиск клиентского оборудования на действующей ТК
        CURSOR cGetEquipOld(cTK_ID NUMBER) IS
            SELECT eq.equ_id, val.rvl_value FROM rm_tk_data rmd
            JOIN rm_res_prop_value val  ON rmd.tkd_resource = val.rvl_res AND val.rvl_prop_id = 3362    -- берем SN
            JOIN rm_equipment eq        ON rmd.tkd_resource = eq.equ_id AND eq.equ_type = 4294          -- Абонентский терминал CPON
            WHERE rmd.tkd_tk = cTK_ID
                AND rmd.tkd_res_class = 1
                AND rmd.tkd_is_new_res = 0;
        -- Поиск порта и IP OLT на действующей ТК
        CURSOR cGetPortOld(cTK_ID NUMBER) IS
            SELECT prt.prt_id, res.rvl_value,
                un.un_number modul,
                REGEXP_REPLACE(prt.prt_name, '[^[[:digit:]]]*') ont
            FROM rm_tk_data rmd
            JOIN rm_equip_port prt      ON rmd.tkd_resource = prt.prt_id
            JOIN rm_equip_unit un       ON prt.prt_unit = un.un_id
            JOIN rm_equipment equ       ON un.un_equip = equ.equ_id AND equ.equ_type = 1003     -- Коммутатор GPON
            JOIN rm_res_prop_value res  ON equ.equ_id = res.rvl_res AND res.rvl_prop_id = 1971  -- IP адрес OLT
            WHERE rmd.tkd_tk = cTK_ID
                AND rmd.tkd_res_class = 2
                AND rmd.tkd_is_new_res = 0;
        -- Поиск порта при первичке
        CURSOR cGetPort (cIP IN VARCHAR2, cModul IN VARCHAR2, cVirtPort IN VARCHAR2) IS
            SELECT p.prt_id
            FROM rm_res_prop_value res, rm_equip_unit un, rm_equip_port p
            WHERE res.rvl_value = cIP
                AND res.rvl_res = un.un_equip
                AND un.un_id = p.prt_unit
                AND un.un_number = cModul
                AND TO_NUMBER(REGEXP_REPLACE(p.prt_name, '[^[[:digit:]]]*')) = TO_NUMBER(cVirtPort);
        -- Поиск оборудования при первичке
        CURSOR cGetEquipID(cSN IN VARCHAR2) IS
            SELECT rvl_res FROM rm_res_prop_value
                WHERE rvl_value = cSN;
        -- Проверка занятости порта
        CURSOR cCheckStatePort(cPortID IN NUMBER) IS
            SELECT tkd.tkd_tk FROM rm_tk_data tkd, rm_tk tk
            WHERE tkd.tkd_tk = tk.tk_id
                AND tk.tk_status_id <> 0
                AND tkd.tkd_resource = cPortID
                AND ROWNUM = 1;

        mURL                VARCHAR2(200);
        mContentType        VARCHAR2(100);
        mRequest            UTL_HTTP.req;
        mResponse           UTL_HTTP.resp;
        mCommand            VARCHAR(300);
        mMetod              CONSTANT VARCHAR2(15) := 'POST';
        mOperation          CONSTANT VARCHAR2(50) := 'IRBIS_IS.ConnectionSettingOLT';
        mService            VARCHAR(25);
        mResponseText       CLOB;
        mResponseTextChange CLOB;
        mResponseTextDel    CLOB;
        mCode               VARCHAR2(10) := NULL;   -- Код состояния HTTP
        mMessage            VARCHAR(290);           -- Текст результата
        mIP                 VARCHAR2(100) := '-1';
        mModul              VARCHAR2(100);
        mVirtPort           VARCHAR2(100);
        mSN                 VARCHAR2(100) := '-1';
        mResult             VARCHAR2(900);
        mResultDopReq       VARCHAR2(900);
        mRxONT              VARCHAR2(25);
        mRxOLT              VARCHAR2(25);
        mRxCatv             VARCHAR2(25);
        mAddress            VARCHAR(300);
        mShortAddress       VARCHAR(300);
        mAddressTrans       VARCHAR(300);
        mAddressID          NUMBER;
        mDepartmentID       NUMBER;
        mTK_ID              NUMBER;
        mCount_TK           NUMBER := 0;
        mCount_W            NUMBER := 0;
        mCount_i            NUMBER := 0;
        mCount_err_SN       NUMBER := 0;
        mCount_err_host     NUMBER := 0;
        mPortID             NUMBER := NULL;
        mPortInTK           NUMBER;
        mEquipID            NUMBER;
        mType_Usl           VARCHAR2(5);
        mLowSignal          VARCHAR2(100) := '';
        mRMDocID            NUMBER;
        mEquipOld           NUMBER := -1;           -- ID оборудования из связанной ТК
        mSNOld              VARCHAR2(50);           -- серийный номер из связанной ТК
        mPortOldID          NUMBER := -1;           -- ID порта из связанной ТК
        mOLTOldIP           VARCHAR2(25);           -- IP OLT из связанной ТК
        mOldF               VARCHAR2(25) := '0';    -- в логике не участвует, всегда 0
        mModulOld           VARCHAR2(25);           -- модуль OLT из связанной ТК
        mPortOld            VARCHAR2(25);           -- порт OLT из связанной ТК
        mVirtPortOld        VARCHAR2(25);           -- вирт. порт из связанной ТК
        mTD_ID              NUMBER;
        mHis                NUMBER;
        m2000UserId         NUMBER := 2400;
        mState              VARCHAR(50) := NULL;
        mStatus             VARCHAR(25);
        mErrorText          VARCHAR2(300);          -- нужен чтобы обрезать для вставки в таблицу
        mCountOVN           NUMBER;
        mSubtypeID          NUMBER;

    BEGIN
        OPEN cGetInfo;
        FETCH cGetInfo INTO mAddressID, mDepartmentID, mTK_ID;
        IF mAddressID IS NULL OR mTK_ID IS NULL THEN
            CLOSE cGetInfo;
            -- Проставление резолюции об ошибке
            mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                    -- Элемент
                                                    xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                    xResol_ID => 1822,
                                                    xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                    -- Прохождение
                                                    xOldDept_ID => mDepartmentID,
                                                    xNewDept_ID => mDepartmentID,
                                                    -- Дополнительно
                                                    xUser_ID => m2000UserId,
                                                    xNotice => 'Не найден адрес подключения или техкарта');
            RETURN;
        END IF;
        CLOSE cGetInfo;

        OPEN cGetParameters;
        FETCH cGetParameters INTO mURL, mContentType;
        IF cGetParameters%NOTFOUND THEN
            CLOSE cGetParameters;
            -- Проставление резолюции об ошибке
            mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                    -- Элемент
                                                    xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                    xResol_ID => 1822,
                                                    xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                    -- Прохождение
                                                    xOldDept_ID => mDepartmentID,
                                                    xNewDept_ID => mDepartmentID,
                                                    -- Дополнительно
                                                    xUser_ID => m2000UserId,
                                                    xNotice => 'Не найден хост в m_ttk.curl_parameters');
            RETURN;
        END IF;
        CLOSE cGetParameters;

        SELECT subtype_id INTO mSubtypeID FROM ad_papers WHERE id = pPaperID;

        FOR tk IN cGetAllTK(mTK_ID) LOOP
            mCount_TK := mCount_TK + 1;
            SELECT
                CASE p.state_id
                    WHEN 'W' THEN 'W'
                    ELSE 'O'
                END status,
                CASE ape.usl_type_id
                    WHEN 23  THEN 'p'    -- СПД
                    WHEN 24  THEN 's'    -- Телефония (SIP)
                    WHEN 61  THEN 'i'    -- IPTV
                    WHEN 81  THEN 'c'    -- КТВ
                    WHEN 241 THEN 'pv'   -- Если нашелся ОВН, значит есть и СПД
                    ELSE '-1'
                END Type_Usl
                INTO mStatus, mType_Usl
            FROM ad_paper_extended ape
            JOIN ad_papers p ON ape.paper_id = p.id AND p.id = (SELECT MAX(paper_id) FROM ad_paper_extended WHERE tk_id = tk.tk_id);

            --Если нашелся наряд по услуге СПД
            IF mType_Usl = 'p' THEN
                --Проверка на существование активной услуги ОВН
                SELECT COUNT(1)
                INTO mCountOVN
                FROM ad_papers p
                JOIN ad_paper_extended e ON p.id = e.paper_id
                WHERE p.subtype_id = 11926  --наряд на установку ОВН
                AND e.tk_id = tk.tk_id
                AND NOT EXISTS (SELECT 1
                                FROM ad_papers pa
                                JOIN ad_paper_extended ext ON pa.id = ext.paper_id
                                WHERE pa.subtype_id = 12006 --наряд на снятие ОВН
                                AND ext.tk_id = tk.tk_id);

                --Если есть активная услуга ОВН
                IF mCountOVN > 0 THEN
                    --Добавление литера услуг ОВН
                    mType_Usl := 'pv';
                END IF;
            END IF;

            IF mStatus = 'W' OR mSubtypeID = 11926 THEN
                mCount_W := mCount_W + 1;
                mService := mService||mType_Usl;
            -- Если услуга уже предоставляется, то берем оборудование и данные порта из этой ТК
            ELSE
                IF mEquipOld = -1 THEN
                    OPEN cGetEquipOld(tk.tk_id);
                    FETCH cGetEquipOld INTO mEquipOld, mSNOld;
                    IF cGetEquipOld%NOTFOUND THEN
                        mEquipOld := -1;
                    END IF;
                    CLOSE cGetEquipOld;
                END IF;
                IF mPortOldID = -1 THEN
                    OPEN cGetPortOld(tk.tk_id);
                    FETCH cGetPortOld INTO mPortOldID, mOLTOldIP, mModulOld, mVirtPortOld;
                    IF cGetPortOld%NOTFOUND THEN
                        mPortOldID := -1;
                    END IF;
                    CLOSE cGetPortOld;
                END IF;
            END IF;
        END LOOP;

        -- Если все подключения новые
        IF mCount_TK = mCount_W THEN
            -- Получение полного названия адреса установки
            mAddress := AO_ADR.get_addresst(mAddressID);
            -- Оставляем только улицу и дом
            SELECT SUBSTR(mAddress, INSTR(mAddress, 'ул.') + 4) INTO mShortAddress FROM dual;
            -- Транслит адреса установки
            mAddressTrans := REPLACE(IRBIS_IS.GetTranslit(mShortAddress), '''', '');
            mCommand := '{ "sn": "'||pEquipNumber||'", "description": "'||mAddressTrans||'", "service": "'||mService||'", "response": "xml" }';
            -- Логирование запроса
            IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod, NULL, mURL, mCommand, NULL, pPaperID);
            -- Запрос
            mRequest := UTL_HTTP.begin_request(URL => mURL, method => mMetod);
            UTL_HTTP.set_header(mRequest, 'Content-Type', mContentType);
            UTL_HTTP.set_header(mRequest, 'Content-Length', TO_CHAR(LENGTH(mCommand)));
            -- Передача параметров
            UTL_HTTP.write_text(mRequest, mCommand);
            -- Ответ
            mResponse := UTL_HTTP.get_response(mRequest);
            UTL_HTTP.read_text(mResponse, mResponseText);
            mCode := mResponse.status_code;
            -- Обязательно закрываем
            UTL_HTTP.end_response(mResponse);
            -- Логирование ответа
            IRBIS_IS.Write_Activity_OLT_log(mOperation, mMetod||'-ответ', mCode, mURL, mCommand, mResponseText, pPaperID);
            -- Разбор XML
            FOR i IN (SELECT ip, f, s, p, sn, descr, newIndex, newOntId, vlanPPPoE, rxOnt, rxOlt, rxCatv, result, ont_found
                      FROM XMLTABLE('root/item' PASSING XMLTYPE(mResponseText)
                      COLUMNS   ip VARCHAR2(30)         PATH 'ip',
                                f VARCHAR2(10)          PATH 'f',
                                s VARCHAR2(10)          PATH 's',
                                p VARCHAR2(10)          PATH 'p',
                                sn VARCHAR2(30)         PATH 'sn',
                                descr VARCHAR2(250)     PATH 'descr',
                                newIndex VARCHAR2(30)   PATH 'newIndex',
                                newOntId VARCHAR2(30)   PATH 'newOntId',
                                vlanPPPoE VARCHAR2(30)  PATH 'vlanPPPoE',
                                rxOnt VARCHAR2(30)      PATH 'rxOnt',
                                rxOlt VARCHAR2(30)      PATH 'rxOlt',
                                rxCatv VARCHAR2(30)     PATH 'rxCatv',
                                result VARCHAR2(250)    PATH 'result',
                                ont_found VARCHAR2(30)  PATH 'ont_found'))
            LOOP
                dbms_output.put_line('Разбор XML');
                mCount_i := mCount_i + 1;
                IF LOWER(i.result) IN ('ok', 'optical power is too low') THEN
                    mIP := i.ip;
                    mModul := i.f||'/'||i.s||'/'||i.p;
                    mVirtPort := i.newOntId;
                    mSN := i.sn;
                    mRxONT:= i.rxOnt;
                    mRxOLT:= i.rxOlt;
                    mRxCatv:= i.rxCatv;
                    mResult := i.result;
                ELSIF LOWER(i.result) IN ('failure', 'failure while setting up', 'vlans not found', ' there is not free service index',  'not all vlans found') THEN
                    mIP := i.ip;
                    mModul := i.f||'/'||i.s||'/'||i.p;
                    mVirtPort := i.newOntId;
                    mSN := i.sn;
                    mResult := i.result;
                    -- Проставление резолюции об ошибке
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1822,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Ошибка. Ответ с OLT: '||i.result);
                    -- Запрос на удаление оборудования
                    IRBIS_IS.DeleteSettingOLT(pPaperID, mIP, mModul, mVirtPort, mResponseTextDel, mMessage, mCode);
                ELSIF LOWER(i.result) IN ('ont not found', 'no compatible ont', 'there is not free ontid') THEN
                    mResult := i.result;
                    -- Проставление резолюции об ошибке
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1822,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Ошибка. Ответ с OLT: '||i.result);
                ELSIF LOWER(i.result) = ('current sn not found') THEN
                    mCount_err_SN := mCount_err_SN + 1;
                ELSIF LOWER(i.result) = ('could not login to host') THEN
                    mCount_err_host := mCount_err_host + 1;
                END IF;
            END LOOP;
            -- Успешный ответ
            IF LOWER(mResult) IN ('ok', 'optical power is too low') THEN
                dbms_output.put_line('Успешный ответ');
                IF LOWER(mResult) = 'optical power is too low' THEN
                    mLowSignal := 'Слабый сигнал.'; -- Уровень слабого сигнала
                END IF;
                -- Проверка оборудования
                OPEN cGetEquipID(mSN);
                FETCH cGetEquipID INTO mEquipID;
                IF cGetEquipID%NOTFOUND THEN
                    -- Проставление резолюции об ошибке
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1822,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'ONT не найдено в тех. учете. (-101)');
                -- Добавление оборудования
                ELSE
                    mRMDocID := RM_DOC.PaperToRMDocument(pPaperID);
                    -- Проверка не занятости оборудования на других ТК с другим адресом
                    SELECT NVL((SELECT (SELECT tt.tkt_name FROM rm_tk_type tt WHERE tt.tkt_id = t.tk_type) || '-' || t.tk_number || ' (id=' || TO_CHAR(t.tk_id) || ')'
                                FROM rm_tk_data d, rm_tk t, rm_tk_address addr
                                WHERE d.tkd_resource = mEquipID
                                    AND d.tkd_res_class = 1
                                    AND d.tkd_tk = t.tk_id
                                    AND t.tk_status_id != 0
                                    AND addr.adr_tk = t.tk_id
                                    AND addr.adr_id != mAddressID
                                    AND rownum < 2), NULL) INTO mState
                    FROM dual;
                    IF mState IS NOT NULL THEN
                        -- Проставление резолюции об ошибке
                        mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                                -- Элемент
                                                                xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                                xResol_ID => 1822,
                                                                xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                                -- Прохождение
                                                                xOldDept_ID => mDepartmentID,
                                                                xNewDept_ID => mDepartmentID,
                                                                -- Дополнительно
                                                                xUser_ID => m2000UserId,
                                                                xNotice => 'Устройство занято по другому адресу, закреплено за ТК '||mState||'. (-102)');
                    -- Добавление оборудования в ТК
                    ELSE
                        -- Добавление в текущую ТК
                        mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK_ID,
                                                                        xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                                        xRes_ID    => mEquipID,
                                                                        xParent_ID => NULL, -- ID старого оборудования (resource_id)
                                                                        xPos       => 1,
                                                                        xDoc_ID    => mRMDocID,
                                                                        xUser_ID   => 2400);
                        IF (mTD_ID IS NULL) THEN NULL; END IF;
                        -- Добавление в связанные ТК (как текущее оборудование, а не добавляемое)
                        FOR t IN cGetLinkTK(mTK_ID)
                        LOOP
                            mTD_ID := RM_TK_PKG.PureRebindResourceOntoData(xTK_ID     => t.tk_id,
                                                                            xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                                            xNewRes_ID    => mEquipID,
                                                                            xOldRes_ID => NULL, -- ID старого оборудования (resource_id)
                                                                            xPos       => 1,
                                                                            xDoc_ID    => mRMDocID,
                                                                            xUser_ID   => 2400,
                                                                            xNotice    => 'Добавление в связанной ТК-'||mTK_ID);
                            IF (mTD_ID IS NULL) THEN NULL; END IF;
                        END LOOP;
                        mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                                -- Элемент
                                                                xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                                xResol_ID => 1742,
                                                                xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                                -- Прохождение
                                                                xOldDept_ID => mDepartmentID,
                                                                xNewDept_ID => mDepartmentID,
                                                                -- Дополнительно
                                                                xUser_ID => m2000UserId,
                                                                xNotice => 'Оборудование забронировано.');
                    END IF;
                END IF;
                CLOSE cGetEquipID;
                -- Поиск порта
                OPEN cGetPort(mIP, mModul, mVirtPort);
                FETCH cGetPort INTO mPortID;
                IF cGetPort%NOTFOUND THEN
                    -- Проставление резолюции об ошибке
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1822,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Не найден порт OLT. (-103)');
                    mPortID := NULL;
                ELSE
                    -- Проверка занятости порта
                    OPEN cCheckStatePort(mPortID);
                    FETCH cCheckStatePort INTO mPortInTK;
                    IF cCheckStatePort%FOUND THEN
                        mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                                -- Элемент
                                                                xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                                xResol_ID => 1822,
                                                                xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                                -- Прохождение
                                                                xOldDept_ID => mDepartmentID,
                                                                xNewDept_ID => mDepartmentID,
                                                                -- Дополнительно
                                                                xUser_ID => m2000UserId,
                                                                xNotice => 'Порт OLT (ID = '||mPortID||') занят в ТК (ID = '||mPortInTK||'). (-104)');
                        mPortID := NULL;
                    END IF;
                    CLOSE cCheckStatePort;
                END IF;
                CLOSE cGetPort;
                -- Бронирование порта
                IF mPortID IS NOT NULL THEN
                    -- Добавление порта в текущую ТК
                    irbis_utl.addBronWithCheck(mTK_ID, mPortID, 2, 'Не удалось найти свободный порт', pPaperID);
                    -- Добавление в связанные ТК (как текущее оборудование, а не добавляемое)
                    FOR t IN cGetLinkTK(mTK_ID)
                    LOOP
                        mTD_ID := RM_TK_PKG.PureRebindResourceOntoData(xTK_ID     => t.tk_id,
                                                                        xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                                        xNewRes_ID => mPortID,
                                                                        xOldRes_ID => NULL, -- ID старого оборудования (resource_id)
                                                                        xPos       => 1,
                                                                        xDoc_ID    => mRMDocID,
                                                                        xUser_ID   => 2400,
                                                                        xNotice    => 'Добавление в связанной ТК-'||mTK_ID);
                        IF (mTD_ID IS NULL) THEN NULL; END IF;
                    END LOOP;
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1742,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Бронирование порта с OLT '||mIP||'. '||mLowSignal||' Сигнал: OLT = '||mRxOLT||'; ONT = '||mRxONT||'; КТВ = '||mRxCatv||'.');
                END IF;

                -- Запись SN в атрибут
                irbis_is_core.update_paper_attr(pPaperID, 'NEW_EQUIP', mSN, mSN);
            -- Все ответы что некорректный серийный номер
            ELSIF mCount_i = mCount_err_SN THEN
                -- Проставление резолюции об ошибке
                mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                        -- Элемент
                                                        xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                        xResol_ID => 1822,
                                                        xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                        -- Прохождение
                                                        xOldDept_ID => mDepartmentID,
                                                        xNewDept_ID => mDepartmentID,
                                                        -- Дополнительно
                                                        xUser_ID => m2000UserId,
                                                        xNotice => 'Некорректный серийный номер клиентского оборудования.');
            -- Не возможно подключиться к OLT или некоректный SN
            ELSIF mCount_i = mCount_err_host + mCount_err_SN THEN
                -- Проставление резолюции об ошибке
                mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                        -- Элемент
                                                        xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                        xResol_ID => 1822,
                                                        xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                        -- Прохождение
                                                        xOldDept_ID => mDepartmentID,
                                                        xNewDept_ID => mDepartmentID,
                                                        -- Дополнительно
                                                        xUser_ID => m2000UserId,
                                                        xNotice => 'Не возможно подключиться к OLT. Возможно некорректный серийный номер клиентского оборудования.');
            -- Не возможно подключиться к OLT
            ELSIF mCount_i = mCount_err_host THEN
                mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                        -- Элемент
                                                        xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                        xResol_ID => 1822,
                                                        xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                        -- Прохождение
                                                        xOldDept_ID => mDepartmentID,
                                                        xNewDept_ID => mDepartmentID,
                                                        -- Дополнительно
                                                        xUser_ID => m2000UserId,
                                                        xNotice => 'Нет возможности подключиться к OLT.');
            END IF;
        -- Если уже есть предоставляемая услуга по ресурсу
        ELSE
            -- Если в связанной ТК не нашли ресурсов для передачи на OLT
            IF mEquipOld = -1 OR mPortOldID = -1 THEN
                mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                        -- Элемент
                                                        xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                        xResol_ID => 1822,
                                                        xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                        -- Прохождение
                                                        xOldDept_ID => mDepartmentID,
                                                        xNewDept_ID => mDepartmentID,
                                                        -- Дополнительно
                                                        xUser_ID => m2000UserId,
                                                        xNotice => 'По адресу предоставляется одна из услуг, но в связанной ТК не найдены порт и ONT для настройки OLT.');
            END IF;
            IF mEquipOld <> -1 AND mPortOldID <> -1 THEN
                -- Запрос на изменение настроек OLT
                IRBIS_IS.ChangeSettingOLT(pPaperID, 1, mService, mOLTOldIP, mModulOld, mVirtPortOld, mResponseTextChange, mMessage, mCode);
                -- Если успешно
                IF LOWER(mMessage) = 'ok' THEN
                    -- Добавление оборудования в текущую ТК (как добавляемый ресурс)
                    mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK_ID,
                                                                    xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP,
                                                                    xRes_ID    => mEquipOld,
                                                                    xParent_ID => NULL, -- ID старого оборудования (resource_id)
                                                                    xPos       => 1,
                                                                    xDoc_ID    => mRMDocID,
                                                                    xUser_ID   => m2000UserId);
                    IF (mTD_ID IS NULL) THEN NULL; END IF;
                    -- Добавление порта в текущую ТК (как добавляемый ресурс)
                    mTD_ID := RM_TK_PKG.LazyEmbindResourceIntoData(xTK_ID     => mTK_ID,
                                                                    xClass_ID  => RM_CONSTS.RM_RES_CLASS_EQUIP_PORT,
                                                                    xRes_ID    => mPortOldID,
                                                                    xParent_ID => NULL, -- ID старого оборудования (resource_id)
                                                                    xPos       => 1,
                                                                    xDoc_ID    => mRMDocID,
                                                                    xUser_ID   => m2000UserId);
                    IF (mTD_ID IS NULL) THEN NULL; END IF;
                    -- Резолюция ою успехе
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1742,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Автоматическая настройка произведена, оборудования и порт добавлены в ТК.');
                    -- Запись SN в атрибут
                    IRBIS_IS_CORE.update_paper_attr(pPaperID, 'NEW_EQUIP', mSNOld, mSNOld);
                -- Если не успешно
                ELSE
                    mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                            -- Элемент
                                                            xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                            xResol_ID => 1822,
                                                            xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                            -- Прохождение
                                                            xOldDept_ID => mDepartmentID,
                                                            xNewDept_ID => mDepartmentID,
                                                            -- Дополнительно
                                                            xUser_ID => m2000UserId,
                                                            xNotice => 'Ошибка: '||mMessage);
                END IF;
            END IF;
        END IF;

    EXCEPTION
        WHEN UTL_HTTP.end_of_body OR UTL_HTTP.too_many_requests THEN
            mErrorText := SQLERRM;
            UTL_HTTP.end_response(mResponse);
            -- Проставление резолюции об ошибке
            mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                    -- Элемент
                                                    xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                    xResol_ID => 1822,
                                                    xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                    -- Прохождение
                                                    xOldDept_ID => mDepartmentID,
                                                    xNewDept_ID => mDepartmentID,
                                                    -- Дополнительно
                                                    xUser_ID => m2000UserId,
                                                    xNotice => mErrorText);

        WHEN UTL_HTTP.request_failed THEN
            mErrorText := SQLERRM;
            -- Проставление резолюции об ошибке
            mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                    -- Элемент
                                                    xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                    xResol_ID => 1822,
                                                    xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                    -- Прохождение
                                                    xOldDept_ID => mDepartmentID,
                                                    xNewDept_ID => mDepartmentID,
                                                    -- Дополнительно
                                                    xUser_ID => m2000UserId,
                                                    xNotice => mErrorText);

        WHEN OTHERS THEN
            mErrorText := SQLERRM;
            IF mCode IS NOT NULL THEN
                UTL_HTTP.end_response(mResponse);
            END IF;
            -- Проставление резолюции об ошибке
            mHis := OM_DOC_PKG.CreateHistoryData(xPaper_ID => pPaperID,
                                                    -- Элемент
                                                    xItemCode => OM_DOC_PKG.AD_HIS_ITEM_ERROR,
                                                    xResol_ID => 1822,
                                                    xNewState_ID => OM_CONSTS.AD_PAPER_STATE_WORKING,
                                                    -- Прохождение
                                                    xOldDept_ID => mDepartmentID,
                                                    xNewDept_ID => mDepartmentID,
                                                    -- Дополнительно
                                                    xUser_ID => m2000UserId,
                                                    xNotice => mErrorText);
            -- Если запрос на настройку был успешным
            IF mIP <> '-1' AND mSN <> '-1' THEN
                -- Запрос на удаление оборудования
                IRBIS_IS.DeleteSettingOLT(pPaperID, mIP, mModul, mVirtPort, mResponseTextDel, mMessage, mCode);
            END IF;
    END;

    -- Создание заявления и наряда для облачного видеонаблюдения
    PROCEDURE CreateCloudVideo
    (
        RequestID       IN NUMBER,      -- ID заявки
        DateMontWish    IN DATE,        -- Желаемая дата прихода специалиста
        TK_ID           IN NUMBER,      -- ID тех.карты
        ConnectionType  IN VARCHAR2,    -- Тип подключения
        RequestComment  IN VARCHAR2,    -- Комментарии из Ирбиса
        MainParam       IN VARCHAR2
    ) IS
        mAddress_ID         ad_paper_content.address_id%TYPE;
        mAddress2_ID        ad_paper_content.address2_id%TYPE;
        mHouseID            NUMBER; -- ID дома
        mApartment          VARCHAR2(200);  -- ID квартиры
        mState              NUMBER;
        mAbonementID        NUMBER; -- идентификатор абонемента
        mContactPhone       VARCHAR2(200);  -- Контактный телефон абонента
        mOperatorName       VARCHAR2(200);  -- ФИО оператора создавшего заявление
        mClientID           NUMBER; -- Идентификатор клиента в IRBiS
        mMarketingCategory  VARCHAR2(50);
        mPriority           NUMBER;
        mPriorityLong       VARCHAR2(200);
        mAbonent_ID         ad_paper_content.abonent_id%TYPE;
        mTariffPlanName     ad_paper_attr.value_long%TYPE;
        mHouseOnly      NUMBER; -- Признак того, что для многоквартирного дома не была указана квартира
        mPrivateHouse   NUMBER; -- Признак того, что дом является частным (без квартир)
        mTelzone_ID     ad_papers.telzone_id%TYPE;
        mAbonOtdelID    ad_papers.department_id%TYPE;   -- ID отдела, в котором должно оказаться заявление после создания
        mOtdel_ID       ad_papers.department_id%TYPE;   -- ID отдела, в котором должен оказаться наряд после создания
        mDeclar_ID      ad_papers.id%TYPE;  -- ID заявления
        mOrder_ID       ad_papers.id%TYPE;  -- ID наряда
        mCategID        NUMBER;
        mSubtype_ID     ad_subtypes.id%TYPE;        -- ID вида заявления
        mChildSubtype   ad_subtypes.id%TYPE;        -- ID вида ТС
        mContent_ID     ad_paper_content.id%TYPE;   -- ID содержания созданного документа
        mProc           NUMBER; -- БП
        mCuslType_ID    ad_paper_content.cusl_type_id%TYPE; -- Тип услуги в M2000

    BEGIN
	        
        irbis_is_core.write_irbis_activity_log('CreateCloudVideo',
                                                'RequestID="'||TO_CHAR(RequestID)||'", DateMontWish="'||TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS')||'", TK_ID ="'||TK_ID||'", ConnectionType="'||ConnectionType||'", RequestComment="'||RequestComment||'"',
                                                RequestID,
                                                MainParam);
        
        -- Проверка на наличие id TK                                       
        IF TK_ID IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен id TK');
        END IF;
        rm_security.setuser(IRBIS_USER_ID);
        m2_common.appuser_id := IRBIS_USER_ID;
        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE'))
        LOOP
            CASE x.param_name
                WHEN 'ContractCommonID'   THEN mAbonementID         := TO_NUMBER(x.VALUE);
                WHEN 'ContractHouseID'    THEN mHouseID             := TO_NUMBER(x.value);
                WHEN 'ContractAppartment' THEN mApartment           := x.value;
                WHEN 'ClientPhones'       THEN mContactPhone        := x.VALUE;
                WHEN 'RequestCreator'     THEN mOperatorName        := x.VALUE;
                WHEN 'ClientID'           THEN mClientID            := TO_NUMBER(x.VALUE);
                WHEN 'MarketingCategory'  THEN mMarketingCategory   := x.VALUE;
                WHEN 'Priority'           THEN mPriority            := TO_NUMBER(x.VALUE);
                WHEN 'AccountID'          THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
                WHEN 'TariffPlanName'     THEN mTariffPlanName      := x.VALUE;
                ELSE NULL;
            END CASE;
        END LOOP;

        mPriorityLong := irbis_is_core.GetPriorityValue(mPriority);

        -- Определение адреса (mState не проверять, т.к. 1 = генерировать исключение)
        mHouseOnly := 0;
        mPrivateHouse := 0;
        mAddress2_ID := NULL;
        irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
        -- Определение филиала
        mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);
        -- Отдел, в котором должно оказаться заявление
        mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

        -- Первая попытка создания документов, с Ирбиса нет повторного запуска, поэтому нет проверки что ранее были попытки создания документов
        mProc := 38;
        mSubtype_ID   := irbis_utl.defineSubtype('BP="'||TO_CHAR(mProc)||'";'||
                                                    'CONNECTION="'||TO_CHAR(ConnectionType)||'";'||
                                                    'OBJECT="D";'||'"');
        IF mSubtype_ID IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен вид заявления');
        END IF;
        mChildSubtype := irbis_utl.defineSubtype('BP="'||TO_CHAR(mProc)||'";'||
                                                    'CONNECTION="'||TO_CHAR(ConnectionType)||'";'||
                                                    'OBJECT="O";'||'"');
        IF mChildSubtype IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен вид наряда');
        END IF;

        SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

        -- СОЗДАНИЕ ЗАЯВЛЕНИЯ
        IF mCategID = 7 THEN
            SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_OVN'), NULL) INTO mCuslType_ID FROM dual;
            -- Создание заявления
            ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                                    SYSDATE, '',
                                                    mTelzone_ID, IRBIS_USER_ID, mCuslType_ID,
                                                    mClientID, 'IRBIS_CONTRAGENT',
                                                    mAbonent_ID, 'IRBIS_ABONENT',
                                                    mAddress_ID, 'M2000_ADDRESS',
                                                    mAddress2_ID, 'M2000_ADDRESS',
                                                    0, NULL, NULL, NULL, NULL, NULL);
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
        END IF;
        -- Заполнение атрибутов
        irbis_is_core.create_paper_attrs(mDeclar_ID);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'MARK_CATEG', mMarketingCategory, mMarketingCategory);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'PRIORITET', TO_CHAR(mPriority), mPriorityLong);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', ConnectionType, ConnectionType);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'TARIF_PLAN', mTariffPlanName, mTariffPlanName);

        -- Привязка абонемента, техкарты к заявлению
        UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = TK_ID WHERE id = mContent_ID;
        -- Привязка ID заявки Ирбис к заявлению
        irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
        -- Направление заявления в нужный отдел
        mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
        irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
        irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

        -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ
        irbis_is_core.create_tc_by_request(mOrder_ID,
                                            mChildSubtype,
                                            mDeclar_ID,
                                            mSubtype_ID,
                                            RequestID,
                                            mOtdel_ID,
                                            mAbonOtdelID,
                                            0,
                                            MainParam);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));

        -- Сохранение созданной техкарты в документе - заявление
        irbis_is_core.attach_tk_to_paper(TK_ID, mDeclar_ID);
        -- Сохранение созданной техкарты в документе - наряд
        irbis_is_core.attach_tk_to_paper(TK_ID, mOrder_ID);
        -- Направление наряда в следующий отдел
        irbis_utl.sendPaperNextDepartment(mOrder_ID);
    END;

    -- Создание заявления и наряда для расторжения облачного видеонаблюдения
    PROCEDURE CloseCloudVideo
    (
        RequestID       IN NUMBER,      -- ID заявки
        CloseReason     IN VARCHAR2,    -- Причина отказа от услуг
        DateMontWish    IN DATE,        -- Желаемая дата прихода специалиста
        TK_ID           IN NUMBER,      -- ID тех.карты
        ConnectionType  IN VARCHAR2,    -- Тип подключения
        RequestComment  IN VARCHAR2,    -- Комментарии из Ирбиса
        Dismantling     IN NUMBER,      -- Требуется демонтаж
        MainParam       IN VARCHAR2
    ) IS
        mAddress_ID         ad_paper_content.address_id%TYPE;
        mAddress2_ID        ad_paper_content.address2_id%TYPE;
        mHouseID            NUMBER; -- ID дома
        mApartment          VARCHAR2(200);  -- ID квартиры
        mState              NUMBER;
        mAbonementID        NUMBER; -- идентификатор абонемента
        mContactPhone       VARCHAR2(200);  -- Контактный телефон абонента
        mOperatorName       VARCHAR2(200);  -- ФИО оператора создавшего заявление
        mClientID           NUMBER; -- Идентификатор клиента в IRBiS
        mAbonent_ID         ad_paper_content.abonent_id%TYPE;
        mHouseOnly          NUMBER; -- Признак того, что для многоквартирного дома не была указана квартира
        mPrivateHouse       NUMBER; -- Признак того, что дом является частным (без квартир)
        mTelzone_ID         ad_papers.telzone_id%TYPE;
        mAbonOtdelID        ad_papers.department_id%TYPE;   -- ID отдела, в котором должно оказаться заявление после создания
        mOtdel_ID           ad_papers.department_id%TYPE;   -- ID отдела, в котором должен оказаться наряд после создания
        mDeclar_ID          ad_papers.id%TYPE;  -- ID заявления
        mOrder_ID           ad_papers.id%TYPE;  -- ID наряда
        mCategID            NUMBER;
        mSubtype_ID         ad_subtypes.id%TYPE;        -- ID вида заявления
        mChildSubtype       ad_subtypes.id%TYPE;        -- ID вида ТС
        mContent_ID         ad_paper_content.id%TYPE;   -- ID содержания созданного документа
        mProc               NUMBER; -- БП
        mCuslType_ID        ad_paper_content.cusl_type_id%TYPE; -- Тип услуги в M2000

    BEGIN
        irbis_is_core.write_irbis_activity_log('CloseCloudVideo',
                                                'RequestID="'||TO_CHAR(RequestID)||
                                                '", CloseReason="' || CloseReason ||
                                                '", DateMontWish="'||TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS')||
                                                '", TK_ID ="'||TK_ID||
                                                '", ConnectionType="'||ConnectionType||
                                                '", RequestComment="'||RequestComment||'"',
                                                RequestID,
                                                MainParam);
        rm_security.setuser(IRBIS_USER_ID);
        m2_common.appuser_id := IRBIS_USER_ID;
        -- Разбор XML
        FOR x IN (SELECT param_name, value FROM XMLTABLE('/PARAMSET/PARAM' PASSING
                   XMLTYPE(MainParam) COLUMNS param_name VARCHAR2(30) PATH 'PARAM_NAME', value VARCHAR2(255) PATH 'VALUE'))
        LOOP
            CASE x.param_name
                WHEN 'ContractCommonID'   THEN mAbonementID         := TO_NUMBER(x.VALUE);
                WHEN 'ContractHouseID'    THEN mHouseID             := TO_NUMBER(x.value);
                WHEN 'ContractAppartment' THEN mApartment           := x.value;
                WHEN 'ClientPhones'       THEN mContactPhone        := x.VALUE;
                WHEN 'RequestCreator'     THEN mOperatorName        := x.VALUE;
                WHEN 'ClientID'           THEN mClientID            := TO_NUMBER(x.VALUE);
                WHEN 'AccountID'          THEN mAbonent_ID          := TO_NUMBER(x.VALUE);
                ELSE NULL;
            END CASE;
        END LOOP;

        -- Определение адреса (mState не проверять, т.к. 1 = генерировать исключение)
        mHouseOnly := 0;
        mPrivateHouse := 0;
        mAddress2_ID := NULL;
        irbis_is_core.GetAddressID(mHouseID, mApartment, mAddress_ID, mHouseOnly, mPrivateHouse, 1, mState);
        -- Определение филиала
        mTelzone_ID := irbis_is_core.GetTelzoneByHouse(mHouseID);
        -- Отдел, в котором должно оказаться заявление
        mAbonOtdelID := irbis_is_core.get_abonotdel_by_telzone(mTelzone_ID);

        -- Первая попытка создания документов, с Ирбиса нет повторного запуска, поэтому нет проверки что ранее были попытки создания документов
        mProc := 4;
        mSubtype_ID   := irbis_utl.defineSubtype('BP="'||TO_CHAR(mProc)||'";'||
                                                    'CONNECTION="'||TO_CHAR(ConnectionType)||'";'||
                                                    'OBJECT="D";'||'"');
        IF mSubtype_ID IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен вид заявления');
        END IF;
        mChildSubtype := irbis_utl.defineSubtype('BP="'||TO_CHAR(mProc)||'";'||
                                                    'CONNECTION="'||TO_CHAR(ConnectionType)||'";'||
                                                    'OBJECT="O";'||'"');
        IF mChildSubtype IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Не определен вид наряда');
        END IF;

        SELECT list_cat_id INTO mCategID FROM ad_subtypes WHERE id = mSubtype_ID;

        -- СОЗДАНИЕ ЗАЯВЛЕНИЯ
        IF mCategID = 7 THEN
            SELECT NVL((SELECT id FROM ad_list_card_type WHERE card_id = 3 AND strcod = 'IRBIS_OVN'), NULL) INTO mCuslType_ID FROM dual;
            -- Создание заявления
            ad_utils.ad_create_paper_cat7_single (mDeclar_ID, mContent_ID, mSubtype_ID,
                                                    SYSDATE, '',
                                                    mTelzone_ID, IRBIS_USER_ID, mCuslType_ID,
                                                    mClientID, 'IRBIS_CONTRAGENT',
                                                    mAbonent_ID, 'IRBIS_ABONENT',
                                                    mAddress_ID, 'M2000_ADDRESS',
                                                    mAddress2_ID, 'M2000_ADDRESS',
                                                    0, NULL, NULL, NULL, NULL, NULL);
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Функция не поддерживается: только документы категории "Расширенная работа с услугами"');
        END IF;
        -- Заполнение атрибутов
        irbis_is_core.create_paper_attrs(mDeclar_ID);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'CONTACT_PHONE', mContactPhone, mContactPhone);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'FIO_GIVE_DOC', mOperatorName, mOperatorName);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'CONNECTION_TYPE', ConnectionType, ConnectionType);
        irbis_is_core.update_paper_attr(mDeclar_ID, 'REQUEST_ID', RequestID, RequestID);

        -- Привязка абонемента, техкарты к заявлению
        UPDATE ad_paper_extended SET usl_id = mAbonementID, usl_card_id = mCuslType_ID, tk_id = TK_ID WHERE id = mContent_ID;
        -- Привязка ID заявки Ирбис к заявлению
        irbis_is_core.attach_paper_to_request(mDeclar_ID, RequestID, mProc, MainParam);
        -- Направление заявления в нужный отдел
        mAbonOtdelID := irbis_utl.getDepCreatorByWork(mDeclar_ID, CREATOR_WORK_ID, irbis_user_id, mAbonOtdelID);
        irbis_utl.assertTrue((mAbonOtdelID > 0), 'Не удалось определить отдел-создатель');
        irbis_is_core.move_created_paper(mDeclar_ID, mAbonOtdelID);

        -- СОЗДАНИЕ НАРЯДА НА ОСНОВАНИИ ЗАЯВЛЕНИЯ
        irbis_is_core.create_tc_by_request(mOrder_ID,
                                            mChildSubtype,
                                            mDeclar_ID,
                                            mSubtype_ID,
                                            RequestID,
                                            mOtdel_ID,
                                            mAbonOtdelID,
                                            0,
                                            MainParam);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DOC_COMMENT', RequestComment, RequestComment);
        irbis_is_core.update_paper_attr(mOrder_ID, 'DATEMONT_WISH', TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'), TO_CHAR(DateMontWish, 'DD.MM.YYYY HH24:MI:SS'));
        irbis_is_core.update_paper_attr(mOrder_ID, 'DISMANTLING', Dismantling, Dismantling);

        -- Сохранение созданной техкарты в документе - заявление
        irbis_is_core.attach_tk_to_paper(TK_ID, mDeclar_ID);
        -- Сохранение созданной техкарты в документе - наряд
        irbis_is_core.attach_tk_to_paper(TK_ID, mOrder_ID);
        -- Направление наряда в следующий отдел
        irbis_utl.sendPaperNextDepartment(mOrder_ID);
    END;
   
   -- Процедура логирования команд на xDSL
    PROCEDURE Write_Activity_xDSL_log
    (
        pOperation      VARCHAR2,
        pMetod          VARCHAR2,
        pRespCode       VARCHAR2,
        pRequest        VARCHAR2,
        pCommand        VARCHAR2,
        pPesponse_XML   CLOB,
        pPaper_id       NUMBER
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO LOG_ACTIVITY_XDSL(log_id, log_date, operation, method, resp_code, request, command, response_xml, paper_id)
        VALUES(log_activity_xDSL_seq.NEXTVAL, SYSDATE, pOperation, pMetod, pRespCode, pRequest, pCommand, pPesponse_XML, pPaper_id);
        COMMIT;
    END;

END IRBIS_IS;
