local Config = lib.load('config')

local Util = {}

function Util.InDistance(House) -- When the player is near a house.

end

function Util.InteractGarage(House)
    if cache.vehicle then
        TriggerEvent("elevate_garage:parkVehicle", cache.vehicle, "privatHus")
    else
        TriggerEvent("elevate_garage:openGarage", "privatHus", true)
    end
end

function Util.OpenWardrobe()
    if Config.Clothing == 'illenium-appearance' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
    elseif Config.Clothing == 'custom' then
        -- Add your own clothing integration here.
    else -- 'rcore_clothing'
        TriggerEvent('rcore_clothing:openClothingShopWithEverythingAndFree')
    end
end

---@param House table
---@return boolean
local function VerifyStashPin(House)
    local PlayerData = exports['mani-bridge']:GetPlayerData()
    if not PlayerData then return false end

    if not House.HasStashPin then return true end

    local Input = lib.inputDialog(locale('UI.StashPinTitle'), {
        {
            type = 'number',
            label = locale('UI.StashPinLabel'),
            min = 0,
            max = 9999,
            required = true
        }
    })

    if not Input then return false end

    local Pin = ('%04d'):format(tonumber(Input[1]) or -1)

    local Verified = lib.callback.await('mani-housing:server:VerifyStashPin', false, {
        HouseId = House.HouseId,
        Pin = Pin
    })

    if not Verified then
        exports['mani-bridge']:Notify(locale('Notify.Error'), locale('Notify.WrongPin'), 'error', 5000)
        return false
    end

    return true
end

function Util.OpenStash(House)
    if not VerifyStashPin(House) then return end

    if not exports['mani-bridge']:OpenInventory('stash', ('housestash_%s'):format(House.HouseId)) then
        local Success, Message = lib.callback.await('mani-housing:server:RegisterStash', false, House.HouseId)
        if Success then
            exports['mani-bridge']:OpenInventory('stash', ('housestash_%s'):format(House.HouseId))
        else
            exports['mani-bridge']:Notify(locale('Notify.Error'), Message, 'error', 5000)
        end
    end
end

return Util