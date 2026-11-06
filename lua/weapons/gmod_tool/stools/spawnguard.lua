-- Tool gun mode. Shows as "Spawnguard" under the SpawnGuard category in the
-- Q menu's Tools tab, and on the tool gun screen.
-- Auto-loaded by the sandbox tool gun; do NOT include it from spawnguard_init.lua.
-- Keep logic out of here: forward to SpawnGuard.* server functions.

TOOL.Category = "SpawnGuard"
TOOL.Name = "#tool.spawnguard.name"

-- Stage = how far along the selection is: 0 none, 1 first corner, 2 complete.
-- The tool gun's on-screen help shows only entries for the current stage.
TOOL.Information = {
	{ name = "left_0", stage = 0 },
	{ name = "left_1", stage = 1 },
	{ name = "info_2", stage = 2 },
	{ name = "reload" },
}

if CLIENT then
	language.Add( "tool.spawnguard.name", "Spawnguard" )
	language.Add( "tool.spawnguard.desc", "Mark spawn protection boxes" )
	language.Add( "tool.spawnguard.left_0", "Set the first corner" )
	language.Add( "tool.spawnguard.left_1", "Set the opposite corner" )
	language.Add( "tool.spawnguard.info_2", "Confirm or reject the box in the popup" )
	language.Add( "tool.spawnguard.reload", "Discard the current selection" )
end

-- Permission is also checked in the CanTool hook (sh_perms.lua); the checks
-- here are the authoritative ones in case another CanTool hook allows it first.
function TOOL:LeftClick( trace )
	if CLIENT then return true end

	local ply = self:GetOwner()
	if not SpawnGuard.CheckPermission( ply, SpawnGuard.Privileges.Create ) then return false end

	return SpawnGuard.SetCorner( ply, trace.HitPos )
end

function TOOL:RightClick( trace )
	return false
end

function TOOL:Reload( trace )
	if CLIENT then return true end
	local ply = self:GetOwner()
	if not SpawnGuard.GetPending( ply ) then return false end

	SpawnGuard.DiscardSelection( ply )
	return true
end

-- Keep the stage in sync with the server-side selection, which can also be
-- changed from the confirm popup.
function TOOL:Think()
	if CLIENT then return end

	local sel = SpawnGuard.GetPending( self:GetOwner() )
	local stage = sel and ( sel.b and 2 or 1 ) or 0
	if self:GetStage() ~= stage then self:SetStage( stage ) end
end

function TOOL.BuildCPanel( panel )
	panel:Help( "#tool.spawnguard.desc" )
	panel:Help( "1. Left click to set the first corner of a box.\n"
		.. "2. Left click again to set the opposite corner.\n"
		.. "3. Click Confirm in the popup to save it, or Reject to throw it away.\n\n"
		.. "Reload also discards the current selection. Saved boxes show in green while you hold this tool." )
end
