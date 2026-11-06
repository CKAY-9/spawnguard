-- Damage protection: players inside a saved box take no damage, unless they
-- were damaged OUTSIDE spawn within the last Config.CombatTagTime seconds
-- (so nobody can escape a fight by running into spawn).
--
-- With Config.NoSpawnAttacks, players inside a box also deal no damage to
-- anything (so spawn can't be used as a firing position). Combat tagged
-- players are exempt so they can fight back while unprotected.
--
-- The tag end time is a networked float so the client HUD can show a
-- countdown. Damage taken inside spawn never starts or extends the tag.

local TAG_NW = "SpawnGuard.CombatUntil"

local function inSpawn( ply )
	return SpawnGuard.PlayerInAnyBox( ply, SpawnGuard.Boxes )
end

function SpawnGuard.IsCombatTagged( ply )
	return CurTime() < ply:GetNWFloat( TAG_NW, 0 )
end

-- True if the player is currently protected from damage.
function SpawnGuard.IsProtected( ply )
	return SpawnGuard.Config.GodMode and inSpawn( ply ) and not SpawnGuard.IsCombatTagged( ply )
end

-- True if damage this player causes should be blocked.
function SpawnGuard.IsDisarmed( ply )
	return SpawnGuard.Config.NoSpawnAttacks and inSpawn( ply ) and not SpawnGuard.IsCombatTagged( ply )
end

hook.Add( "EntityTakeDamage", "SpawnGuard.GodMode", function( target, dmg )
	if target:IsPlayer() and SpawnGuard.IsProtected( target ) then
		return true -- block the damage
	end

	-- The attacker is the player for bullets, melee, explosives and vehicles.
	local attacker = dmg:GetAttacker()
	if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= target and SpawnGuard.IsDisarmed( attacker ) then
		return true
	end
end )

-- PostEntityTakeDamage only reports damage that actually went through
-- (`took`), so blocked or zero damage never tags anyone.
hook.Add( "PostEntityTakeDamage", "SpawnGuard.CombatTag", function( ent, dmg, took )
	if not took or not ent:IsPlayer() or inSpawn( ent ) then return end
	ent:SetNWFloat( TAG_NW, CurTime() + SpawnGuard.Config.CombatTagTime )
end )

-- A fresh life starts untagged.
hook.Add( "PlayerSpawn", "SpawnGuard.ClearCombatTag", function( ply )
	ply:SetNWFloat( TAG_NW, 0 )
end )
