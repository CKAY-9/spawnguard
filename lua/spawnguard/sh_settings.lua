-- Server-owner settings: the subset of SpawnGuard.Config that can be changed
-- in game (Q menu -> Utilities -> SpawnGuard -> Server Settings).
--
--   * Defaults come from sh_config.lua (snapshotted below at load).
--   * The server saves values that differ from the defaults to
--     data/spawnguard/settings.json and syncs all values to clients
--     (sv_settings.lua / cl_settings.lua).
--   * Values are written straight into SpawnGuard.Config, so the rest of the
--     addon just reads Config as usual.
--
-- To make another Config value editable, add it to the schema. The Q menu
-- panel is generated from this list, in this order.

local Config = SpawnGuard.Config

SpawnGuard.SettingsSchema = {
	{ key = "AllowedGroups", type = "groups", category = "Permissions", label = "Groups allowed to use the tools",
		help = "Groups that inherit from a listed group are allowed too. Admin mods can also grant SpawnGuard.Create / SpawnGuard.Remove." },

	{ key = "GodMode", type = "bool", category = "Protection", label = "Players can't be damaged inside spawn" },
	{ key = "CombatTagTime", type = "number", category = "Protection", label = "Combat tag (seconds)", min = 0, max = 60, decimals = 0,
		help = "After taking damage outside spawn, a player isn't protected in spawn for this long." },
	{ key = "BlockProps", type = "bool", category = "Protection", label = "Block and remove props inside spawn" },

	{ key = "HUDText", type = "string", category = "Text", label = "Protected text", maxLen = 100 },
	{ key = "HUDCombatText", type = "string", category = "Text", label = "Combat tagged text", maxLen = 100,
		help = "{time} is replaced with the seconds left." },
	{ key = "HaloText", type = "string", category = "Text", label = "Wall text", maxLen = 24 },

	{ key = "HUDColor", type = "color", category = "Colors", label = "Protected text color" },
	{ key = "HUDCombatColor", type = "color", category = "Colors", label = "Combat tagged text color" },
	{ key = "HaloColor", type = "color", category = "Colors", label = "Zone glow color" },
	{ key = "HaloTextColor", type = "color", category = "Colors", label = "Wall text color" },

	{ key = "HaloEnabled", type = "bool", category = "Glow", label = "Show zone glow" },
	{ key = "HaloFar", type = "number", category = "Glow", label = "Glow visible from (units)", min = 100, max = 5000, decimals = 0,
		help = "The glow starts fading in when a player is this close to a box." },
	{ key = "HaloNear", type = "number", category = "Glow", label = "Full brightness within (units)", min = 0, max = 2000, decimals = 0,
		help = "Should be less than the distance above." },
}

SpawnGuard.SettingsByKey = {}
for _, def in ipairs( SpawnGuard.SettingsSchema ) do
	SpawnGuard.SettingsByKey[ def.key ] = def
end

local GROUP_PATTERN = "^[%w_%-%.]+$"
local MAX_GROUPS = 64

-- Each validator takes an untrusted value (from JSON or the network) and
-- returns a clean value, or nil to reject it.
local validators = {
	bool = function( def, v )
		if isbool( v ) then return v end
	end,

	number = function( def, v )
		v = tonumber( v )
		if not v or v ~= v then return end -- reject nil / NaN
		v = math.Clamp( v, def.min, def.max )
		if ( def.decimals or 0 ) == 0 then v = math.Round( v ) end
		return v
	end,

	string = function( def, v )
		if not isstring( v ) then return end
		v = string.Trim( ( string.gsub( v, "%c", "" ) ) ) -- strip newlines/control chars
		local len = utf8.len( v )
		if not len then return end -- invalid UTF-8
		if len > def.maxLen then
			v = string.sub( v, 1, utf8.offset( v, def.maxLen + 1 ) - 1 )
		end
		return v
	end,

	color = function( def, v )
		if not istable( v ) then return end
		local r, g, b = tonumber( v.r ), tonumber( v.g ), tonumber( v.b )
		if not ( r and g and b ) then return end
		return Color( math.Clamp( math.Round( r ), 0, 255 ), math.Clamp( math.Round( g ), 0, 255 ),
			math.Clamp( math.Round( b ), 0, 255 ), 255 )
	end,

	groups = function( def, v )
		if not istable( v ) then return end
		local out, seen = {}, {}
		for _, g in ipairs( v ) do
			if isstring( g ) then
				g = string.Trim( g )
				if #g > 0 and #g <= 32 and string.match( g, GROUP_PATTERN ) and not seen[ g ] then
					seen[ g ] = true
					out[ #out + 1 ] = g
					if #out >= MAX_GROUPS then break end
				end
			end
		end
		return out
	end,
}

-- Clean an untrusted value for `key`. Returns nil if the key is unknown or
-- the value is invalid.
function SpawnGuard.ValidateSetting( key, value )
	local def = SpawnGuard.SettingsByKey[ key ]
	if not def then return end
	return validators[ def.type ]( def, value )
end

-- Convert a setting value into plain JSON-safe data.
function SpawnGuard.SettingToPlain( key, value )
	local def = SpawnGuard.SettingsByKey[ key ]
	if def.type == "color" then return { r = value.r, g = value.g, b = value.b } end
	if def.type == "groups" then return table.Copy( value ) end
	return value
end

local function settingsEqual( def, a, b )
	if def.type == "color" then
		return a.r == b.r and a.g == b.g and a.b == b.b
	elseif def.type == "groups" then
		if #a ~= #b then return false end
		for i = 1, #a do
			if a[ i ] ~= b[ i ] then return false end
		end
		return true
	end
	return a == b
end

-- Snapshot of the sh_config.lua defaults (deep copies via plain -> validate).
SpawnGuard.SettingDefaults = {}
for _, def in ipairs( SpawnGuard.SettingsSchema ) do
	SpawnGuard.SettingDefaults[ def.key ] = SpawnGuard.ValidateSetting( def.key,
		SpawnGuard.SettingToPlain( def.key, Config[ def.key ] ) )
end

-- Apply a table of plain values (from the settings file or the network).
-- Unknown keys and invalid values are ignored.
function SpawnGuard.ApplySettings( data )
	for _, def in ipairs( SpawnGuard.SettingsSchema ) do
		local value = SpawnGuard.ValidateSetting( def.key, data[ def.key ] )
		if value ~= nil then Config[ def.key ] = value end
	end
end

-- Plain table of current values. With onlyChanged, leaves out values equal
-- to their defaults (so future default changes still reach this server).
function SpawnGuard.ExportSettings( onlyChanged )
	local out = {}
	for _, def in ipairs( SpawnGuard.SettingsSchema ) do
		local value = Config[ def.key ]
		if not onlyChanged or not settingsEqual( def, value, SpawnGuard.SettingDefaults[ def.key ] ) then
			out[ def.key ] = SpawnGuard.SettingToPlain( def.key, value )
		end
	end
	return out
end

function SpawnGuard.ResetSettings()
	for _, def in ipairs( SpawnGuard.SettingsSchema ) do
		Config[ def.key ] = SpawnGuard.ValidateSetting( def.key,
			SpawnGuard.SettingToPlain( def.key, SpawnGuard.SettingDefaults[ def.key ] ) )
	end
end
