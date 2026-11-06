-- Persistence: garrysmod/data/spawnguard/<map>.json
-- File contents: JSON array of boxes (format documented in sv_boxes.lua).

local DIR = "spawnguard"

local function path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

-- util.JSONToTable normally restores Vectors, but accept "[x y z]" / "x y z"
-- strings too in case the file was hand-edited.
local function toVector( v )
	if isvector( v ) then return v end
	if isstring( v ) then
		local x, y, z = string.match( v, "([%d%.%-e]+)%s+([%d%.%-e]+)%s+([%d%.%-e]+)" )
		if x then return Vector( tonumber( x ), tonumber( y ), tonumber( z ) ) end
	end
end

function SpawnGuard.LoadBoxes()
	SpawnGuard.Boxes = {}

	local raw = file.Read( path(), "DATA" )
	if not raw or raw == "" then return end

	local data = util.JSONToTable( raw )
	if not istable( data ) then
		ErrorNoHalt( "[SpawnGuard] Could not parse " .. path() .. ", starting with no boxes\n" )
		return
	end

	for _, box in ipairs( data ) do
		local mins, maxs = toVector( box.mins ), toVector( box.maxs )
		if mins and maxs then
			box.mins, box.maxs = mins, maxs
			box.id = tonumber( box.id ) or ( #SpawnGuard.Boxes + 1 )
			table.insert( SpawnGuard.Boxes, box )
		end
	end

	print( "[SpawnGuard] Loaded " .. #SpawnGuard.Boxes .. " box(es) for " .. game.GetMap() )
end

function SpawnGuard.SaveBoxes()
	file.CreateDir( DIR )
	file.Write( path(), util.TableToJSON( SpawnGuard.Boxes, true ) )
end

SpawnGuard.LoadBoxes()
