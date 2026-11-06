-- Shared configuration defaults.
--
-- Values marked [setting] can be changed by server owners in game:
--   Q menu -> Utilities -> SpawnGuard -> Server Settings
-- Those changes are saved in garrysmod/data/spawnguard/settings.json and
-- override the defaults below (see sh_settings.lua). Everything else is a
-- developer default that only changes by editing this file.

SpawnGuard.Config = SpawnGuard.Config or {}
local Config = SpawnGuard.Config

Config.ChatPrefix = "[SpawnGuard] "
Config.ChatColor = Color( 80, 180, 255 )

-- [setting] Usergroups allowed to use the Spawnguard tools (groups inheriting
-- from these count too). Admin mods can also grant the CAMI permissions.
Config.AllowedGroups = { "superadmin" }

-- Box sizing. Shooting two corners on the floor gives a flat box, so any box
-- shorter than MinHeight is extended upward to DefaultHeight.
Config.MinSize = 16        -- minimum width/depth (units) of a box
Config.MinHeight = 64
Config.DefaultHeight = 128

-- Damage protection (sv_damage.lua). Players inside a box take no damage,
-- unless they were damaged outside spawn within the last CombatTagTime seconds.
Config.GodMode = true                              -- [setting]
Config.CombatTagTime = 5                           -- [setting]

-- Prop blocking (sv_props.lua). Player props of these classes can't be spawned
-- in a box and are removed if they get into one. Map-placed props are ignored.
Config.BlockProps = true                           -- [setting]
Config.PropClasses = {
	prop_physics = true,
	-- prop_ragdoll = true, -- uncomment to also keep spawned ragdolls out
}
Config.PropSweepInterval = 0.5 -- seconds between checks for props moved into boxes

-- Render colors (tool outlines).
Config.PendingColor = Color( 255, 200, 0 )         -- selection awaiting confirm/reject
Config.PendingFill = Color( 255, 200, 0, 20 )
Config.SavedColor = Color( 0, 255, 120 )           -- saved boxes (shown while holding either tool)
Config.RemoveColor = Color( 255, 60, 60 )          -- box targeted by the remover tool
Config.RemoveFill = Color( 255, 60, 60, 40 )

-- Confirm/Reject popup.
Config.UIAccent = Color( 60, 140, 255 )            -- borders, title, Confirm button
Config.UIAccentHover = Color( 95, 165, 255 )
Config.UIBackground = Color( 14, 20, 32, 245 )     -- dialog body
Config.UIButtonHover = Color( 25, 42, 70, 245 )    -- Reject button hover
Config.UIText = Color( 170, 200, 240 )

-- Proximity glow around saved boxes (cl_halo.lua). Players can also turn it
-- off for themselves with `spawnguard_halo 0` or in the Q menu.
Config.HaloEnabled = true                          -- [setting]
Config.HaloColor = Color( 60, 140, 255 )           -- [setting]
Config.HaloNear = 64                               -- [setting] full brightness within this distance (units)
Config.HaloFar = 450                               -- [setting] invisible beyond this distance
Config.HaloWallAlpha = 0.6                         -- wall brightness at the floor, relative to the edges
Config.HaloWallTopScale = 0.3                      -- wall brightness at the top, relative to the floor (0 = fade out fully)
Config.HaloInsideScale = 0.5                       -- brightness multiplier while standing inside a box
Config.HaloCoreWidth = 2                           -- edge beam widths
Config.HaloGlowWidth = 12
Config.HaloPulse = true
Config.HaloPulseSpeed = 2

-- Scrolling text on the outside of each wall, glowing in HaloColor.
Config.HaloTextEnabled = true
Config.HaloText = "SPAWN"                          -- [setting]
Config.HaloTextColor = Color( 200, 225, 255 )      -- [setting] letter color (glow uses HaloColor)
Config.HaloTextHeight = 40                         -- max letter height in world units (shrinks to fit small walls)
Config.HaloTextPulseSpeed = 1.6                    -- fade in/out speed (higher = faster)
Config.HaloTextMinAlpha = 0.15                     -- opacity at the dimmest point of the fade
Config.HaloTextScrollSpeed = 30                    -- sideways scroll speed, world units per second
Config.HaloTextGap = 0.6                           -- space between repeated words, as a fraction of word width
Config.HaloTextRowSpacing = 500                   -- one row of text per this many units of wall height

-- HUD shown to players standing inside a saved box.
Config.HUDText = "You are in Spawn. Safe from damage and props"     -- [setting]
Config.HUDColor = Color( 120, 255, 160 )                            -- [setting]
Config.HUDCombatText = "Spawn protection resumes in {time}s"        -- [setting] {time} = seconds left
Config.HUDCombatColor = Color( 255, 170, 60 )                       -- [setting]
