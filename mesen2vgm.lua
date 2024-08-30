--[[
mesen2vgm.lua
--]]

if not (emu.getState()["consoleType"] == "Gameboy" or emu.getState()["consoleType"] == "Gba") then
	emu.displayMessage("Script", "Game Boy (including Advance) is only supported for now")
	return
end

if not io then
	emu.displayMessage("Script", "IO access is blocked")
	return
end

local function getSeconds()
	return emu.getState()["masterClock"] / (emu.getState()["clockRate"] * (60/59.72750056960583))
end

local vgm_handle = nil
local is_logging = false
local start_vgm_frame = 0
local total_frames = 0

function readPSGMemGB(address)
	return emu.read(address, emu.memType.gameboyMemory, false)
end

function writeCallbackGB(address, value)
	local state = emu.getState()
	local seconds = getSeconds()
	local vgm_frame = math.floor(seconds*44100)
	local frame_difference = vgm_frame - start_vgm_frame
	
	emu.drawString(50, 0, tostring(seconds))
	emu.drawString(50, 9, tostring(state["frameCount"] / 60))--59.72750056960583))
	emu.drawString(50, 18, tostring(vgm_frame))
	emu.drawString(0, 0 + ((address-0xFF10)*9), string.format("[%04X] %02X", address, value))
	
	if frame_difference ~= 0 then
		total_frames = total_frames + frame_difference
		
		vgm_handle:write(string.char(0x61))
		vgm_handle:write(string.char(frame_difference & 0xFF))
		vgm_handle:write(string.char((frame_difference >> 8) & 0xFF))
	end
	start_vgm_frame = vgm_frame
	vgm_handle:write(string.char(0xB3))
	vgm_handle:write(string.char(address - 0xFF10))
	if value > 0xFF then
		emu.log("Warning: written value is bigger than 255 (" .. value .. ")")
	end
	vgm_handle:write(string.char(value % 256))
	return value + 0
end

function readGBAPSGFromGBAddress(address)
	local out_address = 0
	
	if address == 0xFF10 then out_address = 0x4000060
	elseif address == 0xFF11 then out_address = 0x4000062
	elseif address == 0xFF12 then out_address = 0x4000063
	elseif address == 0xFF13 then out_address = 0x4000064
	elseif address == 0xFF14 then out_address = 0x4000065
	elseif address == 0xFF16 then out_address = 0x4000068
	elseif address == 0xFF17 then out_address = 0x4000069
	elseif address == 0xFF18 then out_address = 0x400006C
	elseif address == 0xFF19 then out_address = 0x400006D
	elseif address == 0xFF1A then out_address = 0x4000070
	elseif address == 0xFF1B then out_address = 0x4000072
	elseif address == 0xFF1C then out_address = 0x4000073
	elseif address == 0xFF1D then out_address = 0x4000074
	elseif address == 0xFF1E then out_address = 0x4000075
	elseif address == 0xFF20 then out_address = 0x4000078
	elseif address == 0xFF21 then out_address = 0x4000079
	elseif address == 0xFF22 then out_address = 0x400007C
	elseif address == 0xFF23 then out_address = 0x400007D
	elseif address == 0xFF24 then out_address = 0x4000080
	elseif address == 0xFF25 then out_address = 0x4000081
	elseif address == 0xFF26 then out_address = 0x4000084
	elseif address >= 0xFF30 and address <= 0xFF3F then
		out_address = (address - 0xFF30) + 0x4000090
	else
		return 0
	end
	
	return emu.read(out_address, emu.memType.gbaMemory, false) & 0xFF
end

function writeCallbackGBA(address, value)
	local address_out = 0
	local value_out = value % 256
	if address == 0x4000060 then -- NR10
		address_out = 0xFF10
	elseif address == 0x4000062 then -- NR11
		address_out = 0xFF11
	elseif address == 0x4000063 then -- NR12
		address_out = 0xFF12
	elseif address == 0x4000064 then -- NR13
		address_out = 0xFF13
	elseif address == 0x4000065 then -- NR14
		address_out = 0xFF14
	elseif address == 0x4000068 then -- NR21
		address_out = 0xFF16
	elseif address == 0x4000069 then -- NR22
		address_out = 0xFF17
	elseif address == 0x400006C then -- NR23
		address_out = 0xFF18
	elseif address == 0x400006D then -- NR24
		address_out = 0xFF19
	elseif address == 0x4000070 then -- NR30
		address_out = 0xFF1A
	elseif address == 0x4000072 then -- NR31
		address_out = 0xFF1B
	elseif address == 0x4000073 then -- NR32
		address_out = 0xFF1C
	elseif address == 0x4000074 then -- NR33
		address_out = 0xFF1D
	elseif address == 0x4000075 then -- NR34
		address_out = 0xFF1E
	elseif address == 0x4000078 then -- NR41
		address_out = 0xFF20
	elseif address == 0x4000079 then -- NR42
		address_out = 0xFF21
	elseif address == 0x400007C then -- NR43
		address_out = 0xFF22
	elseif address == 0x400007D then -- NR44
		address_out = 0xFF23
	elseif address == 0x4000080 then -- NR50
		address_out = 0xFF24
	elseif address == 0x4000081 then -- NR51
		address_out = 0xFF25
	elseif address == 0x4000084 then -- NR52
		address_out = 0xFF26
	elseif address >= 0x4000090 and address <= 0x400009F then -- WAVERAM
		address_out = (address - 0x4000090) + 0xFF30
		emu.log(value)
	else
		return
	end
	
	writeCallbackGB(address_out, value_out)
end

if emu.getState()["consoleType"] == "Gameboy" then
	writeCallback = writeCallbackGB
	writeBegin = 0xFF10
	writeEnd = 0xFF3F
	readPSGMem = readPSGMemGB
elseif emu.getState()["consoleType"] == "Gba" then
	writeCallback = writeCallbackGBA
	writeBegin = 0x4000060
	writeEnd = 0x400009F
	readPSGMem = readGBAPSGFromGBAddress
end

local vgm_header = {
0x56, 0x67, 0x6D, 0x20, 0x00, 0x00, 0x00, 0x70, 0x61, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x69, 0x38, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x8C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0xB3, 0x16, 0xFF
}

local write_callback_reference = 0
local function checkForKeys()
	if emu.isKeyPressed("P") and not is_logging then
		start_vgm_frame = math.floor(getSeconds() * 44100)
		total_frames = 0
		is_logging = true
		vgm_handle = io.open(emu.getScriptDataFolder().."/test.vgm", "wb")
		for i, v in ipairs(vgm_header) do
			vgm_handle:write(string.char(v))
		end
		for i = 0xFF10, 0xFF3F do
			vgm_handle:write(string.char(0xB3))
			vgm_handle:write(string.char(i - 0xFF10))
			vgm_handle:write(string.char(readPSGMem(i)))
		end
		write_callback_reference = emu.addMemoryCallback(writeCallback, emu.callbackType.write, writeBegin, writeEnd)
		emu.displayMessage("Script", "Logging started")
	elseif emu.isKeyPressed("O") and is_logging then
		is_logging = false
		vgm_handle:write(string.char(0x66))
		-- end of file in header
		local eof = vgm_handle:seek("cur", 0) - 4
		vgm_handle:seek("set", 4)
		vgm_handle:write(string.char(eof & 0xFF))
		vgm_handle:write(string.char((eof & 0xFF00) >> 8))
		vgm_handle:write(string.char((eof & 0xFF0000) >> 16))
		vgm_handle:write(string.char((eof & 0xFF000000) >> 24))
		-- total samples
		vgm_handle:seek("set", 0x18)
		vgm_handle:write(string.char(total_frames & 0xFF))
		vgm_handle:write(string.char((total_frames & 0xFF00) >> 8))
		vgm_handle:write(string.char((total_frames & 0xFF0000) >> 16))
		vgm_handle:write(string.char((total_frames & 0xFF000000) >> 24))
		vgm_handle:close()
		emu.log(total_frames)
		emu.removeMemoryCallback(write_callback_reference, emu.callbackType.write, writeBegin, writeEnd)
		emu.displayMessage("Script", "Logging stopped")
	end
end

emu.addEventCallback(checkForKeys, emu.eventType.inputPolled)
emu.displayMessage("Script", "mesen2vgm engaged!")
