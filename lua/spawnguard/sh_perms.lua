-- Permissions.
--
-- Tool use (Create / Remove) is allowed if EITHER:
--   * the player's usergroup, or a group it inherits from, is in
--     Config.AllowedGroups (a server setting, superadmin by default), or
--   * an admin mod grants the CAMI privilege (ULX: XGUI -> Groups).
-- Changing server settings (Configure) is CAMI-only: superadmin by default,
-- grantable in any CAMI admin mod. It deliberately ignores AllowedGroups so
-- people in that list can't add more groups themselves.

SpawnGuard.Privileges = {
	Create = "SpawnGuard.Create",
	Remove = "SpawnGuard.Remove",
	Configure = "SpawnGuard.Configure",
}

CAMI.RegisterPrivilege( {
	Name = SpawnGuard.Privileges.Create,
	MinAccess = "superadmin",
	Description = "Create spawn protection boxes with the Spawnguard tool",
} )

CAMI.RegisterPrivilege( {
	Name = SpawnGuard.Privileges.Remove,
	MinAccess = "superadmin",
	Description = "Delete spawn protection boxes with the Spawnguard Remover tool",
} )

CAMI.RegisterPrivilege( {
	Name = SpawnGuard.Privileges.Configure,
	MinAccess = "superadmin",
	Description = "Change SpawnGuard server settings from the Q menu",
} )

-- Privileges that the AllowedGroups list also grants.
local GROUP_LIST_PRIVILEGES = {
	[ SpawnGuard.Privileges.Create ] = true,
	[ SpawnGuard.Privileges.Remove ] = true,
}

-- Tool mode -> privilege needed to use it.
SpawnGuard.ToolPrivileges = {
	spawnguard = SpawnGuard.Privileges.Create,
	spawnguard_remove = SpawnGuard.Privileges.Remove,
}

-- True if the player's usergroup is in AllowedGroups or inherits from one
-- (CAMI knows the inheritance chains of ULX/SAM/etc. groups).
function SpawnGuard.InAllowedGroup( ply )
	local group = ply:GetUserGroup()
	for _, allowed in ipairs( SpawnGuard.Config.AllowedGroups ) do
		if group == allowed or CAMI.UsergroupInherits( group, allowed ) then return true end
	end
	return false
end

-- Last CAMI answer per player/privilege. Most admin mods answer immediately,
-- but CAMI allows async answers; for those we use the last known answer
-- (false until the first one arrives) so callers can stay synchronous.
local cache = setmetatable( {}, { __mode = "k" } )

function SpawnGuard.HasPermission( ply, priv )
	if not IsValid( ply ) then return false end

	local usesGroupList = GROUP_LIST_PRIVILEGES[ priv ]
	if usesGroupList and SpawnGuard.InAllowedGroup( ply ) then return true end

	local entry = cache[ ply ]
	if not entry then
		entry = {}
		cache[ ply ] = entry
	end

	CAMI.PlayerHasAccess( ply, priv, function( has, reason )
		-- With no admin mod installed, CAMI's built-in fallback grants by
		-- MinAccess (superadmin). For tool privileges the AllowedGroups list
		-- replaces that fallback, so removing superadmin from it works.
		if usesGroupList and reason == "Fallback." then has = false end
		entry[ priv ] = has == true
	end )

	return entry[ priv ] == true
end

-- HasPermission + a (rate-limited) chat message on the server when denied.
-- Use this at every server entry point that acts for a player.
local lastDenied = setmetatable( {}, { __mode = "k" } )

function SpawnGuard.CheckPermission( ply, priv )
	if SpawnGuard.HasPermission( ply, priv ) then return true end

	if SERVER and IsValid( ply ) then
		local now = CurTime()
		if not lastDenied[ ply ] or now - lastDenied[ ply ] > 1 then
			lastDenied[ ply ] = now
			SpawnGuard.Notify( ply, "You don't have permission to do that." )
		end
	end

	return false
end

-- Block the tool modes outright for players without the privilege. On the
-- client this only stops the shot effect; the server checks are what count.
-- Returning nil (not true) when allowed leaves other CanTool hooks (FPP,
-- DarkRP, ...) free to block it for their own reasons.
hook.Add( "CanTool", "SpawnGuard.Permissions", function( ply, trace, mode )
	local priv = SpawnGuard.ToolPrivileges[ mode ]
	if priv and not SpawnGuard.CheckPermission( ply, priv ) then return false end
end )
