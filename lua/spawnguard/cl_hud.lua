-- Top-middle notice shown while the local player stands inside a saved box.
-- While combat tagged (damaged outside spawn recently, see sv_damage.lua) it
-- shows a countdown until protection resumes instead.

surface.CreateFont( "SpawnGuard.HUD", {
	font = "Roboto",
	size = 28,
	weight = 700,
} )

hook.Add( "HUDPaint", "SpawnGuard.HUD", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	if not SpawnGuard.PlayerInAnyBox( ply, SpawnGuard.ClientBoxes ) then return end

	local Config = SpawnGuard.Config
	local text, color = Config.HUDText, Config.HUDColor

	local tagLeft = ply:GetNWFloat( "SpawnGuard.CombatUntil", 0 ) - CurTime()
	if Config.GodMode and tagLeft > 0 then
		text = string.Replace( Config.HUDCombatText, "{time}", tostring( math.ceil( tagLeft ) ) )
		color = Config.HUDCombatColor
	end

	if text == "" then return end

	draw.SimpleTextOutlined( text, "SpawnGuard.HUD", ScrW() / 2, ScrH() * 0.03,
		color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black )
end )
