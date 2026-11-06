-- Network message names. Registered server-side; referenced by both realms.

SpawnGuard.Net = {
	Pending = "SpawnGuard.Pending",             -- sv -> cl: player's pending corners
	Boxes = "SpawnGuard.Boxes",                 -- sv -> cl: full list of saved boxes
	Notify = "SpawnGuard.Notify",               -- sv -> cl: chat message
	Settings = "SpawnGuard.Settings",           -- sv -> cl: all server settings (JSON)
	RequestSync = "SpawnGuard.RequestSync",     -- cl -> sv: send boxes + settings once loaded
	Resolve = "SpawnGuard.Resolve",             -- cl -> sv: popup answer (bool: true = confirm)
	SetSetting = "SpawnGuard.SetSetting",       -- cl -> sv: change one server setting
	ResetSettings = "SpawnGuard.ResetSettings", -- cl -> sv: reset all server settings
}

if SERVER then
	for _, name in pairs( SpawnGuard.Net ) do
		util.AddNetworkString( name )
	end
end
