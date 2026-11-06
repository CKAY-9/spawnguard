-- Proximity glow: saved boxes fade in as the local player approaches.
--   * Edges: additive beams, a thin bright core plus a wide soft glow pass.
--   * Side walls: additive gradient, brightest at the floor, fading upward.
--   * Brightness scales with distance (HaloFar -> HaloNear) and a slow pulse.
-- Hidden while holding a SpawnGuard tool (cl_render.lua draws outlines then).
-- Players can turn it off with `spawnguard_halo 0` or in the Q menu
-- (Utilities -> SpawnGuard -> Client Settings).

local cvHalo = CreateClientConVar( "spawnguard_halo", "1", true, false,
	"Show the glow around spawn zones as you approach them", 0, 1 )

-- Built from stock textures so the addon ships no material files.
-- Colors are premultiplied (rgb scaled by brightness) so the fade works with
-- additive blending whether or not it honors vertex alpha.
local wallMat = CreateMaterial( "SpawnGuardHaloWall", "UnlitGeneric", {
	[ "$basetexture" ] = "vgui/white",
	[ "$additive" ] = "1",
	[ "$vertexcolor" ] = "1",
	[ "$vertexalpha" ] = "1",
	[ "$nocull" ] = "1",
} )

-- Radial glow texture sampled at its middle column (texStart = texEnd = 0.5)
-- gives a beam that's bright in the center and soft at the sides.
local beamMat = CreateMaterial( "SpawnGuardHaloBeam", "UnlitGeneric", {
	[ "$basetexture" ] = "sprites/light_glow02",
	[ "$additive" ] = "1",
	[ "$vertexcolor" ] = "1",
	[ "$vertexalpha" ] = "1",
	[ "$nocull" ] = "1",
} )

-- Wall text: big crisp font plus a blurred copy drawn behind it as a glow.
-- Drawn large and scaled down in 3D2D so it stays sharp.
local TEXT_FONT_SIZE = 128
surface.CreateFont( "SpawnGuard.Wall", { font = "Roboto", size = TEXT_FONT_SIZE, weight = 900 } )
surface.CreateFont( "SpawnGuard.WallGlow", { font = "Roboto", size = TEXT_FONT_SIZE, weight = 900, blursize = 12 } )

local function scaled( col, k )
	return Color( col.r * k, col.g * k, col.b * k, 255 * k )
end

-- Distance from pos to the nearest point of the box (0 when inside).
local function distToBox( pos, box )
	local nearest = Vector(
		math.Clamp( pos.x, box.mins.x, box.maxs.x ),
		math.Clamp( pos.y, box.mins.y, box.maxs.y ),
		math.Clamp( pos.z, box.mins.z, box.maxs.z ) )
	return pos:Distance( nearest )
end

-- 0 beyond HaloFar, 1 within HaloNear. Ease-out in between, so it brightens
-- quickly once in range instead of staying dim until the player is close.
local function fadeFor( dist )
	local Config = SpawnGuard.Config
	if dist >= Config.HaloFar then return 0 end

	-- Both distances are server settings; if Near >= Far the fade becomes a
	-- hard edge at HaloFar instead of dividing by zero or going negative.
	local range = math.max( Config.HaloFar - Config.HaloNear, 1 )
	local t = 1 - math.Clamp( ( dist - Config.HaloNear ) / range, 0, 1 )
	return 1 - ( 1 - t ) * ( 1 - t )
end

local function wallVertex( pos, u, v, col )
	mesh.Position( pos )
	mesh.TexCoord( 0, u, v )
	mesh.Color( col.r, col.g, col.b, col.a )
	mesh.AdvanceVertex()
end

local function drawHalo( box, k )
	local Config = SpawnGuard.Config
	local mins, maxs = box.mins, box.maxs

	-- Bottom corners (counter-clockwise) and the matching top corners.
	local b = {
		Vector( mins.x, mins.y, mins.z ), Vector( maxs.x, mins.y, mins.z ),
		Vector( maxs.x, maxs.y, mins.z ), Vector( mins.x, maxs.y, mins.z ),
	}
	local t = {}
	for i = 1, 4 do t[ i ] = Vector( b[ i ].x, b[ i ].y, maxs.z ) end

	-- Side walls: bright at the base, fading to a dimmer (not invisible) top.
	local base = scaled( Config.HaloColor, k * Config.HaloWallAlpha )
	local top = scaled( Config.HaloColor, k * Config.HaloWallAlpha * Config.HaloWallTopScale )
	render.SetMaterial( wallMat )
	mesh.Begin( MATERIAL_QUADS, 4 )
	for i = 1, 4 do
		local j = i % 4 + 1
		wallVertex( b[ i ], 0, 1, base )
		wallVertex( b[ j ], 1, 1, base )
		wallVertex( t[ j ], 1, 0, top )
		wallVertex( t[ i ], 0, 0, top )
	end
	mesh.End()

	-- Edges: wide soft glow, then thin bright core.
	local glow = scaled( Config.HaloColor, k * 0.5 )
	local core = scaled( Config.HaloColor, k )
	render.SetMaterial( beamMat )
	for pass = 1, 2 do
		local width = pass == 1 and Config.HaloGlowWidth or Config.HaloCoreWidth
		local col = pass == 1 and glow or core
		for i = 1, 4 do
			local j = i % 4 + 1
			render.DrawBeam( b[ i ], b[ j ], width, 0.5, 0.5, col ) -- bottom ring
			render.DrawBeam( t[ i ], t[ j ], width, 0.5, 0.5, col ) -- top ring
			render.DrawBeam( b[ i ], t[ i ], width, 0.5, 0.5, col ) -- vertical edge
		end
	end
end

-- Outward-facing side walls: outward normal, which axis runs along the wall,
-- and which side of the box the wall sits on.
local FACES = {
	{ normal = Vector( 0, -1, 0 ), along = "x", fixed = "y", side = "mins" },
	{ normal = Vector( 1, 0, 0 ), along = "y", fixed = "x", side = "maxs" },
	{ normal = Vector( 0, 1, 0 ), along = "x", fixed = "y", side = "maxs" },
	{ normal = Vector( -1, 0, 0 ), along = "y", fixed = "x", side = "mins" },
}

-- Draw Config.HaloText as a scrolling banner on each wall that faces the
-- viewer. `a` is the overall opacity (0-1).
--   * Repeated copies slide sideways along the wall; each copy fades out
--     before touching the wall's edge, so nothing ever sticks out.
--   * Tall walls get one row per ~HaloTextRowSpacing units of height,
--     spread evenly; short walls get a single row through the middle.
local function drawWallText( box, a, eye )
	local Config = SpawnGuard.Config
	local text = Config.HaloText
	local mins, maxs = box.mins, box.maxs
	local now = CurTime()

	surface.SetFont( "SpawnGuard.Wall" )
	local textW, textH = surface.GetTextSize( text )

	local height = maxs.z - mins.z
	local rows = math.max( 1, math.Round( height / Config.HaloTextRowSpacing ) )
	local rowHeight = height / rows

	for _, face in ipairs( FACES ) do
		local center = ( mins + maxs ) / 2
		center[ face.fixed ] = box[ face.side ][ face.fixed ]

		-- Only walls whose outside faces the viewer (no mirrored text).
		if ( eye - center ):Dot( face.normal ) > 0 then
			local width = maxs[ face.along ] - mins[ face.along ]

			-- Fit: at most HaloTextHeight tall, 40% of a row's height, half the wall
			-- width (so there's room to scroll and fade at the edges).
			local worldH = math.min( Config.HaloTextHeight, rowHeight * 0.4, width * 0.5 * textH / textW )
			local scale = worldH / textH

			-- Everything below is in 3D2D units (world units / scale), origin at wall center.
			local halfW = width / scale / 2
			local halfH = height / scale / 2
			local rowLocal = rowHeight / scale
			local spacing = textW * ( 1 + Config.HaloTextGap )
			local fadeLen = math.min( textW * 0.5, halfW * 0.5 )

			local offset = ( now * Config.HaloTextScrollSpeed / scale ) % spacing

			-- Standard "text on the front of an entity" orientation for this normal.
			local ang = face.normal:Angle()
			ang:RotateAroundAxis( ang:Up(), 90 )
			ang:RotateAroundAxis( ang:Forward(), 90 )

			-- Nudge outward so the text never z-fights the wall.
			cam.Start3D2D( center + face.normal * 1, ang, scale )
				for row = 1, rows do
					local y = -halfH + ( row - 0.5 ) * rowLocal -- row centers, top to bottom

					for x = -halfW - spacing + offset, halfW + spacing, spacing do
						-- Room left between this copy's outer edge and the wall edge.
						local edgeRoom = halfW - ( math.abs( x ) + textW / 2 )
						local edgeFade = math.Clamp( edgeRoom / fadeLen, 0, 1 )

						if edgeFade > 0 then
							local alpha = 255 * a * edgeFade
							local glow = Color( Config.HaloColor.r, Config.HaloColor.g, Config.HaloColor.b, alpha )
							local core = Color( Config.HaloTextColor.r, Config.HaloTextColor.g, Config.HaloTextColor.b, alpha )
							draw.SimpleText( text, "SpawnGuard.WallGlow", x, y, glow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
							draw.SimpleText( text, "SpawnGuard.Wall", x, y, core, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
						end
					end
				end
			cam.End3D2D()
		end
	end
end

hook.Add( "PostDrawTranslucentRenderables", "SpawnGuard.Halo", function( depth, skybox )
	if skybox or depth then return end

	local Config = SpawnGuard.Config
	if not Config.HaloEnabled or not cvHalo:GetBool() then return end
	if #SpawnGuard.ClientBoxes == 0 or SpawnGuard.HeldToolMode() then return end

	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local pos = ply:WorldSpaceCenter()

	local pulse = 1
	if Config.HaloPulse then
		pulse = 0.85 + 0.15 * math.sin( CurTime() * Config.HaloPulseSpeed )
	end

	-- Text breathes between HaloTextMinAlpha and 1 on a smooth sine cycle.
	local textPulse = 1
	if Config.HaloTextEnabled then
		local s = 0.5 + 0.5 * math.sin( CurTime() * Config.HaloTextPulseSpeed )
		textPulse = Lerp( s, Config.HaloTextMinAlpha, 1 )
	end

	local eye = EyePos()

	for _, box in ipairs( SpawnGuard.ClientBoxes ) do
		local dist = distToBox( pos, box )
		local k = fadeFor( dist )
		if k > 0 then
			if dist == 0 then k = k * Config.HaloInsideScale end
			drawHalo( box, k * pulse )

			if Config.HaloTextEnabled then
				drawWallText( box, k * textPulse, eye )
			end
		end
	end
end )

-- Q menu: Utilities -> SpawnGuard -> Client Settings.
hook.Add( "PopulateToolMenu", "SpawnGuard.ClientSettings", function()
	spawnmenu.AddToolMenuOption( "Utilities", "SpawnGuard", "spawnguard_client", "Client Settings", "", "", function( panel )
		panel:ClearControls()
		panel:CheckBox( "Show spawn zone glow", "spawnguard_halo" )
		panel:ControlHelp( "Spawn zones glow as you walk up to them." )
	end )
end )
