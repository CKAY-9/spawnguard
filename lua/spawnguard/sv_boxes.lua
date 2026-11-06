-- Saved box list management.
--
-- Box format (stored in SpawnGuard.Boxes and the data file):
-- {
--     id      = number,  -- unique per map
--     mins    = Vector,  -- ordered min corner
--     maxs    = Vector,  -- ordered max corner
--     creator = string,  -- SteamID64 of the player who saved it
--     created = number,  -- os.time()
-- }

local function nextId()
	local max = 0
	for _, box in ipairs( SpawnGuard.Boxes ) do
		if box.id > max then max = box.id end
	end
	return max + 1
end

function SpawnGuard.AddBox( mins, maxs, ply )
	local box = {
		id = nextId(),
		mins = mins,
		maxs = maxs,
		creator = IsValid( ply ) and ply:SteamID64() or "",
		created = os.time(),
	}

	table.insert( SpawnGuard.Boxes, box )
	SpawnGuard.SaveBoxes()
	SpawnGuard.SyncBoxes()

	return box
end

function SpawnGuard.RemoveBox( id )
	for i, box in ipairs( SpawnGuard.Boxes ) do
		if box.id == id then
			table.remove( SpawnGuard.Boxes, i )
			SpawnGuard.SaveBoxes()
			SpawnGuard.SyncBoxes()
			return true
		end
	end
	return false
end

-- Send saved boxes to `target` (player, table of players, or nil = everyone).
function SpawnGuard.SyncBoxes( target )
	net.Start( SpawnGuard.Net.Boxes )
	net.WriteUInt( #SpawnGuard.Boxes, 16 )
	for _, box in ipairs( SpawnGuard.Boxes ) do
		net.WriteUInt( box.id, 32 )
		net.WriteVector( box.mins )
		net.WriteVector( box.maxs )
	end

	if target then net.Send( target ) else net.Broadcast() end
end

-- Clients ask once they've finished loading (sending on PlayerInitialSpawn can
-- arrive before the client is ready). Sends saved boxes and server settings
-- (SyncSettings is in sv_settings.lua). Light rate limit to prevent spam.
local lastRequest = {}

net.Receive( SpawnGuard.Net.RequestSync, function( _, ply )
	local now = CurTime()
	if lastRequest[ ply ] and now - lastRequest[ ply ] < 5 then return end
	lastRequest[ ply ] = now

	SpawnGuard.SyncSettings( ply )
	SpawnGuard.SyncBoxes( ply )
end )

hook.Add( "PlayerDisconnected", "SpawnGuard.ClearRequest", function( ply )
	lastRequest[ ply ] = nil
end )

-- Lua autorefresh: push the reloaded list to anyone already connected.
if #player.GetHumans() > 0 then SpawnGuard.SyncBoxes() end
