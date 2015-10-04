--
-- wire_ports.lua - management of input/output ports on entities
-- Copyright (C) 2015 Wire Team
--

if not WireLib then return end

WireLib.Types = {
	NORMAL = { Zero = 0 },
	VECTOR = { Zero = Vector() },
	ANGLE = { Zero = Angle() },
	COLOR = { Zero = Color() },
	ENTITY = { Zero = NULL },
	STRING = { Zero = "" },
	TABLE = { Zero = {} },
	ANY = { Zero = nil }
}

--- Copies any fields which are in `base` and not `table` into `table`. Returns `table`.
local function inherit(table, base)
	for k, v in pairs(base) do
		if table[k] == nil then
			table[k] = istable(v) and table.Copy(v) or v
		end
	end
	return table
end

--- Given an old-style port string, in the format:
---   "Name (optional description) [optional type]"
--- return a table with this information parsed.
local function ParsePortString(port)
	local name, desc, type = port:match("^(.+)( %((.*)%))?( %[(.*)%])?$")
	return { Name = name, Desc = desc, Type = type }
end

--- Given a table containing either old-style port strings or port tables,
--- parse any port strings that need parsing, add any necessary fields, and
--- return a table where the keys are port names and the values are port tables.
local function ParsePorts(ports)
	local parsed_ports = {}
	for port_name, port in pairs(ports) do
		if type(port) == "string" then port = ParsePortString(port) end

		port.Name = port.Name or port_name
		assert(type(port.Name) == "string")
		port.Type = port.Type or "NORMAL"
		port.Value = port.Value or WireLib.Types[port.Type].Zero
		port = inherit(port, default_port)

		parsed_ports[port.Name] = port
	end
	return parsed_ports
end

local function PortSetter(port_category)
	if port_category.Setter then return port_category.Setter end
	if port_category.EntityModifier then
		duplicator.RegisterEntityModifier(port_category.EntityModifier,
			function(player, entity, data) return port_category.Setter(entity, data) end)
	end
	port_category.Setter = function(entity, port_name, port)
		-- TODO support old-style port strings
		if istable(port_name) and port == nil then port, port_name = port_name, port.Name end
		assert(port_name == port.Name and type(input_name) == "string")

		local ports = entity[port_category.Field]

		if port == nil then -- remove the existing port
			port_category.Disconnector(entity, port_name)
			ports[port_name] = nil
		elseif ports[port_name] then -- update the existing port
			if port.Type ~= ports[port_name].Type then
				port_category.Disconnector(entity, port_name)
			end
			table.Merge(ports[port_name], port)
		else -- create a new port
			ports[port_name] = inherit(port, port_category.Default)
		end

		ports[port_name].Value = ports[port_name].Value or WireLib.Types[port.Type].Zero

		if port_category.EntityModifier then
			duplicator.StoreEntityModifier(entity, port_category.EntityModifier, ports)
		end
	end
	return port_category.Setter
end

local function PortListSetter(port_category)
	if port_category.ListSetter then return port_category.ListSetter end
	port_category.ListSetter = function(entity, ports)
		ports = ParsePorts(ports)
		for name, port in pairs(entity[port_category.Field]) do
			if not ports[name] then port_category.Setter(entity, name, nil) end
		end

		for name, port in pairs(ports) do port_category.Setter(entity, name, port) end
	end
	return port_category.ListSetter
end

-- Most handling of ports is identical between input and output ports, so we
-- avoid code duplication by just separating out the relevant differences into
-- a table.
local port_categories = {
	Inputs = {
		Field = "Inputs",
		Disconnector = WireLib.DisconnectInput,
		Default = { Material = "tripmine_laser", Color = Color(255, 255, 255, 255), Width = 1 },
		EntityModifier = "WireInputs"
	},

	Outputs = {
		Field = "Outputs"
		Disconnector = WireLib.DisconnectOutput,
		Default = { TriggerLimit = 8, Connected = {} },
		EntityModifier = "WireOutputs"
	}
}

--- WireLib.SetInput(entity, [input_name,] input)
--- Creates, updates or removes the input `input_name` on `entity`. If the input
--- is updated and still has the same type, the wire to this input will be
--- preserved. `input_name` is optional, and is taken from `input.Name` if it
--- is not specified.
WireLib.SetInput = PortSetter(port_categories.Inputs)

--- WireLib.SetOutput(entity, [output_name,] output)
--- Creates, updates or removes the output `output_name` on `entity`. If the
--- output is updated and still has the same type, all wires form this output
--- will be preserved. `output_name` is optional, and is taken from
--- `output.Name` if it is not specified.
WireLib.SetOutput = PortSetter(port_categories.Outputs)

--- WireLib.SetInputs(entity, inputs)
--- Updates the inputs on `entity` to be only those specified in `inputs`. All
--- wires will be preserved where possible. Each field in `inputs` can either
--- be a port table, or an old-style "Name (description) [type]" string.
--- The keys of `inputs` are only important if a port table has no name.
WireLib.SetInputs = PortListSetter(port_categories.Inputs)

--- WireLib.SetOutputs(entity, inputs)
--- Updates the outputs on `entity` to be only those specified in `outputs`. All
--- wires will be preserved where possible. Each field in `outputs` can either
--- be a port table, or an old-style "Name (description) [type]" string.
--- The keys of `outputs` are only used if a port table has no name.
WireLib.SetOutputs = PortListSetter(port_categories.Outputs)

--- WireLib.RemovePorts(entity)
--- Remove all ports on `entity`.
function WireLib.RemovePorts(entity)
	for _, category in pairs(port_categories) do
		category.ListSetter(entity, {})
	end
end

-- everything beyond this point implements the old WireLib API
if not WireLib.Compatibility then return end

local function ParseOldPorts(names, types, descs)
	types, descs = types or {}, descs or {}
	local ports = {}
	for index, name in pairs(names) do
		port = ParsePortString(name)
		port.Desc = port.Desc or descs[index]
		port.Type = port.Type or types[index]
		ports[name] = port
	end
	return ports
end

local function CreateSpecialPorts(port_category)
	return function(ent, names, types, descs)
		for _, port in pairs(ParseOldPorts(names, types, descs)) do
			port_category.Setter(ent, port)
		end
	end
end

--- WireLib.CreateSpecialInputs(ent, names, types, descs) (deprecated)
WireLib.CreateSpecialInputs = CreateSpecialPorts(port_categories.Inputs)

--- WireLib.CreateSpecialOutputs(ent, names, types, descs) (deprecated)
WireLib.CreateSpecialOutputs = CreateSpecialPorts(port_categories.Outputs)

local function AdjustSpecialPorts(port_category)
	return function(ent, names, types, descs)
		port_category.ListSetter(ent, ParseOldPorts(names, types, descs))
	end
end

--- WireLib.AdjustSpecialInputs(ent, names, types, descs) (deprecated)
WireLib.AdjustSpecialInputs = AdjustSpecialPorts(port_categories.Inputs)

--- WireLib.AdjustSpecialOutputs(ent, names, types, descs) (deprecated)
WireLib.AdjustSpecialOutputs = AdjustSpecialPorts(port_categories.Outputs)

local function RetypePort(port_category)
	return function(ent, name, type, desc)
		if not ent[port_category.Field] then return end
		for _, port in pairs(ParseOldPorts({ name }, { type }, { desc })) do
			port_category.Setter(ent, port)
		end
	end
end

--- WireLib.RetyeInputs(ent, name, type, desc) (deprecated)
WireLib.RetypeInputs = RetypePort(port_categories.Inputs)

--- WireLib.RetypeOutputs(ent, name, type, desc) (deprecated)
WireLib.RetypeOutputs = RetypePort(port_categories.Outputs)

--- WireLib.Remove(ent) (deprecated)
WireLib.Remove = WireLib.RemovePorts


function WireLib.CreateInputs(ent, names, descs) -- (deprecated)
	return WireLib.CreateSpecialInputs(ent, names, {}, descs)
end

function WireLib.CreateOutputs(ent, names, descs) -- (deprecated)
	return WireLib.CreateSpecialOutputs(ent, names, {}, descs)
end

function WireLib.AdjustInputs(ent, names, descs) -- (deprecated)
	return WireLib.AdjustSpecialInputs(ent, names, {}, descs)
end

function WireLib.AdjustOutputs(ent, names, descs) -- (deprecated)
	return WireLib.AdjustSpecialOutputs(ent, names, {}, descs)
end

Wire_CreateInputs = WireLib.CreateInputs  -- (deprecated)
Wire_CreateOutputs = WireLib.CreateOutputs  -- (deprecated)
Wire_AdjustInputs = WireLib.AdjustInputs  -- (deprecated)
Wire_AdjustOutputs = WireLib.AdjustOutputs  -- (deprecated)
