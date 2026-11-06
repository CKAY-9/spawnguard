-- Keeps player props out of saved boxes.
--   1. PlayerSpawnProp: refuse the spawn if the player is aiming into a box
--      (before the prop exists, so DarkRP etc. never charge for it).
--   2. PlayerSpawnedProp: remove it if its bounds still overlap a box.
--   3. Periodic sweep: remove props that got in any other way (physgun,
--      thrown, duplicator / AdvDupe pastes, other addons).
-- Map-placed props are never touched.

local function notifyLimited( ply, msg )
	if not IsValid( ply ) or not ply:IsPlayer() then return end

	ply.SpawnGuardLastPropMsg = ply.SpawnGuardLastPropMsg or 0
	if CurTime() - ply.SpawnGuardLastPropMsg < 2 then return end
	ply.SpawnGuardLastPropMsg = CurTime()

	SpawnGuard.Notify( ply, msg )
end

local function isGuardedProp( ent )
	return IsValid( ent )
		and SpawnGuard.Config.PropClasses[ ent:GetClass() ] == true
		and not ent:CreatedByMap()
end

local function getOwner( ent )
	if ent.CPPIGetOwner then -- FPP / DarkRP / most prop protection addons
		local owner = ent:CPPIGetOwner()
		if IsValid( owner ) then return owner end
	end

	local creator = ent:GetCreator()
	if IsValid( creator ) then return creator end
end

-- True if the entity's world bounds overlap the box at all.
local function overlapsBox( ent, box )
	local mins, maxs = ent:WorldSpaceAABB()
	return mins.x <= box.maxs.x and maxs.x >= box.mins.x
		and mins.y <= box.maxs.y and maxs.y >= box.mins.y
		and mins.z <= box.maxs.z and maxs.z >= box.mins.z
end

local function overlapsAnyBox( ent )
	for _, box in ipairs( SpawnGuard.Boxes ) do
		if overlapsBox( ent, box ) then return true end
	end
	return false
end

local function removeProp( ent, msg )
	notifyLimited( getOwner( ent ), msg )
	ent:Remove()
end

hook.Add( "PlayerSpawnProp", "SpawnGuard.BlockProps", function( ply, model )
	if not SpawnGuard.Config.BlockProps then return end

	local pos = ply:GetEyeTrace().HitPos
	for _, box in ipairs( SpawnGuard.Boxes ) do
		if SpawnGuard.PosInBox( pos, box ) then
			notifyLimited( ply, "You can't spawn props inside a spawn zone." )
			return false
		end
	end
	-- Return nothing when allowed so other addons' hooks still get a say.
end )

hook.Add( "PlayerSpawnedProp", "SpawnGuard.BlockProps", function( ply, model, ent )
	if not SpawnGuard.Config.BlockProps then return end

	if isGuardedProp( ent ) and overlapsAnyBox( ent ) then
		removeProp( ent, "You can't spawn props inside a spawn zone." )
	end
end )

local function sweep()
	if not SpawnGuard.Config.BlockProps then return end

	for _, box in ipairs( SpawnGuard.Boxes ) do
		for _, ent in ipairs( ents.FindInBox( box.mins, box.maxs ) ) do
			if isGuardedProp( ent ) and overlapsBox( ent, box ) then
				removeProp( ent, "Your prop was removed because it entered a spawn zone." )
			end
		end
	end
end

timer.Create( "SpawnGuard.PropSweep", SpawnGuard.Config.PropSweepInterval, 0, sweep )
