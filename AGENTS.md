# AGENTS.md

Garry's Mod addon written in Lua. See README.md for usage, the file layout and what isn't built yet.

## Conventions
- The file prefix sets the realm: `sh_` is shared, `sv_` is server, `cl_` is client. Only `lua/autorun/spawnguard_init.lua` loads files, so add every new file to its `files` list.
- The exceptions are the tool gun modes in `lua/weapons/gmod_tool/stools/` (`spawnguard.lua` creates boxes, `spawnguard_remove.lua` deletes them). Sandbox loads them automatically, so don't include them yourself. Keep them thin and have them call `SpawnGuard.*` functions.
- All state lives under the global `SpawnGuard` table. Settings live in `SpawnGuard.Config`, with defaults in `sh_config.lua`.
- Server-owner settings: values listed in `SpawnGuard.SettingsSchema` (`sh_settings.lua`) can be edited in game and override the `sh_config.lua` defaults at runtime. To make another value editable, add a schema entry (type `bool`/`number`/`string`/`color`/`groups`) and mark it `[setting]` in `sh_config.lua`. The Q menu panel is generated from the schema. Never trust values from the network or the settings file without passing them through `SpawnGuard.ValidateSetting`.
- The server is authoritative. It holds each player's pending corners (`SpawnGuard.Pending`) and the saved boxes (`SpawnGuard.Boxes`). Clients only hold copies to draw (`ClientPending`, `ClientBoxes`).
- Permissions use CAMI privileges defined in `sh_perms.lua` (`SpawnGuard.Privileges`). For Create/Remove, `Config.AllowedGroups` also grants access and replaces CAMI's no-admin-mod fallback. Configure is CAMI-only. Every server entry point that acts for a player must call `SpawnGuard.CheckPermission( ply, priv )`, including tool clicks and net receivers. The `CanTool` hook is not enough, because another addon's hook can return first. The `SpawnGuard.*` functions themselves don't check permissions. `sh_cami.lua` is a vendored third-party file, so don't edit it; update it by replacing it with a newer upstream copy.
- `SpawnGuard.BoxFromCorners` and `SpawnGuard.BoxFromTrace` are shared so what the client draws matches what the server does. That means the preview matches the saved box, and the red highlight is the box that gets deleted. Change sizing and targeting only in these two functions.
- Net message names are defined in `sh_net.lua` (`SpawnGuard.Net`). Don't hardcode the strings anywhere else.
- Data is saved to `garrysmod/data/spawnguard/<map>.json` by `sv_storage.lua`. The box format is documented at the top of `sv_boxes.lua`, so update it there when it changes.
- Style: tabs, and spaces inside parentheses (`foo( a, b )`), which matches Garry's Mod/Facepunch Lua.
- There is no test runner. Syntax check with `luac5.1 -p $(find lua -name '*.lua')`, then run a GMod server and watch the console for Lua errors.
