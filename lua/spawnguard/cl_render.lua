-- 3D rendering of the pending selection and saved boxes.
-- Drawn only while the local player holds a SpawnGuard tool mode:
--   spawnguard        -> saved boxes + pending selection
--   spawnguard_remove -> saved boxes, with the targeted one highlighted

-- Returns "spawnguard" / "spawnguard_remove" if the local player is holding
-- that tool mode, else nil. Also used by cl_halo.lua.
function SpawnGuard.HeldToolMode()
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid( wep ) or wep:GetClass() ~= "gmod_tool" then return end

	local mode = GetConVarString( "gmod_toolmode" )
	if mode == "spawnguard" or mode == "spawnguard_remove" then return mode end
end

local function drawBox( mins, maxs, line, fill )
	if fill then
		render.SetColorMaterial()
		render.DrawBox( vector_origin, angle_zero, mins, maxs, fill )
	end
	render.DrawWireframeBox( vector_origin, angle_zero, mins, maxs, line, true )
end

hook.Add( "PostDrawTranslucentRenderables", "SpawnGuard.Render", function( depth, skybox )
	if skybox then return end

	local mode = SpawnGuard.HeldToolMode()
	if not mode then return end

	local Config = SpawnGuard.Config

	local target
	if mode == "spawnguard_remove" then
		target = SpawnGuard.BoxFromTrace( LocalPlayer():GetEyeTrace(), SpawnGuard.ClientBoxes )
	end

	for _, box in ipairs( SpawnGuard.ClientBoxes ) do
		if box == target then
			drawBox( box.mins, box.maxs, Config.RemoveColor, Config.RemoveFill )
		else
			drawBox( box.mins, box.maxs, Config.SavedColor )
		end
	end

	if mode ~= "spawnguard" then return end

	local sel = SpawnGuard.ClientPending
	if not sel then return end

	-- Only one corner so far: preview the box out to wherever the player is aiming.
	local b = sel.b or LocalPlayer():GetEyeTrace().HitPos
	local mins, maxs = SpawnGuard.BoxFromCorners( sel.a, b )
	drawBox( mins, maxs, Config.PendingColor, Config.PendingFill )
end )
