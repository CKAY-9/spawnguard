-- Confirm/Reject popup shown once a selection has both corners.
-- Opened/closed from the Pending net message (cl_net.lua) via UpdateConfirm,
-- so it always mirrors the server's state. Buttons send Net.Resolve; the
-- server then saves or discards and syncs the cleared selection back.

local FADE_IN = 0.25
local FADE_OUT = 0.15

surface.CreateFont( "SpawnGuard.UITitle", { font = "Roboto", size = 26, weight = 700 } )
surface.CreateFont( "SpawnGuard.UIText", { font = "Roboto", size = 17, weight = 500 } )
surface.CreateFont( "SpawnGuard.UIButton", { font = "Roboto", size = 20, weight = 600 } )

-- Lua autorefresh: drop any popup built by the old code.
if IsValid( SpawnGuard.ConfirmPanel ) then SpawnGuard.ConfirmPanel:Remove() end

local function makeButton( parent, text, filled, onClick )
	local btn = vgui.Create( "DButton", parent )
	btn:SetText( "" )
	btn.DoClick = onClick

	function btn:Paint( w, h )
		local Config = SpawnGuard.Config
		local hovered = self:IsHovered()
		local textColor

		if filled then
			draw.RoundedBox( 6, 0, 0, w, h, hovered and Config.UIAccentHover or Config.UIAccent )
			textColor = color_white
		else
			draw.RoundedBox( 6, 0, 0, w, h, Config.UIAccent )
			draw.RoundedBox( 6, 2, 2, w - 4, h - 4, hovered and Config.UIButtonHover or Config.UIBackground )
			textColor = Config.UIAccent
		end

		draw.SimpleText( text, "SpawnGuard.UIButton", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	return btn
end

function SpawnGuard.CloseConfirm()
	local panel = SpawnGuard.ConfirmPanel
	if not IsValid( panel ) or panel.closing then return end

	panel.closing = true
	panel:SetMouseInputEnabled( false )
	panel:SetKeyboardInputEnabled( false )
	panel:AlphaTo( 0, FADE_OUT, 0, function()
		if IsValid( panel ) then panel:Remove() end
	end )
end

local function respond( confirm )
	net.Start( SpawnGuard.Net.Resolve )
	net.WriteBool( confirm )
	net.SendToServer()

	SpawnGuard.CloseConfirm()
end

function SpawnGuard.OpenConfirm()
	local existing = SpawnGuard.ConfirmPanel
	if IsValid( existing ) and not existing.closing then return end

	-- Fullscreen backdrop: blur + dark tint, fades in.
	local backdrop = vgui.Create( "EditablePanel" )
	backdrop:SetSize( ScrW(), ScrH() )
	backdrop:SetPos( 0, 0 )
	backdrop:MakePopup()
	backdrop:SetAlpha( 0 )
	backdrop:AlphaTo( 255, FADE_IN )
	backdrop.startTime = SysTime()

	function backdrop:Paint( w, h )
		Derma_DrawBackgroundBlur( self, self.startTime )
		surface.SetDrawColor( 0, 0, 0, 160 )
		surface.DrawRect( 0, 0, w, h )
	end

	-- Dialog box.
	local dialog = vgui.Create( "DPanel", backdrop )
	dialog:SetSize( 420, 190 )
	dialog:Center()

	function dialog:Paint( w, h )
		local Config = SpawnGuard.Config
		draw.RoundedBox( 8, 0, 0, w, h, Config.UIAccent )
		draw.RoundedBox( 8, 2, 2, w - 4, h - 4, Config.UIBackground )
		draw.SimpleText( "Create new Spawnguard Box", "SpawnGuard.UITitle", w / 2, 38, Config.UIAccent,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

		local sel = SpawnGuard.ClientPending
		if sel and sel.b then
			local mins, maxs = SpawnGuard.BoxFromCorners( sel.a, sel.b )
			local size = maxs - mins
			draw.SimpleText( string.format( "%d x %d x %d units", size.x, size.y, size.z ), "SpawnGuard.UIText",
				w / 2, 72, Config.UIText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	local btnW, btnH, gap = 160, 42, 20
	local btnY = dialog:GetTall() - btnH - 28
	local left = ( dialog:GetWide() - btnW * 2 - gap ) / 2

	local confirm = makeButton( dialog, "Confirm", true, function() respond( true ) end )
	confirm:SetSize( btnW, btnH )
	confirm:SetPos( left, btnY )

	local reject = makeButton( dialog, "Reject", false, function() respond( false ) end )
	reject:SetSize( btnW, btnH )
	reject:SetPos( left + btnW + gap, btnY )

	SpawnGuard.ConfirmPanel = backdrop
end

-- Show the popup exactly when the selection is complete.
function SpawnGuard.UpdateConfirm()
	local sel = SpawnGuard.ClientPending
	if sel and sel.b then
		SpawnGuard.OpenConfirm()
	else
		SpawnGuard.CloseConfirm()
	end
end
