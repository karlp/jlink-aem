-- Usage: wireshark -X lua_script:sysclk-lwla-dissector.lua
--
-- It is not advisable to install this dissector globally, since
-- it will try to interpret the communication of any USB device
-- using the vendor-specific interface class.
--
-- inspired by the sigrok lwla decoder

p_jlink = Proto("jlink", "jlink USB Protocol")

-- known jlink commands.  Sourced from "RM08001-R2 Reference manual for J-Link USB Protocol 2008"
local command_types = {
	-- TODO - make better FSM wrapping, this is just a "how many in's are expected..."
    [0x1] = {"EMU_CMD_VERSION", 2}
    [0xc0] = {"EMU_CMD_GET_SPEEDS", 1}
    [0xd4] = {"EMU_CMD_GET_MAX_MEM_BLOCK", 1}
    [0xe8] = {"EMU_CMD_GET_CAPS", 1}
    [0xed] = {"EMU_CMD_GET_EXT_CAPS", 1}
    [0xf0] = {"EMU_CMD_GET_HW_VERSION", 1}
}


p_jlink.fields.command = ProtoField.uint8("jlink.command", "Command Type", base.HEX, command_types)
p_jlink.fields.unknown  = ProtoField.bytes("lwla.unknown", "Unidentified message data")

-- Referenced USB URB dissector fields.
local f_urb_type = Field.new("usb.urb_type")
local f_transfer_type = Field.new("usb.transfer_type")
local f_endpoint = Field.new("usb.endpoint_address.number")
local f_endpoint_dir = Field.new("usb.endpoint_address.direction")

-- Insert warning for undecoded leftover data.
local function warn_undecoded(tree, range)
    local item = tree:add(p_jlink.fields.unknown, range)
    item:add_expert_info(PI_UNDECODED, PI_WARN, "Leftover data")
end

function p_jlink.dissector(tvb, pinfo, tree)

	local transfer_type = f_transfer_type().value
	local ep = f_endpoint().value
	local ep_dir = f_endpoint_dir().value -- 0 == out, 1 =0 in
	print("ep, epdir, with types", ep, tostring(type(ep)), ep_dir, tostring(type(ep_dir)))
	assert(transfer_type==3) -- we're onyl adding ourselves to the bulk table right now.... duh
	assert(ep == 3)

	pinfo.cols.protocol = p_jlink.name
	local subtree = tree:add(p_jlink, tvb(), "Jlink")

	if ep_dir == 0 then
		local cmd = tvb(0,1):uint()
		print("cmd = ", cmd, type(cmd))
		subtree:add(p_jlink.fields.command, tvb(0,1)):set_generated()
		local mode = command_types[cmd]
		pinfo.cols.info:set(mode[0])
		-- set expected to mode[1]....
	else
		-- directin == in.  should be in the other mode now.... bump the state machine :)
	end



	return 0
end

-- Register protocol dissector during initialization.
function p_jlink.init()
    --local usb_product_dissectors = DissectorTable.get("usb.product")

    -- Dissection by vendor+product ID requires that Wireshark can get the
    -- the device descriptor.  Making a USB device available inside VirtualBox
    -- will make it inaccessible from Linux, so Wireshark cannot fetch the
    -- descriptor by itself.  However, it is sufficient if the VirtualBox
    -- guest requests the descriptor once while Wireshark is capturing.
    --usb_product_dissectors:add(0x13660105, p_jlink) -- incomplete list...

    -- Addendum: Protocol registration based on product ID does not always
    -- work as desired.  Register the protocol on the interface class instead.
    -- The downside is that it would be a bad idea to put this into the global
    -- configuration, so one has to make do with -X lua_script: for now.
    local usb_bulk_dissectors = DissectorTable.get("usb.bulk")

    -- For some reason the "unknown" class ID is sometimes 0xFF and sometimes
    -- 0xFFFF.  Register both to make it work all the time.
    usb_bulk_dissectors:add(0xFF, p_jlink)
    usb_bulk_dissectors:add(0xFFFF, p_jlink)
end
