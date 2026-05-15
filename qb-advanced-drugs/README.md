# qb-advanced-drugs

A configurable **advanced drug creator** resource for FiveM QBCore servers. It lets administrators create, edit, delete, and persist custom drug profiles from an in-game menu without rewriting Lua every time they want a new drug loop.

## Features

- `/drugcreator` admin menu powered by `qb-menu` and `qb-input`.
- Create custom drug profiles with:
  - raw, processed, and packaged item names;
  - gather ranges;
  - craft and package recipes;
  - sell item and payout range;
  - usable item effects;
  - gather, craft, package, and dealer coordinates.
- Server-side recipe validation, item removal, payout handling, police-count gating, cooldowns, and random police alerts.
- JSON persistence in `data/drugs.json` with optional `oxmysql` backup table.
- Configurable progress durations, permissions, marker distance, police requirements, and default locations.
- Supports standard QBCore item APIs and optional `ox_inventory` item add/remove/carry checks.

## Dependencies

- `qb-core`
- `qb-menu`
- `qb-input`
- `qb-progressbar`
- `oxmysql` if `Config.UseDatabaseBackup = true`

## Installation

1. Copy `qb-advanced-drugs` into your server `resources` folder.
2. Import `sql/advanced_drugs.sql` if you want database backups.
3. Add the items you create to your inventory item list. At minimum, the default sample expects:

```lua
moon_sugar_leaf = { name = 'moon_sugar_leaf', label = 'Moon Sugar Leaf', weight = 100, type = 'item', image = 'moon_sugar_leaf.png', unique = false, useable = false, shouldClose = true, description = 'A strange crystalline plant.' },
moon_sugar_paste = { name = 'moon_sugar_paste', label = 'Moon Sugar Paste', weight = 100, type = 'item', image = 'moon_sugar_paste.png', unique = false, useable = false, shouldClose = true, description = 'Processed moon sugar.' },
moon_sugar_bag = { name = 'moon_sugar_bag', label = 'Bag of Moon Sugar', weight = 100, type = 'item', image = 'moon_sugar_bag.png', unique = false, useable = true, shouldClose = true, description = 'A packaged street product.' },
empty_bag = { name = 'empty_bag', label = 'Empty Bag', weight = 10, type = 'item', image = 'empty_bag.png', unique = false, useable = false, shouldClose = true, description = 'A small empty bag.' },
```

4. Add the resource to `server.cfg` after its dependencies:

```cfg
ensure qb-core
ensure qb-menu
ensure qb-input
ensure qb-progressbar
ensure oxmysql
ensure qb-advanced-drugs
```

5. Restart the server, join as an admin, and run `/drugcreator`.

## Admin workflow

1. Run `/drugcreator`.
2. Select **Create new drug** or choose an existing profile.
3. Fill in item names, recipes, payouts, effects, and coordinates.
4. Use recipe format `item:amount,item:amount`, for example `moon_sugar_leaf:4,empty_bag:1`.
5. Use coordinate format `x, y, z`, for example `1391.85, 3605.73, 38.94`.
6. Save. The resource syncs the new profile to all players and persists it to `data/drugs.json`.

## Commands

- `/drugcreator` - opens the admin creator menu.
- `/drugreload` - reloads `data/drugs.json` from disk and syncs profiles to clients.

## Notes

- This resource does **not** create inventory images or item definitions automatically. You must add item definitions to your server inventory system.
- The in-game flow is fictional and designed for roleplay servers only.
- Set `Config.MinimumPolice` above `0` if you want gathering, processing, and packaging blocked until enough on-duty police are online.
