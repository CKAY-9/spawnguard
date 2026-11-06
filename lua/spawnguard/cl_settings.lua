-- Client side of server-owner settings: receives values from the server and
-- builds the admin panel at Q menu -> Utilities -> SpawnGuard -> Server Settings.
-- The panel is generated from SpawnGuard.SettingsSchema (sh_settings.lua).
-- Every edit is sent to the server, which validates, saves and re-syncs it
-- to everyone; the panel then refreshes from that sync.

local DEBOUNCE = 0.3 -- seconds; sliders and color pickers fire constantly while dragging

net.Receive( SpawnGuard.Net.Settings, function()
	local data = util.JSONToTable( net.ReadString(), false, true )
	if istable( data ) then SpawnGuard.ApplySettings( data ) end
	SpawnGuard.RefreshSettingsPanel()
end )

local function send( key, value )
	net.Start( SpawnGuard.Net.SetSetting )
	net.WriteString( key )
	net.WriteString( util.TableToJSON( { v = SpawnGuard.SettingToPlain( key, value ) } ) )
	net.SendToServer()
end

local function timerId( key )
	return "SpawnGuard.Setting." .. key
end

local function sendDebounced( key, value )
	timer.Create( timerId( key ), DEBOUNCE, 1, function() send( key, value ) end )
end

-- One builder per setting type. Each adds its controls to `panel` and returns
-- { Refresh = function( value ) } to show a new server value. Refresh skips
-- controls the player is in the middle of editing.
local builders = {}

function builders.bool( panel, def )
	local cb = panel:CheckBox( def.label )
	local syncing = false

	local function refresh( value )
		syncing = true
		cb:SetChecked( value )
		syncing = false
	end
	refresh( SpawnGuard.Config[ def.key ] )

	function cb:OnChange( value )
		if not syncing then send( def.key, value ) end
	end

	return { Refresh = refresh }
end

function builders.number( panel, def )
	local slider = panel:NumSlider( def.label, nil, def.min, def.max, def.decimals or 0 )
	local syncing = false

	local function refresh( value )
		if slider:IsEditing() or timer.Exists( timerId( def.key ) ) then return end
		syncing = true
		slider:SetValue( value )
		syncing = false
	end
	refresh( SpawnGuard.Config[ def.key ] )

	function slider:OnValueChanged( value )
		if not syncing then sendDebounced( def.key, value ) end
	end

	return { Refresh = refresh }
end

function builders.string( panel, def )
	local entry = panel:TextEntry( def.label )
	entry:SetValue( SpawnGuard.Config[ def.key ] )

	-- Send on Enter or when the field loses focus, if it actually changed.
	local function commit()
		local value = entry:GetValue()
		if value ~= SpawnGuard.Config[ def.key ] then send( def.key, value ) end
	end

	entry.OnEnter = commit
	local baseLoseFocus = entry.OnLoseFocus
	function entry:OnLoseFocus()
		if baseLoseFocus then baseLoseFocus( self ) end
		commit()
	end

	return {
		Refresh = function( value )
			if not entry:IsEditing() then entry:SetValue( value ) end
		end,
	}
end

function builders.color( panel, def )
	panel:Help( def.label )

	local mixer = vgui.Create( "DColorMixer" )
	mixer:SetPalette( false )
	mixer:SetAlphaBar( false )
	mixer:SetWangs( true )
	mixer:SetTall( 140 )
	panel:AddItem( mixer )

	local syncing = false

	local function refresh( value )
		if timer.Exists( timerId( def.key ) ) then return end
		syncing = true
		mixer:SetColor( value )
		syncing = false
	end
	refresh( SpawnGuard.Config[ def.key ] )

	function mixer:ValueChanged( col )
		if not syncing then sendDebounced( def.key, Color( col.r, col.g, col.b ) ) end
	end

	return { Refresh = refresh }
end

function builders.groups( panel, def )
	panel:Help( def.label )

	local list = vgui.Create( "DListView" )
	list:SetTall( 100 )
	list:SetMultiSelect( false )
	list:AddColumn( "Usergroup" )
	panel:AddItem( list )

	local function add( name )
		name = string.Trim( name or "" )
		if name == "" then return end

		local groups = table.Copy( SpawnGuard.Config[ def.key ] )
		if table.HasValue( groups, name ) then return end
		groups[ #groups + 1 ] = name
		send( def.key, groups )
	end

	-- Dropdown of groups the admin mod knows about (rebuilt each time it opens).
	local PLACEHOLDER = "Add an existing usergroup..."
	local combo = vgui.Create( "DComboBox" )
	combo:SetValue( PLACEHOLDER )

	local baseOpenMenu = combo.OpenMenu
	function combo:OpenMenu( ... )
		self:Clear()
		self:SetValue( PLACEHOLDER )
		local names = table.GetKeys( CAMI.GetUsergroups() )
		table.sort( names )
		for _, name in ipairs( names ) do self:AddChoice( name ) end
		return baseOpenMenu( self, ... )
	end

	function combo:OnSelect( _, value )
		add( value )
		self:SetValue( PLACEHOLDER )
	end
	panel:AddItem( combo )

	-- Free text for groups not registered with CAMI.
	local entry = vgui.Create( "DTextEntry" )
	entry:SetPlaceholderText( "Or type a usergroup name" )
	local addButton = vgui.Create( "DButton" )
	addButton:SetText( "Add" )
	function addButton:DoClick()
		add( entry:GetValue() )
		entry:SetValue( "" )
	end
	entry.OnEnter = function() addButton:DoClick() end
	panel:AddItem( entry, addButton )

	local removeButton = panel:Button( "Remove selected group" )
	function removeButton:DoClick()
		local _, line = list:GetSelectedLine()
		if not IsValid( line ) then return end

		local groups = table.Copy( SpawnGuard.Config[ def.key ] )
		table.RemoveByValue( groups, line:GetColumnText( 1 ) )
		send( def.key, groups )
	end

	local function refresh( groups )
		list:Clear()
		for _, name in ipairs( groups ) do list:AddLine( name ) end
	end
	refresh( SpawnGuard.Config[ def.key ] )

	return { Refresh = refresh }
end

local function canConfigure()
	return SpawnGuard.HasPermission( LocalPlayer(), SpawnGuard.Privileges.Configure )
end

function SpawnGuard.BuildSettingsPanel( panel )
	SpawnGuard.SettingsPanel = panel
	SpawnGuard.SettingsControls = nil
	panel:ClearControls()

	panel.SpawnGuardLocked = not canConfigure()
	if panel.SpawnGuardLocked then
		panel:Help( "Only players with the SpawnGuard.Configure permission (superadmin by default) "
			.. "can change server settings." )
		return
	end

	panel:Help( "Changes apply to everyone immediately and are saved on the server." )

	local controls = {}
	local category

	for _, def in ipairs( SpawnGuard.SettingsSchema ) do
		if def.category ~= category then
			category = def.category
			local header = panel:Help( category )
			header:SetFont( "DermaDefaultBold" )
		end

		controls[ def.key ] = builders[ def.type ]( panel, def )
		if def.help then panel:ControlHelp( def.help ) end
	end

	local reset = panel:Button( "Reset all settings to defaults" )
	function reset:DoClick()
		Derma_Query( "Reset every SpawnGuard server setting to its default?", "SpawnGuard",
			"Reset", function()
				net.Start( SpawnGuard.Net.ResetSettings )
				net.SendToServer()
			end,
			"Cancel" )
	end

	SpawnGuard.SettingsControls = controls
end

-- Called after every settings sync. Rebuilds the panel if the player's
-- permission changed since it was built; otherwise updates values in place.
function SpawnGuard.RefreshSettingsPanel()
	local panel = SpawnGuard.SettingsPanel
	if not IsValid( panel ) then return end

	if panel.SpawnGuardLocked == canConfigure() then
		SpawnGuard.BuildSettingsPanel( panel )
		return
	end

	for key, control in pairs( SpawnGuard.SettingsControls or {} ) do
		control.Refresh( SpawnGuard.Config[ key ] )
	end
end

hook.Add( "PopulateToolMenu", "SpawnGuard.ServerSettings", function()
	spawnmenu.AddToolMenuOption( "Utilities", "SpawnGuard", "spawnguard_server", "Server Settings", "", "",
		SpawnGuard.BuildSettingsPanel )
end )
