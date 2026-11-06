-- Client-side receivers. Client never decides anything; it only stores what to draw.

SpawnGuard.ClientPending = SpawnGuard.ClientPending or nil -- { a = Vector, b = Vector|nil } or nil
SpawnGuard.ClientBoxes = SpawnGuard.ClientBoxes or {}

net.Receive( SpawnGuard.Net.Pending, function()
	local sel
	if net.ReadBool() then
		sel = { a = net.ReadVector() }
		if net.ReadBool() then sel.b = net.ReadVector() end
	end

	SpawnGuard.ClientPending = sel
	SpawnGuard.UpdateConfirm()
end )

net.Receive( SpawnGuard.Net.Boxes, function()
	local boxes = {}
	for i = 1, net.ReadUInt( 16 ) do
		boxes[ i ] = {
			id = net.ReadUInt( 32 ),
			mins = net.ReadVector(),
			maxs = net.ReadVector(),
		}
	end
	SpawnGuard.ClientBoxes = boxes
end )

net.Receive( SpawnGuard.Net.Notify, function()
	SpawnGuard.Notify( nil, net.ReadString() )
end )

hook.Add( "InitPostEntity", "SpawnGuard.RequestSync", function()
	net.Start( SpawnGuard.Net.RequestSync )
	net.SendToServer()
end )
