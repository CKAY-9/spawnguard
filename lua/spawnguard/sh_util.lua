-- Shared helpers.

-- Send a prefixed chat message. Server: to `ply`. Client: to the local player (ply ignored).
function SpawnGuard.Notify( ply, msg )
	if SERVER then
		net.Start( SpawnGuard.Net.Notify )
		net.WriteString( msg )
		net.Send( ply )
	else
		local Config = SpawnGuard.Config
		chat.AddText( Config.ChatColor, Config.ChatPrefix, color_white, msg )
	end
end

-- Turn two arbitrary corners into ordered mins/maxs, applying the height rule
-- from the config. Used by both the server (saving) and client (preview) so
-- what you see is what gets saved.
function SpawnGuard.BoxFromCorners( a, b )
	local Config = SpawnGuard.Config

	local mins = Vector( math.min( a.x, b.x ), math.min( a.y, b.y ), math.min( a.z, b.z ) )
	local maxs = Vector( math.max( a.x, b.x ), math.max( a.y, b.y ), math.max( a.z, b.z ) )

	if maxs.z - mins.z < Config.MinHeight then
		maxs.z = mins.z + Config.DefaultHeight
	end

	return mins, maxs
end

-- True if `pos` is inside the box.
function SpawnGuard.PosInBox( pos, box )
	return pos:WithinAABox( box.mins, box.maxs )
end

-- The box in `boxes` the trace is aimed at, or nil. The ray is cut off where
-- the trace hit, so boxes behind walls aren't picked. A box containing the
-- trace start counts as hit first. Shared so the remover's client highlight
-- and server delete agree.
function SpawnGuard.BoxFromTrace( trace, boxes )
	local start = trace.StartPos
	local delta = trace.HitPos - start
	if delta:IsZero() then return end
	delta = delta + delta:GetNormalized() * 4 -- reach boxes ending exactly on the hit surface

	local best, bestFrac
	for _, box in ipairs( boxes ) do
		local frac
		if start:WithinAABox( box.mins, box.maxs ) then
			frac = 0
		else
			local hit, _, f = util.IntersectRayWithOBB( start, delta, vector_origin, angle_zero, box.mins, box.maxs )
			if hit then frac = f end
		end

		if frac and ( not bestFrac or frac < bestFrac ) then
			best, bestFrac = box, frac
		end
	end

	return best
end

-- True if `ply` is inside any box in `boxes`.
function SpawnGuard.PlayerInAnyBox( ply, boxes )
	local pos = ply:WorldSpaceCenter()
	for _, box in ipairs( boxes ) do
		if SpawnGuard.PosInBox( pos, box ) then return true end
	end
	return false
end
