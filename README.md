# SpawnGuard

A Garry's Mod addon for marking spawn-protection areas. You draw boxes in the world with a tool gun mode, and they're saved per map. Players inside a box can't be damaged, props can't be spawned or pushed in, and the boxes glow as players approach them.

## Usage

1. Open the Q menu, go to the **Tools** tab and choose **SpawnGuard → Spawnguard**.
2. **Left click** to set the first corner. A yellow box follows your aim to preview the selection.
3. **Left click** again to set the opposite corner. A "Create new Spawnguard Box" popup fades in over a dark, blurred screen and shows the box size:
   - **Confirm**: adds the box to the map's list and writes it to disk.
   - **Reject**: clears the selection, and chat tells you to shoot a new first corner.
4. **Reload** with the tool also discards a selection that has only one corner.

To delete a box, choose **SpawnGuard → Spawnguard Remover**. The box you're aiming at (or standing in) is highlighted in red, and a left click deletes it immediately. There's no confirmation and no undo. Boxes behind walls can't be targeted.

While you hold either tool, saved boxes are drawn in green. If both corners are on roughly the same height (for example, both on the floor), the box is extended upward to `Config.DefaultHeight`.

## Server settings

Server owners can change the main settings in game, in the Q menu under **Utilities → SpawnGuard → Server Settings**. Changes apply to everyone immediately and are saved on the server in `garrysmod/data/spawnguard/settings.json`. Only changed values are saved, so new defaults in addon updates still apply to everything else. A **Reset all settings to defaults** button is at the bottom.

| Section | Settings |
|---|---|
| Permissions | Usergroups allowed to use the tools (default: `superadmin`) |
| Protection | Godmode on/off, combat tag length (default 5 s), prop blocking on/off |
| Text | Protected HUD text, combat tagged HUD text, wall text |
| Colors | Protected and combat tagged HUD text colors, zone glow color, wall text color |
| Glow | Glow on/off, distance it starts appearing (default 450), distance it reaches full brightness (default 64) |

Only players with the `SpawnGuard.Configure` permission can open and use this page (see below). Box sizes are intentionally not editable in game. They and other less common values (beam widths, popup colors) are developer defaults in `sh_config.lua`. Settings marked `[setting]` there are the editable ones.

## Permissions

**Tool use:** a player can use the tools if their usergroup is in the **allowed usergroups** list, or inherits from a group in it. For example, ULX's `owner` inherits from `superadmin`. Admin mods can also grant access on top of the list through [CAMI](https://github.com/glua/CAMI), which ULX, SAM, ServerGuard, sAdmin, FAdmin and others support.

| Permission | Allows | Default |
|---|---|---|
| `SpawnGuard.Create` | Using the **Spawnguard** tool | Allowed usergroups list, plus admin mod grants |
| `SpawnGuard.Remove` | Using the **Spawnguard Remover** tool | Allowed usergroups list, plus admin mod grants |
| `SpawnGuard.Configure` | Changing **Server Settings** | superadmin |

- **ULX:** open XGUI (`!menu`), go to **Groups**, select the usergroup, and tick the `spawnguard.*` entries in its permissions list. ULX grants all three to superadmins by default, so to take tool access away from superadmins on a ULX server, untick it in ULX as well as removing `superadmin` from the list.
- **No admin mod:** only the allowed usergroups list counts for the tools, and only superadmins can change settings.

`SpawnGuard.Configure` deliberately ignores the allowed usergroups list, so people who can use the tools can't add other groups themselves. Players without permission get a chat message and nothing happens. The server checks permission on every action, so a player can't get around it from their own game.

## Damage protection

Players inside a saved box take no damage from any source. The exception is the **combat tag**: a player who took damage *outside* spawn within the last 5 seconds isn't protected yet, so nobody can escape a fight by running into spawn. Damage taken inside spawn never starts or extends the tag, and dying clears it.

Inside a box, the top-middle HUD shows "You are in Spawn. Safe from damage and props". While combat tagged, it shows "Spawn protection resumes in 3s" in orange instead. Both texts, their colors and the tag length are server settings.

## Props

Players can't spawn props inside a saved box. A spawn is refused if the player is aiming into a box, and a prop is deleted if any part of it overlaps one. Props that get into a box later are removed within half a second, and their owner gets a chat message. That covers props pushed in with the physgun, thrown in, or pasted with a dupe.

Props that are part of the map are never removed. Admins aren't exempt. By default this applies only to `prop_physics`. `Config.PropClasses` and `Config.PropSweepInterval` in `sh_config.lua` control which props and how often.

## Proximity glow

Saved boxes fade into view as a player gets close: within 450 units by default, and at full brightness within 64. Both distances are server settings. The edges glow, the walls show a soft gradient that's brightest at the floor, and the whole effect pulses slowly.

Each outside wall shows a "SPAWN" banner in glowing letters that scrolls sideways and fades in and out. Tall walls get an extra row of text for about every 1000 units of height (`Config.HaloTextRowSpacing`).

The glow is dimmer while you stand inside a box, and hidden while you hold a SpawnGuard tool, because the tool outlines show the boxes then. Players can turn it off with `spawnguard_halo 0` or in the Q menu under **Utilities → SpawnGuard → Client Settings**.

## Installation

Put the `spawnguard` folder in `garrysmod/addons/` and restart the server. Your gamemode must derive from sandbox (DarkRP does) for the tool gun mode to appear.

## Data

- Boxes: `garrysmod/data/spawnguard/<map>.json`, one file per map.
- Server settings: `garrysmod/data/spawnguard/settings.json`.

## Layout

```
spawnguard/
├── addon.json
├── lua/
│   ├── autorun/
│   │   └── spawnguard_init.lua      # loader: includes every file below in order
│   ├── spawnguard/
│   │   ├── sh_cami.lua              # bundled CAMI library (MIT), do not edit
│   │   ├── sh_config.lua            # defaults; [setting] marks values editable in game
│   │   ├── sh_net.lua               # net message names
│   │   ├── sh_util.lua              # notify, corners -> box, point-in-box, aimed-at box
│   │   ├── sh_perms.lua             # allowed usergroups + CAMI privileges, CanTool hook
│   │   ├── sh_settings.lua          # editable settings schema, validation, defaults
│   │   ├── sv_settings.lua          # load/save/sync settings, handle panel edits
│   │   ├── sv_storage.lua           # load/save box data file
│   │   ├── sv_boxes.lua             # saved box list, sync to clients
│   │   ├── sv_selection.lua         # per-player pending corners, popup answer, save/discard
│   │   ├── sv_props.lua             # block/remove player props inside boxes
│   │   ├── sv_damage.lua            # godmode in spawn + combat tag
│   │   ├── cl_settings.lua          # receive settings, Server Settings Q menu panel
│   │   ├── cl_net.lua               # receive pending selection, boxes, chat
│   │   ├── cl_render.lua            # draw wireframe boxes while holding the tool
│   │   ├── cl_halo.lua              # proximity glow, wall text, Client Settings panel
│   │   ├── cl_hud.lua               # "You are in Spawn" notice / combat countdown
│   │   └── cl_confirm.lua           # Confirm/Reject popup
│   └── weapons/gmod_tool/stools/
│       ├── spawnguard.lua           # selection tool (auto-loaded by sandbox)
│       └── spawnguard_remove.lua    # remover tool (auto-loaded by sandbox)
├── README.md
└── AGENTS.md
```

## Known limitations

- Protected players can still deal damage from inside spawn, so they could shoot out of it.
- Only the settings listed above can be changed in game. The rest need edits to `sh_config.lua`.
