-- Tool gun mode for deleting saved boxes. Shows as "Spawnguard Remover" under
-- the SpawnGuard category in the Q menu's Tools tab.
-- The targeted box is highlighted in cl_render.lua; shooting deletes it with
-- no confirmation.

TOOL.Category = "SpawnGuard"
TOOL.Name = "#tool.spawnguard_remove.name"

TOOL.Information = {
	{ name = "left" },
}

if CLIENT then
	language.Add( "tool.spawnguard_remove.name", "Spawnguard Remover" )
	language.Add( "tool.spawnguard_remove.desc", "Delete saved spawn protection boxes" )
	language.Add( "tool.spawnguard_remove.left", "Delete the highlighted box" )
end

function TOOL:LeftClick( trace )
	if CLIENT then
		-- Only play the tool effect if there's something to delete.
		return SpawnGuard.BoxFromTrace( trace, SpawnGuard.ClientBoxes ) ~= nil
	end

	-- Authoritative check; CanTool (sh_perms.lua) usually blocks before this.
	local ply = self:GetOwner()
	if not SpawnGuard.CheckPermission( ply, SpawnGuard.Privileges.Remove ) then return false end

	local box = SpawnGuard.BoxFromTrace( trace, SpawnGuard.Boxes )
	if not box then return false end

	SpawnGuard.RemoveBox( box.id )
	SpawnGuard.Notify( ply, "Removed spawn box #" .. box.id .. " (" .. #SpawnGuard.Boxes .. " left on this map)." )
	return true
end

function TOOL:RightClick( trace )
	return false
end

function TOOL.BuildCPanel( panel )
	panel:Help( "#tool.spawnguard_remove.desc" )
	panel:Help( "Saved boxes show in green while you hold this tool. The box you're aiming at turns red; "
		.. "left click to delete it immediately. There is no undo." )
end
