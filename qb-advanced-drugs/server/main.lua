local QBCore = exports['qb-core']:GetCoreObject()
local Drugs = {}
local DrugIndex = {}
local PlayerBusy = {}
local ActionCooldowns = {}
local SellCooldowns = {}

local function debugPrint(...)
    if Config.Debug then print('[qb-advanced-drugs]', ...) end
end

local function notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
end

local function itemBox(source, itemName, action, amount)
    local itemData = QBCore.Shared.Items[itemName]
    if itemData then TriggerClientEvent('inventory:client:ItemBox', source, itemData, action, amount) end
end

local function hasPermission(source)
    if source == 0 then return true end
    return QBCore.Functions.HasPermission(source, Config.AdminPermission) or IsPlayerAceAllowed(source, 'command.' .. Config.AdminCommand)
end

local function rebuildIndex()
    DrugIndex = {}
    for _, drug in ipairs(Drugs) do DrugIndex[drug.id] = drug end
end

local function encodeForJson(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do
        if type(v) == 'vector3' then
            out[k] = { x = v.x, y = v.y, z = v.z }
        else
            out[k] = encodeForJson(v)
        end
    end
    return out
end

local function ensureStorageDirectory()
    local path = Config.StorageFile
    local directory = path:match('(.+)/[^/]+$')
    if directory then SaveResourceFile(GetCurrentResourceName(), directory .. '/.keep', '', -1) end
end

local function saveDrugs()
    ensureStorageDirectory()
    local payload = json.encode(encodeForJson(Drugs))
    SaveResourceFile(GetCurrentResourceName(), Config.StorageFile, payload, -1)

    if Config.UseDatabaseBackup and MySQL then
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS advanced_drugs (
            id VARCHAR(64) PRIMARY KEY,
            label VARCHAR(128) NOT NULL,
            data LONGTEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )]])
        for _, drug in ipairs(Drugs) do
            MySQL.insert.await('INSERT INTO advanced_drugs (id, label, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), data = VALUES(data)', {
                drug.id,
                drug.label,
                json.encode(encodeForJson(drug)),
            })
        end
    end
end

local function loadDrugs()
    local file = LoadResourceFile(GetCurrentResourceName(), Config.StorageFile)
    local decoded = file and json.decode(file) or nil
    if type(decoded) ~= 'table' or #decoded == 0 then decoded = Config.DefaultDrugs end
    Drugs = DrugShared.NormalizeList(decoded)
    rebuildIndex()
    debugPrint(('loaded %s drug profiles'):format(#Drugs))
end

local function getPoliceCount()
    local count = 0
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job and player.PlayerData.job.name == 'police' and player.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

local function getItemAmount(player, itemName)
    local item = player.Functions.GetItemByName(itemName)
    return item and item.amount or 0
end

local function canCarry(player, itemName, amount)
    if Config.Inventory == 'ox' and exports.ox_inventory then
        return exports.ox_inventory:CanCarryItem(player.PlayerData.source, itemName, amount)
    end
    return true
end

local function addItem(player, itemName, amount)
    if Config.Inventory == 'ox' and exports.ox_inventory then
        return exports.ox_inventory:AddItem(player.PlayerData.source, itemName, amount)
    end
    return player.Functions.AddItem(itemName, amount)
end

local function removeItem(player, itemName, amount)
    if Config.Inventory == 'ox' and exports.ox_inventory then
        return exports.ox_inventory:RemoveItem(player.PlayerData.source, itemName, amount)
    end
    return player.Functions.RemoveItem(itemName, amount)
end

local function hasRecipe(player, recipe)
    for _, ingredient in ipairs(recipe) do
        if getItemAmount(player, ingredient.item) < ingredient.amount then return false end
    end
    return true
end

local function removeRecipe(player, recipe)
    for _, ingredient in ipairs(recipe) do removeItem(player, ingredient.item, ingredient.amount) end
end

local function startAction(source, action, drugId)
    if PlayerBusy[source] then return false end
    local cooldownKey = ('%s:%s:%s'):format(source, action, drugId)
    if ActionCooldowns[cooldownKey] and ActionCooldowns[cooldownKey] > os.time() then return false end
    if Config.MinimumPolice > 0 and getPoliceCount() < Config.MinimumPolice then
        notify(source, Config.Locale.policeNeeded, 'error')
        return false
    end
    PlayerBusy[source] = { action = action, drugId = drugId, cooldownKey = cooldownKey, started = os.time() }
    return true
end

local function finishAction(source)
    local current = PlayerBusy[source]
    if current and current.cooldownKey then
        ActionCooldowns[current.cooldownKey] = os.time() + Config.CraftCooldownSeconds
    end
    PlayerBusy[source] = nil
end

local function maybePoliceAlert(source, drug, action)
    if math.random(100) > Config.AlertPoliceChance then return end
    local coords = GetEntityCoords(GetPlayerPed(source))
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job and player.PlayerData.job.name == 'police' and player.PlayerData.job.onduty then
            TriggerClientEvent('qb-advanced-drugs:client:policeAlert', playerId, coords, drug.label, action)
        end
    end
end

local function registerDrugUsable(drug)
    QBCore.Functions.CreateUseableItem(drug.packagedItem, function(source, item)
        local player = QBCore.Functions.GetPlayer(source)
        if not player or not item then return end
        if removeItem(player, drug.packagedItem, 1) then
            TriggerClientEvent('qb-advanced-drugs:client:useDrug', source, drug)
        end
    end)
end

local function registerAllUsables()
    for _, drug in ipairs(Drugs) do registerDrugUsable(drug) end
end

CreateThread(function()
    Wait(1000)
    loadDrugs()
    registerAllUsables()
    TriggerClientEvent('qb-advanced-drugs:client:syncDrugs', -1, Drugs)
end)

QBCore.Functions.CreateCallback('qb-advanced-drugs:server:getDrugs', function(source, cb)
    cb(Drugs, hasPermission(source))
end)

RegisterNetEvent('qb-advanced-drugs:server:adminSaveDrug', function(data)
    local source = source
    if not hasPermission(source) then return notify(source, 'No permission.', 'error') end
    local normalized, errorMessage = DrugShared.NormalizeDrug(data)
    if not normalized then return notify(source, errorMessage, 'error') end

    local replaced = false
    for index, existing in ipairs(Drugs) do
        if existing.id == normalized.id then
            Drugs[index] = normalized
            replaced = true
            break
        end
    end
    if not replaced then Drugs[#Drugs + 1] = normalized end
    rebuildIndex()
    saveDrugs()
    registerDrugUsable(normalized)
    TriggerClientEvent('qb-advanced-drugs:client:syncDrugs', -1, Drugs)
    notify(source, Config.Locale.created, 'success')
end)

RegisterNetEvent('qb-advanced-drugs:server:adminDeleteDrug', function(drugId)
    local source = source
    if not hasPermission(source) then return notify(source, 'No permission.', 'error') end
    drugId = DrugShared.Slug(drugId)
    for index, drug in ipairs(Drugs) do
        if drug.id == drugId then
            table.remove(Drugs, index)
            rebuildIndex()
            saveDrugs()
            TriggerClientEvent('qb-advanced-drugs:client:syncDrugs', -1, Drugs)
            return notify(source, Config.Locale.deleted, 'success')
        end
    end
    notify(source, Config.Locale.invalidDrug, 'error')
end)

RegisterNetEvent('qb-advanced-drugs:server:gather', function(drugId)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    local drug = DrugIndex[DrugShared.Slug(drugId)]
    if not player or not drug or not drug.enabled then return notify(source, Config.Locale.invalidDrug, 'error') end
    if not startAction(source, 'gather', drug.id) then return notify(source, Config.Locale.busy, 'error') end

    local amount = math.random(drug.gatherAmount.min, drug.gatherAmount.max)
    if not canCarry(player, drug.rawItem, amount) then
        finishAction(source)
        return notify(source, 'Inventory is full.', 'error')
    end
    addItem(player, drug.rawItem, amount)
    itemBox(source, drug.rawItem, 'add', amount)
    finishAction(source)
    maybePoliceAlert(source, drug, 'gathering')
end)

RegisterNetEvent('qb-advanced-drugs:server:craft', function(drugId)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    local drug = DrugIndex[DrugShared.Slug(drugId)]
    if not player or not drug or not drug.enabled then return notify(source, Config.Locale.invalidDrug, 'error') end
    if not hasRecipe(player, drug.craftRecipe) then return notify(source, Config.Locale.notEnoughItems, 'error') end
    if not startAction(source, 'craft', drug.id) then return notify(source, Config.Locale.busy, 'error') end

    if not canCarry(player, drug.processedItem, drug.craftOutput) then
        finishAction(source)
        return notify(source, 'Inventory is full.', 'error')
    end
    removeRecipe(player, drug.craftRecipe)
    addItem(player, drug.processedItem, drug.craftOutput)
    itemBox(source, drug.processedItem, 'add', drug.craftOutput)
    finishAction(source)
    maybePoliceAlert(source, drug, 'processing')
end)

RegisterNetEvent('qb-advanced-drugs:server:package', function(drugId)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    local drug = DrugIndex[DrugShared.Slug(drugId)]
    if not player or not drug or not drug.enabled then return notify(source, Config.Locale.invalidDrug, 'error') end
    if not hasRecipe(player, drug.packageRecipe) then return notify(source, Config.Locale.notEnoughItems, 'error') end
    if not startAction(source, 'package', drug.id) then return notify(source, Config.Locale.busy, 'error') end

    if not canCarry(player, drug.packagedItem, drug.packageOutput) then
        finishAction(source)
        return notify(source, 'Inventory is full.', 'error')
    end
    removeRecipe(player, drug.packageRecipe)
    addItem(player, drug.packagedItem, drug.packageOutput)
    itemBox(source, drug.packagedItem, 'add', drug.packageOutput)
    finishAction(source)
    maybePoliceAlert(source, drug, 'packaging')
end)

RegisterNetEvent('qb-advanced-drugs:server:sell', function(drugId)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    local drug = DrugIndex[DrugShared.Slug(drugId)]
    if not player or not drug or not drug.enabled then return notify(source, Config.Locale.invalidDrug, 'error') end
    if SellCooldowns[source] and SellCooldowns[source] > os.time() then return notify(source, 'Wait for another buyer.', 'error') end
    if getItemAmount(player, drug.sell.item) < 1 then return notify(source, Config.Locale.notEnoughItems, 'error') end
    if math.random(100) <= 12 then
        SellCooldowns[source] = os.time() + Config.SellCooldownSeconds
        maybePoliceAlert(source, drug, 'street dealing')
        return notify(source, Config.Locale.noBuyer, 'error')
    end

    removeItem(player, drug.sell.item, 1)
    local payout = math.random(drug.sell.min, drug.sell.max)
    player.Functions.AddMoney('cash', payout, 'advanced-drugs-sale')
    SellCooldowns[source] = os.time() + Config.SellCooldownSeconds
    notify(source, Config.Locale.sold .. (' ($%s)'):format(payout), 'success')
    maybePoliceAlert(source, drug, 'street dealing')
end)

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    PlayerBusy[source] = nil
    SellCooldowns[source] = nil
    for key in pairs(ActionCooldowns) do
        if key:sub(1, #prefix) == prefix then ActionCooldowns[key] = nil end
    end
end)

QBCore.Commands.Add(Config.AdminCommand, 'Open the advanced drug creator', {}, false, function(source)
    if not hasPermission(source) then return notify(source, 'No permission.', 'error') end
    TriggerClientEvent('qb-advanced-drugs:client:openCreator', source)
end, Config.AdminPermission)

QBCore.Commands.Add(Config.ReloadCommand, 'Reload advanced drug profiles from disk', {}, false, function(source)
    if not hasPermission(source) then return notify(source, 'No permission.', 'error') end
    loadDrugs()
    registerAllUsables()
    TriggerClientEvent('qb-advanced-drugs:client:syncDrugs', -1, Drugs)
    notify(source, 'Drug profiles reloaded.', 'success')
end, Config.AdminPermission)
