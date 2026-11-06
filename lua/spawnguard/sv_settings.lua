-- Server side of server-owner settings (schema and validation in sh_settings.lua).
-- Persistence: garrysmod/data/spawnguard/settings.json (changed values only).

local PATH = "spawnguard/settings.json"

function SpawnGuard.LoadSettings()
	local raw = file.Read( PATH, "DATA" )
	if not raw or raw == "" then return end

	-- ignoreConversions: keep strings like "[1 2 3]" as strings, not Vectors.
	local data = util.JSONToTable( raw, false, true )
	if not istable( data ) then
		ErrorNoHalt( "[SpawnGuard] Could not parse " .. PATH .. ", using default settings\n" )
		return
	end

	SpawnGuard.ApplySettings( data )
end

function SpawnGuard.SaveSettings()
	file.CreateDir( "spawnguard" )
	file.Write( PATH, util.TableToJSON( SpawnGuard.ExportSettings( true ), true ) )
end

-- Send all current values to `target` (player, table of players, or nil = everyone).
function SpawnGuard.SyncSettings( target )
	net.Start( SpawnGuard.Net.Settings )
	net.WriteString( util.TableToJSON( SpawnGuard.ExportSettings( false ) ) )
	if target then net.Send( target ) else net.Broadcast() end
end

-- One setting changed from the Q menu panel. Value arrives as JSON { v = ... }.
net.Receive( SpawnGuard.Net.SetSetting, function( _, ply )
	if not SpawnGuard.CheckPermission( ply, SpawnGuard.Privileges.Configure ) then return end

	local key = net.ReadString()
	if not SpawnGuard.SettingsByKey[ key ] then return end

	local wrapped = util.JSONToTable( net.ReadString(), false, true )
	if not istable( wrapped ) then return end

	local value = SpawnGuard.ValidateSetting( key, wrapped.v )
	if value == nil then return end

	SpawnGuard.Config[ key ] = value
	SpawnGuard.SaveSettings()
	SpawnGuard.SyncSettings()

	MsgN( string.format( "[SpawnGuard] %s (%s) changed setting %s", ply:Nick(), ply:SteamID(), key ) )
end )

net.Receive( SpawnGuard.Net.ResetSettings, function( _, ply )
	if not SpawnGuard.CheckPermission( ply, SpawnGuard.Privileges.Configure ) then return end

	SpawnGuard.ResetSettings()
	SpawnGuard.SaveSettings()
	SpawnGuard.SyncSettings()

	SpawnGuard.Notify( ply, "All server settings were reset to their defaults." )
	MsgN( string.format( "[SpawnGuard] %s (%s) reset all settings", ply:Nick(), ply:SteamID() ) )
end )

SpawnGuard.LoadSettings()

-- Lua autorefresh: push to anyone already connected.
if #player.GetHumans() > 0 then SpawnGuard.SyncSettings() end
