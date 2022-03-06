-- Usage: wireshark -X lua_script:sysclk-lwla-dissector.lua
--
-- It is not advisable to install this dissector globally, since
-- it will try to interpret the communication of any USB device
-- using the vendor-specific interface class.
--
-- inspired by the sigrok lwla decoder

p_jlink = Proto("jlink", "jlink USB Protocol")

-- known jlink commands.  Sourced from "RM08001-R2 Reference manual for J-Link USB Protocol 2008"
-- expanded from libjaylink
local command_types = {
	-- TODO - make better FSM wrapping, this is just a "how many in's are expected..."
    [0x00] = "EMU_CMD_SERVER",
    [0x01] = "EMU_CMD_GET_VERSION",
    [0x05] = "EMU_CMD_SET_SPEED",
    [0x07] = "EMU_CMD_CLIENT",
    [0x07] = "EMU_CMD_GET_HW_STATUS",
    [0x08] = "EMU_CMD_SET_TARGET_POWER",
    [0x09] = "EMU_CMD_REGISTER",
    [0x1e] = "EMU_CMD_FILE_IO",
    [0xc0] = "EMU_CMD_GET_SPEEDS",
    [0xc1] = "EMU_CMD_GET_HW_INFO",
    [0xc2] = "EMU_CMD_GET_COUNTERS",
    [0xc7] = "EMU_CMD_SELECT_TIF",
    [0xce] = "EMU_CMD_JTAG_IO_V2",
    [0xcf] = "EMU_CMD_JTAG_IO_V3",
    [0xcf] = "EMU_CMD_SWD_IO",
    [0xd4] = "EMU_CMD_GET_FREE_MEMORY",
    [0xdc] = "EMU_CMD_CLEAR_RESET",
    [0xdd] = "EMU_CMD_SET_RESET",
    [0xde] = "EMU_CMD_JTAG_CLEAR_TRST",
    [0xdf] = "EMU_CMD_JTAG_SET_TRST",
    [0xe8] = "EMU_CMD_GET_CAPS",
    [0xeb] = "EMU_CMD_SWO",
    [0xed] = "EMU_CMD_GET_EXT_CAPS",
    [0xee] = "EMU_CMD_EMUCOM",
    [0xf0] = "EMU_CMD_GET_HW_VERSION",
    [0xf2] = "EMU_CMD_READ_CONFIG",
    [0xf3] = "EMU_CMD_WRITE_CONFIG",
}

local emucom_cmds = {
    [0] = "READ",
    [1] = "WRITE",
}

p_jlink.fields.command = ProtoField.uint8("jlink.command", "Command Type", base.HEX, command_types)
p_jlink.fields.emucom_cmd = ProtoField.uint8("jlink.emucom.cmd", "EMUCOM Command", base.DEC, emucom_cmds)
p_jlink.fields.emucom_chan = ProtoField.uint32("jlink.emucom.chan", "EMUCOM Channel", base.HEX)
p_jlink.fields.emucom_len = ProtoField.uint32("jlink.emucom.len", "EMUCOM Length", base.DEC)
p_jlink.fields.unknown  = ProtoField.bytes("jlink.unknown", "Unidentified message data")

-- Referenced USB URB dissector fields.
local f_urb_type = Field.new("usb.urb_type")
local f_transfer_type = Field.new("usb.transfer_type")
local f_endpoint = Field.new("usb.endpoint_address.number")
local f_endpoint_dir = Field.new("usb.endpoint_address.direction")

-- Things we want to reference...
local f_e_cmd = Field.new("jlink.emucom.cmd")
local f_e_chan = Field.new("jlink.emucom.chan")
local f_e_len = Field.new("jlink.emucom.len")

function p_jlink.dissector(tvb, pinfo, tree)

	local transfer_type = f_transfer_type().value
	local ep = f_endpoint().value
	local ep_dir = f_endpoint_dir().value -- 0 == out, 1 =0 in
	--print("ep, epdir, with types", ep, tostring(type(ep)), ep_dir, tostring(type(ep_dir)))
	assert(transfer_type==3) -- we're onyl adding ourselves to the bulk table right now.... duh
	--assert(ep == 3) - no, depends very much on config, msc, msc+cdc, don't try this.

	pinfo.cols.protocol = p_jlink.name
	local subtree = tree:add(p_jlink, tvb(), "JLink")

    local info_s = "unknown"

	if ep_dir == 0 then
		local cmd = tvb(0,1):uint()
		subtree:add(p_jlink.fields.command, tvb(0,1))
		local mode = command_types[cmd]
		info_s = mode and mode or string.format("unknown out: %d(0x%02x)", cmd, cmd)
		-- set expected to mode[1]....
                if mode == "EMU_CMD_EMUCOM" then
                    subtree:add(p_jlink.fields.emucom_cmd, tvb(1,1))
                    subtree:add_le(p_jlink.fields.emucom_chan, tvb(2,4))
                    subtree:add_le(p_jlink.fields.emucom_len, tvb(6,4))
                    info_s = string.format("%s %s ch: %x len: %d", mode, f_e_cmd().display, f_e_chan().value, f_e_len().value)
                end
	else
		-- directin == in.  should be in the other mode now.... bump the state machine :)
        info_s = "unknown in"
	end
    pinfo.cols.info:set(info_s)



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
