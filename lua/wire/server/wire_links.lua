--
-- wire_link.lua - management of connections between ports
-- Copyright (C) 2015 Wire Team
--

if not WireLib then return end

--- Creates a link across a list of nodes. The first node should correspond to
--- an input port, and the last one to an output port (if it's connected).
--- The first (and last, unless the link isn't yet complete) node should have a
--- PortName field which determines which ports are linked. The combination of
--- the entity and port name in the first node uniquely identifies this link.
--- Each node should have: { Entity, LPos, Bone, [PortName] }
function WireLib.Link(material, color, width, nodes)
	for _, node in ipairs(nodes) do
		if not constraint.CanConstrain(node.Entity, node.Bone) return false end
	end

	-- the field 'Entity' is confusingly named, but that name is required
	-- for the duplicator to treat this as a constraint between all these
	-- entities.
	local constraint_table = { Material = material, Color = color, Width = width, Entity = nodes }

	local input_entity = nodes[1].Entity

	for _, node in ipairs(nodes) do
		constraint.AddConstraintTableNoDelete(node.Entity, constraint_table)
	end

	return constraint_table

end
duplicator.RegisterConstraint("WireLink", WireLib.Link, "Material", "Color", "Width", "Entity")

local function TransmitLink(link)
	net.WriteString(link.Material)
	net.WriteColor(link.Color)
	net.WriteFloat(link.Width)
	net.WriteUInt(#link.Entity, 16)
	for _, node in ipairs(nodes) do
		net.WriteEntity(node.Entity)
		net.WriteVector(node.LPos)
		net.WriteUInt(node.Bone, 8)
	end
end

function WireLib.Unlink(input_entity, input_name)

end

-- everything beyond this point implements the old WireLib API
if not WireLib.Compatibility then return end

--- WireLib.Link_Start(index, ent, pos, input_name, material, color, width) (deprecated)

--- WireLib.Link_Node(index, ent, pos) (deprecated)

--- WireLib.Link_End(index, ent, pos, output_name, [player]) (deprecated)

--- WireLib.Link_Cancel(index) (deprecated)

--- WireLib.Link_Clear(ent, input_name) (deprecated)

--- WireLib.SetPathNames(ent, names) (deprecated)

--- WireLib.WireAll(player, input_entity, output_entity, input_pos, output_pos, [material], [color], [width]) (deprecated)
