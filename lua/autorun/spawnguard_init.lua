-- SpawnGuard loader. This is the ONLY file that includes/AddCSLuaFile's other files.
-- Prefix decides realm: sh_ = shared, sv_ = server only, cl_ = client only.

SpawnGuard = SpawnGuard or {}
SpawnGuard.Boxes = SpawnGuard.Boxes or {} -- saved boxes for the current map

local DIR = "spawnguard/"

-- Load order matters: libraries and config/net names first, then logic.
local files = {
	"sh_cami.lua", -- bundled third-party library (MIT); self-versioning, newest copy on the server wins
	"sh_config.lua",
	"sh_net.lua",
	"sh_util.lua",
	"sh_perms.lua",
	"sh_settings.lua", -- snapshots sh_config.lua defaults; keep after sh_config

	"sv_settings.lua", -- loads saved settings before anything else uses Config
	"sv_storage.lua",
	"sv_boxes.lua",
	"sv_selection.lua",
	"sv_props.lua",
	"sv_damage.lua",

	"cl_settings.lua",
	"cl_net.lua",
	"cl_render.lua",
	"cl_halo.lua",
	"cl_hud.lua",
	"cl_confirm.lua",
}

for _, name in ipairs( files ) do
	local prefix = string.sub( name, 1, 3 )
	local path = DIR .. name

	if prefix == "sh_" then
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	elseif prefix == "sv_" then
		if SERVER then include( path ) end
	elseif prefix == "cl_" then
		if SERVER then AddCSLuaFile( path ) else include( path ) end
	end
end
