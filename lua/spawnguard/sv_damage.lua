-- Damage protection: players inside a saved box take no damage, unless they
-- were damaged OUTSIDE spawn within the last Config.CombatTagTime seconds
-- (so nobody can escape a fight by running into spawn).
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

hook.Add( "EntityTakeDamage", "SpawnGuard.GodMode", function( target, dmg )
	if target:IsPlayer() and SpawnGuard.IsProtected( target ) then
		return true -- block the damage
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
