# SpawnGuard

Garry's Mod addon for spawn-protection areas. Draw boxes with a tool gun mode and they're saved per map. Inside a box, players can't take or deal damage, and props can't be spawned or pushed in. Boxes glow as players approach.

## Installation

Put the `spawnguard` folder in `garrysmod/addons/` and restart the server. The gamemode must derive from sandbox (DarkRP does).

## Usage

**Create:** Q menu → **Tools → SpawnGuard → Spawnguard**. Left click two opposite corners (a yellow preview follows your aim), then **Confirm** or **Reject** in the popup. Reload discards a half-finished selection. If both corners are at about the same height, the box extends upward to `Config.DefaultHeight`.

**Remove:** **SpawnGuard → Spawnguard Remover**. The box you aim at or stand in turns red. Left click deletes it immediately, with no undo. Boxes behind walls can't be targeted.

Saved boxes are drawn in green while you hold either tool.

## Behavior

- **Damage:** players inside a box take no damage and deal none. A player damaged *outside* spawn in the last 5 seconds is **combat tagged**: they aren't protected and can fight back, so nobody escapes a fight by running into spawn. Damage taken inside spawn never starts the tag, and dying clears it. The HUD shows a notice in spawn, or a countdown while tagged.
- **Props:** spawning a prop into a box is refused, and props that end up in one (physgun, thrown, duped) are removed within half a second with a chat message to the owner. Map props are never removed and admins aren't exempt. Classes and sweep rate: `Config.PropClasses`, `Config.PropSweepInterval`.
- **Glow:** boxes fade in from 450 units and reach full brightness at 64, with a scrolling "SPAWN" banner on each wall. The glow is hidden while you're inside any box and while you hold a SpawnGuard tool. Players can turn it off with `spawnguard_halo 0` or under **Utilities → SpawnGuard → Client Settings**.

## Server settings

Q menu → **Utilities → SpawnGuard → Server Settings** (requires `SpawnGuard.Configure`). Changes apply immediately and are saved to `data/spawnguard/settings.json`. Only changed values are stored, so new defaults from updates still apply.

| Section | Settings |
|---|---|
| Permissions | Usergroups allowed to use the tools (default `superadmin`) |
| Protection | Godmode, no damage from inside spawn, combat tag length, prop blocking |
| Text | Protected HUD text, combat tagged HUD text, wall text |
| Colors | HUD text colors, glow color, wall text color |
| Glow | On/off, fade-in distance, full-brightness distance |

Everything else (box sizes, beam widths, popup colors) is a developer default in `sh_config.lua`, where `[setting]` marks the editable values.

## Permissions

| Permission | Allows | Default |
|---|---|---|
| `SpawnGuard.Create` | Spawnguard tool | Allowed usergroups, plus admin mod grants |
| `SpawnGuard.Remove` | Spawnguard Remover tool | Allowed usergroups, plus admin mod grants |
| `SpawnGuard.Configure` | Server Settings | superadmin |

Groups inheriting from an allowed group count too (e.g. ULX `owner` from `superadmin`). Admin mods supporting [CAMI](https://github.com/glua/CAMI) (ULX, SAM, ServerGuard, sAdmin, FAdmin…) can grant extra access. In ULX, tick the `spawnguard.*` entries under XGUI → Groups. ULX grants all three to superadmins, so removing a superadmin's tool access means unticking it there as well.

`SpawnGuard.Configure` ignores the allowed usergroups list, so tool users can't grant themselves more. The server checks permission on every action.

## Data

- Boxes: `garrysmod/data/spawnguard/<map>.json`
- Settings: `garrysmod/data/spawnguard/settings.json`

## Layout

```
lua/
├── autorun/spawnguard_init.lua      # loader: includes every file below in order
├── spawnguard/
│   ├── sh_cami.lua                  # bundled CAMI library (MIT), do not edit
│   ├── sh_config.lua                # defaults; [setting] marks values editable in game
│   ├── sh_net.lua                   # net message names
│   ├── sh_util.lua                  # notify, corners -> box, point-in-box, aimed-at box
│   ├── sh_perms.lua                 # allowed usergroups + CAMI privileges, CanTool hook
│   ├── sh_settings.lua              # editable settings schema, validation, defaults
│   ├── sv_settings.lua              # load/save/sync settings, handle panel edits
│   ├── sv_storage.lua               # load/save box data file
│   ├── sv_boxes.lua                 # saved box list, sync to clients
│   ├── sv_selection.lua             # per-player pending corners, popup answer, save/discard
│   ├── sv_props.lua                 # block/remove player props inside boxes
│   ├── sv_damage.lua                # godmode, no damage from spawn, combat tag
│   ├── cl_settings.lua              # receive settings, Server Settings panel
│   ├── cl_net.lua                   # receive pending selection, boxes, chat
│   ├── cl_render.lua                # wireframe boxes while holding the tool
│   ├── cl_halo.lua                  # proximity glow, wall text, Client Settings panel
│   ├── cl_hud.lua                   # "You are in Spawn" notice / combat countdown
│   └── cl_confirm.lua               # Confirm/Reject popup
└── weapons/gmod_tool/stools/
    ├── spawnguard.lua               # selection tool (auto-loaded by sandbox)
    └── spawnguard_remove.lua        # remover tool (auto-loaded by sandbox)
```

## Known limitations

- Only the settings listed above can be changed in game. The rest need edits to `sh_config.lua`.