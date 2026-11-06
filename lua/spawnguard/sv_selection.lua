-- Per-player pending selection (the box being drawn with the tool).
--
-- SpawnGuard.Pending[ply] = { a = Vector, b = Vector|nil }
-- Flow: SetCorner(a) -> SetCorner(b) -> client popup (cl_confirm.lua)
--       -> Net.Resolve -> SaveSelection / DiscardSelection.
-- The client opens the popup whenever it receives a pending selection with
-- both corners, so SyncPending is what shows it.

SpawnGuard.Pending = SpawnGuard.Pending or {}

function SpawnGuard.GetPending( ply )
	return SpawnGuard.Pending[ ply ]
end

-- Send this player's pending corners to them.
function SpawnGuard.SyncPending( ply )
	local sel = SpawnGuard.Pending[ ply ]

	net.Start( SpawnGuard.Net.Pending )
	net.WriteBool( sel ~= nil )
	if sel then
		net.WriteVector( sel.a )
		net.WriteBool( sel.b ~= nil )
		if sel.b then net.WriteVector( sel.b ) end
	end
	net.Send( ply )
end

-- Called by the tool on each left click. Fills corner A, then B.
-- Returns true if a corner was set (so the tool shows its effect).
function SpawnGuard.SetCorner( ply, pos )
	local sel = SpawnGuard.Pending[ ply ]

	if sel and sel.b then
		-- Re-send so the popup reopens if it was somehow closed.
		SpawnGuard.SyncPending( ply )
		SpawnGuard.Notify( ply, "Confirm or reject your current box first." )
		return false
	end

	if not sel then
		SpawnGuard.Pending[ ply ] = { a = pos }
		SpawnGuard.Notify( ply, "First corner set. Shoot the opposite corner." )
		SpawnGuard.SyncPending( ply )
		return true
	end

	local minSize = SpawnGuard.Config.MinSize
	if math.abs( pos.x - sel.a.x ) < minSize or math.abs( pos.y - sel.a.y ) < minSize then
		SpawnGuard.Notify( ply, "That box is too small. Shoot a corner further from the first one." )
		return false
	end

	sel.b = pos
	SpawnGuard.SyncPending( ply ) -- opens the confirm popup on the client
	return true
end

-- Save the completed selection as a box.
function SpawnGuard.SaveSelection( ply )
	local sel = SpawnGuard.Pending[ ply ]
	if not sel or not sel.b then
		SpawnGuard.Notify( ply, "You don't have a completed box to save. Shoot two corners with the Spawnguard tool first." )
		return
	end

	local mins, maxs = SpawnGuard.BoxFromCorners( sel.a, sel.b )
	local box = SpawnGuard.AddBox( mins, maxs, ply )

	SpawnGuard.Pending[ ply ] = nil
	SpawnGuard.SyncPending( ply )
	SpawnGuard.Notify( ply, "Saved spawn box #" .. box.id .. " (" .. #SpawnGuard.Boxes .. " on this map). Shoot a corner to start another." )
end

-- Throw away the selection and tell the player what they can do next.
function SpawnGuard.DiscardSelection( ply )
	if not SpawnGuard.Pending[ ply ] then
		SpawnGuard.Notify( ply, "Nothing to discard." )
		return
	end

	SpawnGuard.Pending[ ply ] = nil
	SpawnGuard.SyncPending( ply )
	SpawnGuard.Notify( ply, "Selection discarded. Shoot the first corner of a new box to try again." )
end

-- Popup answer. Ignored unless the player actually has a completed selection.
net.Receive( SpawnGuard.Net.Resolve, function( _, ply )
	local sel = SpawnGuard.Pending[ ply ]
	if not sel or not sel.b then return end

	-- Permission may have been revoked since the corners were set.
	if not SpawnGuard.CheckPermission( ply, SpawnGuard.Privileges.Create ) then
		SpawnGuard.Pending[ ply ] = nil
		SpawnGuard.SyncPending( ply )
		return
	end

	if net.ReadBool() then
		SpawnGuard.SaveSelection( ply )
	else
		SpawnGuard.DiscardSelection( ply )
	end
end )

hook.Add( "PlayerDisconnected", "SpawnGuard.ClearPending", function( ply )
	SpawnGuard.Pending[ ply ] = nil
end )
