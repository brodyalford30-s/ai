local QBCore = exports['qb-core']:GetCoreObject()
local Drugs = {}
local IsAdmin = false
local Busy = false

local function notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or 'primary')
end

local function drawText3d(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawMarker(coords)
    DrawMarker(
        Config.Marker.type,
        coords.x,
        coords.y,
        coords.z - 0.2,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        Config.Marker.scale.x,
        Config.Marker.scale.y,
        Config.Marker.scale.z,
        Config.Marker.color.r,
        Config.Marker.color.g,
        Config.Marker.color.b,
        Config.Marker.color.a,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function openMenu(menu)
    exports['qb-menu']:openMenu(menu)
end

local function showInput(header, inputs)
    return exports['qb-input']:ShowInput({ header = header, submitText = 'Save', inputs = inputs })
end

local function coordsToString(coords)
    return ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z)
end

local function parseCoords(text, fallback)
    local x, y, z = tostring(text or ''):match('^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$')
    return vector3(tonumber(x) or fallback.x, tonumber(y) or fallback.y, tonumber(z) or fallback.z)
end

local function recipeToText(recipe)
    local parts = {}
    for _, ingredient in ipairs(recipe or {}) do
        parts[#parts + 1] = ingredient.item .. ':' .. ingredient.amount
    end
    return table.concat(parts, ',')
end

local function parseRecipe(text)
    local recipe = {}
    for token in tostring(text or ''):gmatch('[^,]+') do
        local item, amount = token:match('^%s*([%w_%-]+)%s*:%s*(%d+)%s*$')
        if item and amount then recipe[#recipe + 1] = { item = item, amount = tonumber(amount) } end
    end
    return recipe
end

local function requestDrugs(callback)
    QBCore.Functions.TriggerCallback('qb-advanced-drugs:server:getDrugs', function(serverDrugs, admin)
        Drugs = serverDrugs or {}
        IsAdmin = admin == true
        if callback then callback() end
    end)
end

local function runProgress(label, duration, anim, done)
    if Busy then return notify(Config.Locale.busy, 'error') end
    Busy = true
    QBCore.Functions.Progressbar('advanced_drugs_' .. label:gsub('%s+', '_'):lower(), label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, anim or {}, {}, {}, function()
        Busy = false
        if done then done() end
    end, function()
        Busy = false
        notify('Cancelled.', 'error')
    end)
end

local function triggerAction(action, drug)
    if action == 'gather' then
        runProgress('Gathering ' .. drug.label, Config.Progress.gather, { animDict = 'amb@world_human_gardener_plant@male@base', anim = 'base', flags = 1 }, function()
            TriggerServerEvent('qb-advanced-drugs:server:gather', drug.id)
        end)
    elseif action == 'craft' then
        runProgress('Processing ' .. drug.label, Config.Progress.craft, { animDict = 'mini@repair', anim = 'fixing_a_player', flags = 1 }, function()
            TriggerServerEvent('qb-advanced-drugs:server:craft', drug.id)
        end)
    elseif action == 'package' then
        runProgress('Packaging ' .. drug.label, Config.Progress.package, { animDict = 'anim@heists@ornate_bank@grab_cash', anim = 'grab', flags = 1 }, function()
            TriggerServerEvent('qb-advanced-drugs:server:package', drug.id)
        end)
    elseif action == 'sell' then
        runProgress('Negotiating sale', Config.Progress.sell, { animDict = 'misscarsteal4@actor', anim = 'actor_berating_loop', flags = 1 }, function()
            TriggerServerEvent('qb-advanced-drugs:server:sell', drug.id)
        end)
    end
end

local function buildDrugFromInput(input, existing)
    existing = existing or {}
    local defaults = existing.locations or {}
    return {
        id = DrugShared.Slug(input.id or existing.id),
        label = input.label or existing.label,
        enabled = input.enabled == 'true' or input.enabled == true or input.enabled == nil,
        rawItem = input.rawItem,
        processedItem = input.processedItem,
        packagedItem = input.packagedItem,
        gatherAmount = { min = tonumber(input.gatherMin), max = tonumber(input.gatherMax) },
        craftRecipe = parseRecipe(input.craftRecipe),
        craftOutput = tonumber(input.craftOutput),
        packageRecipe = parseRecipe(input.packageRecipe),
        packageOutput = tonumber(input.packageOutput),
        sell = { item = input.sellItem, min = tonumber(input.sellMin), max = tonumber(input.sellMax) },
        effect = { armor = tonumber(input.armor), stress = tonumber(input.stress), duration = tonumber(input.duration) },
        locations = {
            gather = parseCoords(input.gatherCoords, defaults.gather or Config.DefaultLocations.gather),
            craft = parseCoords(input.craftCoords, defaults.craft or Config.DefaultLocations.craft),
            package = parseCoords(input.packageCoords, defaults.package or Config.DefaultLocations.package),
            dealer = parseCoords(input.dealerCoords, defaults.dealer or Config.DefaultLocations.dealer),
        },
    }
end

local function openDrugForm(existing)
    local ped = PlayerPedId()
    local currentCoords = GetEntityCoords(ped)
    existing = existing or {
        id = '',
        label = '',
        enabled = true,
        rawItem = '',
        processedItem = '',
        packagedItem = '',
        gatherAmount = { min = 1, max = 3 },
        craftRecipe = {},
        craftOutput = 1,
        packageRecipe = {},
        packageOutput = 1,
        sell = { item = '', min = 100, max = 200 },
        effect = { armor = 0, stress = 0, duration = 30000 },
        locations = { gather = currentCoords, craft = currentCoords, package = currentCoords, dealer = currentCoords },
    }

    local input = showInput('Advanced Drug Creator', {
        { text = 'Drug ID (slug)', name = 'id', type = 'text', isRequired = true, default = existing.id },
        { text = 'Label', name = 'label', type = 'text', isRequired = true, default = existing.label },
        { text = 'Enabled (true/false)', name = 'enabled', type = 'text', default = tostring(existing.enabled ~= false) },
        { text = 'Raw item', name = 'rawItem', type = 'text', isRequired = true, default = existing.rawItem },
        { text = 'Processed item', name = 'processedItem', type = 'text', isRequired = true, default = existing.processedItem },
        { text = 'Packaged item', name = 'packagedItem', type = 'text', isRequired = true, default = existing.packagedItem },
        { text = 'Gather min', name = 'gatherMin', type = 'number', default = existing.gatherAmount.min },
        { text = 'Gather max', name = 'gatherMax', type = 'number', default = existing.gatherAmount.max },
        { text = 'Craft recipe (item:amount,item:amount)', name = 'craftRecipe', type = 'text', default = recipeToText(existing.craftRecipe) },
        { text = 'Craft output amount', name = 'craftOutput', type = 'number', default = existing.craftOutput },
        { text = 'Package recipe (item:amount,item:amount)', name = 'packageRecipe', type = 'text', default = recipeToText(existing.packageRecipe) },
        { text = 'Package output amount', name = 'packageOutput', type = 'number', default = existing.packageOutput },
        { text = 'Sell item', name = 'sellItem', type = 'text', default = existing.sell.item or existing.packagedItem },
        { text = 'Sell min cash', name = 'sellMin', type = 'number', default = existing.sell.min },
        { text = 'Sell max cash', name = 'sellMax', type = 'number', default = existing.sell.max },
        { text = 'Use armor change', name = 'armor', type = 'number', default = existing.effect.armor },
        { text = 'Use stress change', name = 'stress', type = 'number', default = existing.effect.stress },
        { text = 'Effect duration ms', name = 'duration', type = 'number', default = existing.effect.duration },
        { text = 'Gather coords x,y,z', name = 'gatherCoords', type = 'text', default = coordsToString(existing.locations.gather) },
        { text = 'Craft coords x,y,z', name = 'craftCoords', type = 'text', default = coordsToString(existing.locations.craft) },
        { text = 'Package coords x,y,z', name = 'packageCoords', type = 'text', default = coordsToString(existing.locations.package) },
        { text = 'Dealer coords x,y,z', name = 'dealerCoords', type = 'text', default = coordsToString(existing.locations.dealer) },
    })
    if not input then return end
    TriggerServerEvent('qb-advanced-drugs:server:adminSaveDrug', buildDrugFromInput(input, existing))
end

local function openDrugActions(drug)
    openMenu({
        { header = drug.label, isMenuHeader = true },
        { header = 'Edit profile', txt = 'Change items, recipes, payouts, effects, and coords.', params = { event = 'qb-advanced-drugs:client:editDrug', args = drug.id } },
        { header = 'Teleport: gather', txt = coordsToString(drug.locations.gather), params = { event = 'qb-advanced-drugs:client:teleport', args = drug.locations.gather } },
        { header = 'Teleport: craft', txt = coordsToString(drug.locations.craft), params = { event = 'qb-advanced-drugs:client:teleport', args = drug.locations.craft } },
        { header = 'Teleport: package', txt = coordsToString(drug.locations.package), params = { event = 'qb-advanced-drugs:client:teleport', args = drug.locations.package } },
        { header = 'Teleport: dealer', txt = coordsToString(drug.locations.dealer), params = { event = 'qb-advanced-drugs:client:teleport', args = drug.locations.dealer } },
        { header = 'Delete profile', txt = 'This removes the profile from the resource JSON.', params = { event = 'qb-advanced-drugs:client:deleteDrug', args = drug.id } },
        { header = 'Back', params = { event = 'qb-advanced-drugs:client:openCreator' } },
    })
end

local function findDrug(drugId)
    for _, drug in ipairs(Drugs) do
        if drug.id == drugId then return drug end
    end
end

RegisterNetEvent('qb-advanced-drugs:client:syncDrugs', function(serverDrugs)
    Drugs = serverDrugs or {}
end)

RegisterNetEvent('qb-advanced-drugs:client:openCreator', function()
    requestDrugs(function()
        if not IsAdmin then return notify('No permission.', 'error') end
        local menu = {
            { header = 'Advanced Drug Creator', isMenuHeader = true },
            { header = 'Create new drug', txt = 'Build a new item flow, recipe, effect, and location set.', params = { event = 'qb-advanced-drugs:client:newDrug' } },
        }
        for _, drug in ipairs(Drugs) do
            menu[#menu + 1] = {
                header = drug.label .. ' (' .. drug.id .. ')',
                txt = ('%s -> %s -> %s'):format(drug.rawItem, drug.processedItem, drug.packagedItem),
                params = { event = 'qb-advanced-drugs:client:drugActions', args = drug.id },
            }
        end
        menu[#menu + 1] = { header = 'Close', params = { event = 'qb-menu:closeMenu' } }
        openMenu(menu)
    end)
end)

RegisterNetEvent('qb-advanced-drugs:client:newDrug', function() openDrugForm() end)
RegisterNetEvent('qb-advanced-drugs:client:editDrug', function(drugId)
    local drug = findDrug(drugId)
    if drug then openDrugForm(drug) end
end)
RegisterNetEvent('qb-advanced-drugs:client:drugActions', function(drugId)
    local drug = findDrug(drugId)
    if drug then openDrugActions(drug) end
end)
RegisterNetEvent('qb-advanced-drugs:client:deleteDrug', function(drugId)
    TriggerServerEvent('qb-advanced-drugs:server:adminDeleteDrug', drugId)
end)
RegisterNetEvent('qb-advanced-drugs:client:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent('qb-advanced-drugs:client:useDrug', function(drug)
    local ped = PlayerPedId()
    if drug.effect.armor ~= 0 then
        SetPedArmour(ped, math.max(0, math.min(100, GetPedArmour(ped) + drug.effect.armor)))
    end
    if drug.effect.stress < 0 then
        TriggerServerEvent('hud:server:RelieveStress', math.abs(drug.effect.stress))
    elseif drug.effect.stress > 0 then
        TriggerServerEvent('hud:server:GainStress', drug.effect.stress)
    end
    if drug.effect.duration > 0 then
        StartScreenEffect('DrugsMichaelAliensFight', 0, true)
        SetTimecycleModifier('spectator5')
        SetPedMotionBlur(ped, true)
        SetTimeout(drug.effect.duration, function()
            StopScreenEffect('DrugsMichaelAliensFight')
            ClearTimecycleModifier()
            SetPedMotionBlur(ped, false)
        end)
    end
end)

RegisterNetEvent('qb-advanced-drugs:client:policeAlert', function(coords, label, action)
    notify(('Suspicious %s activity reported: %s'):format(label, action), 'error')
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Suspicious drug activity')
    EndTextCommandSetBlipName(blip)
    SetTimeout(60000, function() RemoveBlip(blip) end)
end)

CreateThread(function()
    requestDrugs()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        for _, drug in ipairs(Drugs) do
            if drug.enabled then
                local actions = {
                    { name = 'gather', label = Config.Locale.gather, coords = drug.locations.gather },
                    { name = 'craft', label = Config.Locale.craft, coords = drug.locations.craft },
                    { name = 'package', label = Config.Locale.package, coords = drug.locations.package },
                    { name = 'sell', label = Config.Locale.sell, coords = drug.locations.dealer },
                }
                for _, action in ipairs(actions) do
                    local distance = #(playerCoords - action.coords)
                    if distance < Config.DrawDistance then
                        sleep = 0
                        drawMarker(action.coords)
                        drawText3d(action.coords + vector3(0.0, 0.0, 0.35), ('[E] %s %s'):format(action.label, drug.label))
                        if distance < Config.InteractDistance and IsControlJustPressed(0, 38) then
                            triggerAction(action.name, drug)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
