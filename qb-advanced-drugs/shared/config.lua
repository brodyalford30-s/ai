Config = Config or {}

Config.Debug = false
Config.Inventory = 'qb' -- qb or ox. qb mode uses Player.Functions.* item helpers.
Config.AdminPermission = 'admin'
Config.AdminCommand = 'drugcreator'
Config.ReloadCommand = 'drugreload'
Config.StorageFile = 'data/drugs.json'
Config.UseDatabaseBackup = true
Config.InteractDistance = 2.0
Config.DrawDistance = 18.0
Config.MinimumPolice = 0
Config.AlertPoliceChance = 20
Config.SellCooldownSeconds = 6
Config.CraftCooldownSeconds = 2
Config.Locale = {
    openCreator = 'Open drug creator',
    gather = 'Gather',
    craft = 'Cook / process',
    package = 'Package',
    sell = 'Sell product',
    notEnoughItems = 'You do not have the required items.',
    policeNeeded = 'Not enough police are on duty.',
    invalidDrug = 'That drug profile does not exist.',
    busy = 'You are already doing something.',
    created = 'Drug profile saved.',
    deleted = 'Drug profile deleted.',
    sold = 'Product sold.',
    noBuyer = 'The buyer is not interested right now.',
}

Config.Progress = {
    gather = 5500,
    craft = 9000,
    package = 6500,
    sell = 3500,
}

Config.DefaultLocations = {
    gather = vector3(2222.02, 5577.12, 53.85),
    craft = vector3(1391.85, 3605.73, 38.94),
    package = vector3(2433.28, 4970.86, 42.35),
    dealer = vector3(-1172.25, -1572.62, 4.66),
}

Config.Marker = {
    type = 2,
    scale = vector3(0.25, 0.25, 0.25),
    color = { r = 102, g = 16, b = 242, a = 170 },
}

Config.DefaultDrugs = {
    {
        id = 'moon_sugar',
        label = 'Moon Sugar',
        enabled = true,
        rawItem = 'moon_sugar_leaf',
        processedItem = 'moon_sugar_paste',
        packagedItem = 'moon_sugar_bag',
        gatherAmount = { min = 1, max = 3 },
        craftRecipe = {
            { item = 'moon_sugar_leaf', amount = 4 },
            { item = 'empty_bag', amount = 1 },
        },
        craftOutput = 1,
        packageRecipe = {
            { item = 'moon_sugar_paste', amount = 1 },
            { item = 'empty_bag', amount = 2 },
        },
        packageOutput = 2,
        sell = { min = 120, max = 210, item = 'moon_sugar_bag' },
        effect = { armor = 10, stress = -15, duration = 45000 },
        locations = {},
    },
}
