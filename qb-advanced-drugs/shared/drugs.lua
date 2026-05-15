DrugShared = DrugShared or {}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

function DrugShared.DeepCopy(value)
    return copy(value)
end

function DrugShared.Slug(value)
    value = tostring(value or ''):lower()
    value = value:gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if value == '' then return nil end
    return value
end

function DrugShared.ClampNumber(value, fallback, min, max)
    local number = tonumber(value) or fallback
    if min and number < min then number = min end
    if max and number > max then number = max end
    return number
end

function DrugShared.NormalizeCoords(coords, fallback)
    fallback = fallback or vector3(0.0, 0.0, 0.0)
    if type(coords) == 'vector3' then return coords end
    if type(coords) == 'table' then
        return vector3(tonumber(coords.x) or fallback.x, tonumber(coords.y) or fallback.y, tonumber(coords.z) or fallback.z)
    end
    return fallback
end

function DrugShared.NormalizeRecipe(recipe)
    local normalized = {}
    if type(recipe) ~= 'table' then return normalized end
    for _, entry in pairs(recipe) do
        local item = DrugShared.Slug(entry.item)
        local amount = DrugShared.ClampNumber(entry.amount, 1, 1, 1000)
        if item then normalized[#normalized + 1] = { item = item, amount = amount } end
    end
    return normalized
end

function DrugShared.NormalizeDrug(drug)
    if type(drug) ~= 'table' then return nil, 'Drug data must be a table.' end

    local id = DrugShared.Slug(drug.id or drug.label)
    if not id then return nil, 'Drug id or label is required.' end

    local normalized = {
        id = id,
        label = tostring(drug.label or id),
        enabled = drug.enabled ~= false,
        rawItem = DrugShared.Slug(drug.rawItem or (id .. '_raw')),
        processedItem = DrugShared.Slug(drug.processedItem or (id .. '_processed')),
        packagedItem = DrugShared.Slug(drug.packagedItem or (id .. '_bag')),
        gatherAmount = {
            min = DrugShared.ClampNumber(drug.gatherAmount and drug.gatherAmount.min, 1, 1, 1000),
            max = DrugShared.ClampNumber(drug.gatherAmount and drug.gatherAmount.max, 3, 1, 1000),
        },
        craftRecipe = DrugShared.NormalizeRecipe(drug.craftRecipe),
        craftOutput = DrugShared.ClampNumber(drug.craftOutput, 1, 1, 1000),
        packageRecipe = DrugShared.NormalizeRecipe(drug.packageRecipe),
        packageOutput = DrugShared.ClampNumber(drug.packageOutput, 1, 1, 1000),
        sell = {
            item = DrugShared.Slug(drug.sell and drug.sell.item or drug.packagedItem or (id .. '_bag')),
            min = DrugShared.ClampNumber(drug.sell and drug.sell.min, 100, 0, 1000000),
            max = DrugShared.ClampNumber(drug.sell and drug.sell.max, 200, 0, 1000000),
        },
        effect = {
            armor = DrugShared.ClampNumber(drug.effect and drug.effect.armor, 0, -100, 100),
            stress = DrugShared.ClampNumber(drug.effect and drug.effect.stress, 0, -100, 100),
            duration = DrugShared.ClampNumber(drug.effect and drug.effect.duration, 30000, 0, 600000),
        },
        locations = {},
    }

    if normalized.gatherAmount.max < normalized.gatherAmount.min then
        normalized.gatherAmount.max = normalized.gatherAmount.min
    end
    if normalized.sell.max < normalized.sell.min then normalized.sell.max = normalized.sell.min end

    local locations = drug.locations or {}
    normalized.locations.gather = DrugShared.NormalizeCoords(locations.gather, Config.DefaultLocations.gather)
    normalized.locations.craft = DrugShared.NormalizeCoords(locations.craft, Config.DefaultLocations.craft)
    normalized.locations.package = DrugShared.NormalizeCoords(locations.package, Config.DefaultLocations.package)
    normalized.locations.dealer = DrugShared.NormalizeCoords(locations.dealer, Config.DefaultLocations.dealer)

    if #normalized.craftRecipe == 0 then
        normalized.craftRecipe = { { item = normalized.rawItem, amount = 3 } }
    end
    if #normalized.packageRecipe == 0 then
        normalized.packageRecipe = { { item = normalized.processedItem, amount = 1 }, { item = 'empty_bag', amount = 1 } }
    end

    return normalized
end

function DrugShared.NormalizeList(list)
    local normalized = {}
    for _, drug in pairs(list or {}) do
        local clean = DrugShared.NormalizeDrug(drug)
        if clean then normalized[#normalized + 1] = clean end
    end
    return normalized
end
