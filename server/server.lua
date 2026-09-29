local Config, Util = lib.load('config'), lib.load('open.sv_open')

local HouseCache, PlayerCache, StashPins, Initialized = {}, {}, {}, false

local HouseClass = {}
HouseClass.__index = HouseClass

lib.locale()

function HouseClass:New(Data)
    return setmetatable({
        HouseId = Data.HouseId,
        Owner = Data.Owner,
        Coords = Data.Coords,
        Shell = Data.Shell,
        Decor = Data.Decor,
        SalesData = Data.SalesData,
        State = Data.State,
        HasStashPin = Data.HasStashPin or false,
        Keyholders = {},
        Inside = {}
    }, self)
end

CreateThread(function()
    local HouseSuccess, Houses = pcall(function() return MySQL.query.await('SELECT * FROM `mani_houses`') end)
    if not HouseSuccess then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `mani_houses` (
                `houseid` INT(11) NOT NULL AUTO_INCREMENT,
                `owner` VARCHAR(60) NULL DEFAULT '' COLLATE 'utf8mb4_0900_ai_ci',
                `coords` LONGTEXT NOT NULL DEFAULT '[]' COLLATE 'utf8mb4_0900_ai_ci',
                `shell` VARCHAR(25) NULL DEFAULT '' COLLATE 'utf8mb4_0900_ai_ci',
                `decor` LONGTEXT NULL DEFAULT '[]' COLLATE 'utf8mb4_0900_ai_ci',
                `salesdata` LONGTEXT NOT NULL DEFAULT '[]' COLLATE 'utf8mb4_0900_ai_ci',
                `state` INT(1) NOT NULL DEFAULT '0',
                `stashpin` VARCHAR(4) NULL DEFAULT NULL COLLATE 'utf8mb4_0900_ai_ci',
                INDEX `houseid` (`houseid`) USING BTREE
            )
            COLLATE='utf8mb4_0900_ai_ci'
            ENGINE=InnoDB;
        ]])

        Houses = {}
    end

    pcall(function()
        MySQL.query.await("ALTER TABLE `mani_houses` ADD COLUMN `stashpin` VARCHAR(4) NULL DEFAULT NULL COLLATE 'utf8mb4_0900_ai_ci'")
    end)

    local KeySuccess, Keyholders = pcall(function() return MySQL.query.await('SELECT * FROM `mani_housekeys`') end)
    if not KeySuccess then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `mani_housekeys` (
                `identifier` VARCHAR(60) NOT NULL DEFAULT '' COLLATE 'utf8mb4_0900_ai_ci',
                `keys` LONGTEXT NOT NULL DEFAULT '[]' COLLATE 'utf8mb4_0900_ai_ci',
                `character` VARCHAR(60) NULL DEFAULT '' COLLATE 'utf8mb4_0900_ai_ci',
                UNIQUE INDEX `identifier` (`identifier`) USING BTREE,
                CONSTRAINT `keys` CHECK (json_valid(`keys`))
            )
            COLLATE='utf8mb4_0900_ai_ci'
            ENGINE=InnoDB;
        ]])

        Keyholders = {}
    end

    for i = 1, #Houses do
        local House = Houses[i]

        local HasStashPin = House.stashpin ~= nil and House.stashpin ~= ''

        HouseCache[House.houseid] = HouseClass:New({
            HouseId = House.houseid,
            Owner = House.owner,
            Coords = json.decode(House.coords),
            Shell = House.shell,
            Decor = json.decode(House.decor),
            SalesData = json.decode(House.salesdata),
            State = House.state,
            HasStashPin = HasStashPin,
            Keyholders = {}
        })

        if HasStashPin then
            StashPins[House.houseid] = House.stashpin
        end
    end

    for i = 1, #Keyholders do
        local Keyholder = Keyholders[i]
        local Keys = json.decode(Keyholder.keys)

        PlayerCache[Keyholder.identifier] = PlayerCache[Keyholder.identifier] or {}
        PlayerCache[Keyholder.identifier].Keys = PlayerCache[Keyholder.identifier].Keys or {}

        for StringId, Data in pairs(Keys) do
            local HouseId = tonumber(StringId)
            if HouseId and HouseCache[HouseId] then
                PlayerCache[Keyholder.identifier].Keys[HouseId] = Data
                HouseCache[HouseId].Keyholders[Keyholder.identifier] = {
                    Character = Keyholder.character,
                    Permissions = Data
                }
            end
        end
    end

    lib.print.info(('[Mani-Housing] Loaded %s Houses'):format(#Houses))

    Initialized = true

    local WhitelistedJobs = Config.WhitelistedJobs
    Config.WhitelistedJobs = {}

    for _, Job in ipairs(WhitelistedJobs) do
        Config.WhitelistedJobs[Job] = true
    end

    Config.ShellIndexes = {}

    for i = 1, #Config.Shells do
        local Shell = Config.Shells[i]
        Config.ShellIndexes[Shell.Model] = i
    end
end)

lib.callback.register('mani-housing:server:GetHouses', function()
    while not Initialized do Wait(100) end
    return HouseCache
end)

lib.callback.register('mani-housing:server:GetNearbyPlayers', function(Source, Coords, HouseId)
    local Players = lib.getNearbyPlayers(Coords, 7.5)
    local PlayerTable = {}

    local House = HouseCache[HouseId]
    if not House then return {} end

    for i = 1, #Players do
        local Player = Players[i]
        if Config.Debug or Player.id ~= Source then
            local PlayerData = exports['mani-bridge']:GetPlayerData(Player.id)
            if not House.Keyholders[PlayerData.Identifier] then
                PlayerTable[#PlayerTable + 1] = {
                    Name = PlayerData.Character.Fullname,
                    Source = Player.id
                }
            end
        end
    end

    return PlayerTable
end)

lib.callback.register('mani-housing:server:GiveKeys', function(Source, Players, HouseId)
    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    for i = 1, #Players do
        local PlayerSource = Players[i]
        House:AddKeyholder(PlayerSource, {
            Enter = true,
            Garage = false,
            Stash = false,
            Admin = false
        }, true)
    end

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, HouseCache[HouseId], 'Update')

    return true
end)

lib.callback.register('mani-housing:server:UpdatePermissions', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:UpdatePermissions(Data.Identifier, Data.Permissions)

    return true
end)

lib.callback.register('mani-housing:server:RemoveKeyholder', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:RemoveKeyholder(Data.Identifier)

    return true
end)

lib.callback.register('mani-housing:server:CreateHouse', function(Source, Data)
    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end
    if not Config.WhitelistedJobs[PlayerData.Job.Name] then return false, locale('Notify.NoPermission') end

    local HouseData = {
        Coords = {
            Entrance = Data.Entrance,
            Garage = Data.Garage,
            Zone = Data.Zone
        },
        SalesData = {
            Price = Data.Price,
            Salesman = PlayerData.Character.Fullname,
            SalesmanIdentifier = PlayerData.Identifier,
            SalesmanJob = PlayerData.Job.Name,
            SalesmanJobLabel = PlayerData.Job.Label,
        }
    }

    local HouseId = MySQL.insert.await('INSERT INTO `mani_houses` (`coords`, `salesdata`, `shell`) VALUES (?, ?, ?)', {
        json.encode(HouseData.Coords),
        json.encode(HouseData.SalesData),
        Data.Shell
    })

    if not HouseId then return false, locale('Notify.GenericError') end

    local House = HouseClass:New({
        HouseId = HouseId,
        Owner = '',
        Coords = HouseData.Coords,
        Shell = Data.Shell,
        Decor = {},
        SalesData = HouseData.SalesData,
        State = 0,
        Keyholders = {}
    })

    HouseCache[HouseId] = House

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, House, 'Update')

    Util.Log(Source, ('[Housing] [%s] | %s created a new house (HouseID: %s)'):format(
        Source,
        PlayerData.Character.Firstname,
        HouseId
    ))

    return HouseId
end)

lib.callback.register('mani-housing:server:PurchaseHouse', function(Source, HouseId)
    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    if House.State ~= 0 then return false, locale('Notify.HouseNotForSale') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    local SalesData = House.SalesData
    local SellerJob = SalesData.SalesmanJob
    local Price = SalesData.Price

    if not exports['mani-bridge']:RemoveMoneyAuto(Source, { 'money', 'bank' }, Price) then return false, locale('Notify.CannotAfford') end

    if House.Owner ~= '' then
        exports['mani-bridge']:AddMoneyOffline(House.Owner, 'bank', Price * Config.Commision['Owner'])
    else
        if Config.Commision['Agent'] then exports['mani-bridge']:AddMoneyOffline(SalesData.SalesmanIdentifier, 'bank', Price * Config.Commision['Agent']) end
        Util.AddMoneyForJob(SellerJob, Price * Config.Commision['RealEstate'])
    end

    House:SetOwner(PlayerData)

    Util.Log(Source, ('[Housing] [%s] | %s bought a house (HouseID: %s)'):format(
        Source,
        PlayerData.Character.Firstname,
        HouseId
    ))

    return true
end)

lib.callback.register('mani-housing:server:PlaceWardrobe', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:PlaceWardrobe(Data.PlayerCoords)

    return true
end)

lib.callback.register('mani-housing:server:PlaceStash', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:PlaceStash(Data.PlayerCoords)

    return true
end)

lib.callback.register('mani-housing:server:RegisterStash', function(Source, HouseId)
    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if not House:HasAccess(PlayerData.Identifier, 'Stash') then return false, locale('Notify.NoPermission') end

    local ShellIndex = Config.ShellIndexes[House.Shell]
    if not ShellIndex then return false, locale('Notify.ShellNotExist') end
    local Shell = Config.Shells[ShellIndex]

    exports['mani-bridge']:RegisterStash(('housestash_%s'):format(House.HouseId), locale('Misc.StashName'), Shell.Stash.Slots, Shell.Stash.Weight)

    return true
end)

lib.callback.register('mani-housing:server:SetStashPin', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    if House.Owner ~= PlayerData.Identifier then return false, locale('Notify.NoPermission') end

    local Pin = tostring(Data.Pin or '')
    if not Pin:match('^%d%d%d%d$') then return false, locale('Notify.InvalidPin') end

    local IsChangingPin = StashPins[Data.HouseId] ~= nil

    if IsChangingPin then
        if not exports['mani-bridge']:RemoveMoneyAuto(Source, { 'bank' }, Config.StashPinEditCost) then
            return false, locale('Notify.CannotAfford')
        end
    end

    House:SetStashPin(Pin)

    Util.Log(Source, ('[Housing] [%s] | %s %s the stash code on house (HouseID: %s)'):format(
        Source,
        PlayerData.Character.Firstname,
        IsChangingPin and 'changed' or 'set',
        Data.HouseId
    ))

    return true, IsChangingPin and locale('Notify.StashPinChanged') or locale('Notify.StashPinSet')
end)

lib.callback.register('mani-housing:server:VerifyStashPin', function(Source, Data)
    local House = HouseCache[Data.HouseId]
    if not House then return false end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false end

    local Pin = StashPins[Data.HouseId]
    if not Pin then return true end

    return tostring(Data.Pin) == Pin
end)

lib.callback.register('mani-housing:server:EnterHouse', function(Source, HouseId)
    if not HouseCache[HouseId] then return end

    HouseCache[HouseId].Inside[Source] = true
end)

lib.callback.register('mani-housing:server:ExitHouse', function(Source, HouseId)
    if not HouseCache[HouseId] then return end

    HouseCache[HouseId].Inside[Source] = false
end)

lib.callback.register('mani-housing:server:UpdateGarage', function(Source, Data)
    local HouseId = Data.HouseId
    local Coords = Data.Coords

    if not HouseId or not Coords then return false, locale('Notify.GenericError') end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end
    if not Config.WhitelistedJobs[PlayerData.Job.Name] then return false, locale('Notify.NoPermission') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    House:SetGarage(Coords)

    return true
end)

lib.callback.register('mani-housing:server:RemoveHouse', function(Source, HouseId)
    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end
    if not Config.WhitelistedJobs[PlayerData.Job.Name] and not Config.Debug then return false, locale('Notify.NoPermission') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    House:Remove()

    Util.Log(Source, ('[Housing] [%s] | %s removed a house (HouseID: %s)'):format(
        Source,
        PlayerData.Character.Firstname,
        HouseId
    ))

    return true
end)

lib.callback.register('mani-housing:server:SellHouse', function(Source, Data)
    local HouseId = Data.HouseId
    local Price = Data.Price

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end
    if not Config.WhitelistedJobs[PlayerData.Job.Name] and not Config.Debug then return false, locale('Notify.NoPermission') end

    if not HouseId or not Price then return false, locale('Notify.GenericError') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    House:Sell(Price)

    Util.Log(Source, ('[Housing] [%s] | %s sat a house up for sale (HouseID: %s)'):format(
        Source,
        PlayerData.Character.Firstname,
        HouseId
    ))

    return true
end)

lib.callback.register('mani-housing:server:UploadDecoration', function(Source, Data)
    local HouseId = Data.HouseId
    local Model = Data.Model
    local Label = Data.Label
    local Price = Data.Price
    local Position = Data.Position
    local Rotation = Data.Rotation

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:AddDecoration({
        Model = Model,
        Label = Label,
        Price = Price,
        Position = Position,
        Rotation = Rotation
    })

    return true
end)

lib.callback.register('mani-housing:server:EditDecoration', function(Source, Data)
    local HouseId = Data.HouseId
    local DecorIndex = Data.DecorIndex

    local Position = Data.Position
    local Rotation = Data.Rotation

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:EditDecoration({
        DecorIndex = DecorIndex,
        Position = Position,
        Rotation = Rotation
    })

    return true
end)

lib.callback.register('mani-housing:server:SellDecoration', function(Source, Data)
    local HouseId = Data.HouseId
    local DecorIndex = Data.DecorIndex

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return false, locale('Notify.GenericError') end

    local House = HouseCache[HouseId]
    if not House then return false, locale('Notify.HouseNotExist') end

    if not House:HasAccess(PlayerData.Identifier, 'Admin') then return false, locale('Notify.NoPermission') end

    House:SellDecoration(DecorIndex)

    return true
end)

---@param Source number
---@param Permissions table
---@param IgnoreClient boolean
function HouseClass:AddKeyholder(Source, Permissions, IgnoreClient)
    self = HouseCache[self.HouseId]
    if not self then return end

    local PlayerData = exports['mani-bridge']:GetPlayerData(Source)
    if not PlayerData then return end

    if PlayerData.Identifier == self.Owner then return end
    if self.Keyholders[PlayerData.Identifier] then return end

    self.Keyholders[PlayerData.Identifier] = {
        Character = PlayerData.Character.Fullname,
        Permissions = Permissions
    }

    PlayerCache[PlayerData.Identifier] = PlayerCache[PlayerData.Identifier] or {}
    PlayerCache[PlayerData.Identifier].Keys = PlayerCache[PlayerData.Identifier].Keys or {}

    PlayerCache[PlayerData.Identifier].Keys[self.HouseId] = Permissions

    MySQL.Async.execute('REPLACE INTO `mani_housekeys` (`identifier`, `keys`, `character`) VALUES (@identifier, @keys, @character)', {
        ['@identifier'] = PlayerData.Identifier,
        ['@keys'] = json.encode(PlayerCache[PlayerData.Identifier].Keys),
        ['@character'] = PlayerData.Character.Fullname
    })

    if not IgnoreClient then TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update') end
end

---@param Identifier string
---@param Permissions table
function HouseClass:UpdatePermissions(Identifier, Permissions)
    self = HouseCache[self.HouseId]
    if not self then return end

    if not self.Keyholders[Identifier] then return end
    self.Keyholders[Identifier].Permissions = Permissions

    PlayerCache[Identifier] = PlayerCache[Identifier] or {}
    PlayerCache[Identifier].Keys = PlayerCache[Identifier].Keys or {}

    PlayerCache[Identifier].Keys[self.HouseId] = Permissions

    MySQL.update.await('UPDATE `mani_housekeys` SET `keys` = ? WHERE `identifier` = ?', {
        json.encode(PlayerCache[Identifier].Keys),
        Identifier
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

---@param Identifier string
---@param IgnoreClient boolean
function HouseClass:RemoveKeyholder(Identifier, IgnoreClient)
    self = HouseCache[self.HouseId]
    if not self then return end

    if not self.Keyholders[Identifier] then return end
    self.Keyholders[Identifier] = nil

    PlayerCache[Identifier] = PlayerCache[Identifier] or {}
    PlayerCache[Identifier].Keys = PlayerCache[Identifier].Keys or {}

    PlayerCache[Identifier].Keys[self.HouseId] = nil

    MySQL.update.await('UPDATE `mani_housekeys` SET `keys` = ? WHERE `identifier` = ?', {
        json.encode(PlayerCache[Identifier].Keys),
        Identifier
    })

    if not IgnoreClient then TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update') end
end

---@param Identifier string
---@param Key string
function HouseClass:HasAccess(Identifier, Key)
    local IsOwner = self.Owner == Identifier
    local HasKey = self.Keyholders[Identifier] and self.Keyholders[Identifier].Permissions[Key or 'Enter']

    return IsOwner or HasKey
end

---@param PlayerData table
function HouseClass:SetOwner(PlayerData)
    self = HouseCache[self.HouseId]
    if not self then return end

    self.Owner = PlayerData.Identifier
    self.SalesData.OwnerName = PlayerData.Character.Fullname
    self.State = 1

    MySQL.update.await('UPDATE mani_houses SET owner = ?, salesdata = ?, state = 1 WHERE houseid = ?', {
        self.Owner, json.encode(self.SalesData), self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

---@param Coords vector3
function HouseClass:PlaceWardrobe(Coords)
    self = HouseCache[self.HouseId]
    if not self then return end

    self.Coords.Wardrobe = Coords

    MySQL.update.await('UPDATE mani_houses SET coords = ? WHERE houseid = ?', {
        json.encode(self.Coords), self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')

    self:RunAction(function(HouseSource)
        TriggerClientEvent('mani-housing:client:UpdatePoint', HouseSource, self.Coords.Wardrobe, 'Wardrobe')
    end)
end

---@param Coords vector3
function HouseClass:PlaceStash(Coords)
    self = HouseCache[self.HouseId]
    if not self then return end

    self.Coords.Stash = Coords

    MySQL.update.await('UPDATE mani_houses SET coords = ? WHERE houseid = ?', {
        json.encode(self.Coords), self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')

    self:RunAction(function(HouseSource)
        TriggerClientEvent('mani-housing:client:UpdatePoint', HouseSource, self.Coords.Stash, 'Stash')
    end)
end

---@param Pin string
function HouseClass:SetStashPin(Pin)
    self = HouseCache[self.HouseId]
    if not self then return end

    StashPins[self.HouseId] = Pin
    self.HasStashPin = true

    MySQL.update.await('UPDATE mani_houses SET stashpin = ? WHERE houseid = ?', {
        Pin, self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

---@param Coords vector3
function HouseClass:SetGarage(Coords)
    self = HouseCache[self.HouseId]
    if not self then return end

    self.Coords.Garage = Coords

    MySQL.update.await('UPDATE mani_houses SET coords = ? WHERE houseid = ?', {
        json.encode(self.Coords), self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

function HouseClass:Remove()
    self = HouseCache[self.HouseId]
    if not self then return end

    MySQL.query.await('DELETE FROM mani_houses WHERE houseid = ?', {
        self.HouseId
    })

    for Identifier, Data in pairs(self.Keyholders) do
        self:RemoveKeyholder(Identifier, true)
    end

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Remove')

    self = nil
end

---@param State number
function HouseClass:SetState(State)
    self = HouseCache[self.HouseId]
    if not self then return end
    if type(State) ~= 'number' then return end

    self.State = State

    MySQL.update.await('UPDATE mani_houses SET state = ? WHERE houseid = ?', {
        self.State, self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

---@param Price number
function HouseClass:Sell(Price)
    self = HouseCache[self.HouseId]
    if not self then return end
    if type(Price) ~= 'number' then return end

    self.State = 0
    self.SalesData.Price = Price

    for Identifier, Data in pairs(self.Keyholders) do
        self:RemoveKeyholder(Identifier, true)
    end

    MySQL.update.await('UPDATE mani_houses SET state = ?, salesdata = ? WHERE houseid = ?', {
        self.State,
        json.encode(self.SalesData),
        self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'Update')
end

---@param Data table
function HouseClass:AddDecoration(Data)
    self = HouseCache[self.HouseId]
    if not self then return end

    local Model = Data.Model
    local Label = Data.Label
    local Price = Data.Price
    local Position = Data.Position
    local Rotation = Data.Rotation

    self.Decor[#self.Decor + 1] = {
        Model = Model,
        Label = Label,
        Price = Price,
        Position = Position,
        Rotation = Rotation
    }

    MySQL.update.await('UPDATE mani_houses SET decor = ? WHERE houseid = ?', {
        json.encode(self.Decor),
        self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'UpdateDecoration')
end

---@param Data table
function HouseClass:EditDecoration(Data)
    self = HouseCache[self.HouseId]
    if not self then return end

    local DecorIndex = Data.DecorIndex

    local Position = Data.Position
    local Rotation = Data.Rotation

    if not self.Decor[DecorIndex] then return end

    self.Decor[DecorIndex].Position = Position
    self.Decor[DecorIndex].Rotation = Rotation

    MySQL.update.await('UPDATE mani_houses SET decor = ? WHERE houseid = ?', {
        json.encode(self.Decor),
        self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'UpdateDecoration')
end

---@param DecorIndex number
function HouseClass:SellDecoration(DecorIndex)
    self = HouseCache[self.HouseId]
    if not self then return end

    if not self.Decor[DecorIndex] then return end

    table.remove(self.Decor, DecorIndex)

    MySQL.update.await('UPDATE mani_houses SET decor = ? WHERE houseid = ?', {
        json.encode(self.Decor),
        self.HouseId
    })

    TriggerClientEvent('mani-housing:client:UpdateHouse', -1, self, 'UpdateDecoration')
end

---@param Action function
function HouseClass:RunAction(Action)
    for Source, State in pairs(self.Inside) do
        if State then Action(Source) end
    end
end

---@return table
exports('GetClass', function() return HouseClass end)

---@param HouseId number
---@return table
exports('GetHouse', function(HouseId) return HouseCache[HouseId] end)

exports('GetHouses', function() return HouseCache end)

---@param Identifier string|number
---@param ReturnByIndex boolean
---@return table
exports('GetPlayerHouses', function(Identifier, ReturnByIndex)
    if type(Identifier) == 'number' then
        local PlayerData = exports['mani-bridge']:GetPlayerData(Identifier)
        if not PlayerData then return {} end
        Identifier = PlayerData.Identifier
    end

    local Houses = {}

    for HouseId, House in pairs(HouseCache) do
        if House.Owner == Identifier or House.Keyholders[Identifier] then
            Houses[ReturnByIndex and HouseId or #Houses + 1] = House
        end
    end

    return Houses
end)

exports('AddKeyholder', function(HouseId, Source, Permissions, IgnoreClient)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:AddKeyholder(Source, Permissions, IgnoreClient)

    return true
end)

exports('RemoveKeyholder', function(HouseId, Identifier, IgnoreClient)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:RemoveKeyholder(Identifier, IgnoreClient)

    return true
end)

exports('UpdatePermissions', function(HouseId, Identifier, Permissions)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:UpdatePermissions(Identifier, Permissions)

    return true
end)

exports('HasAccess', function(HouseId, Identifier, Key)
    local House = HouseCache[HouseId]
    if not House then return false end

    return House:HasAccess(Identifier, Key)
end)

exports('SetOwner', function(HouseId, PlayerData)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:SetOwner(PlayerData)

    return true
end)

exports('Remove', function(HouseId)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:Remove()

    return true
end)

exports('SetState', function(HouseId, State)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:SetState(State)

    return true
end)

exports('Sell', function(HouseId, Price)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:Sell(Price)

    return true
end)

exports('RunAction', function(HouseId, Action)
    local House = HouseCache[HouseId]
    if not House then return false end

    House:RunAction(Action)

    return true
end)