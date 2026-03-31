-- mame_dump.lua — dump arcade core state at a target frame for Golden State Snapshot
-- Usage: mame <gamename> -autoboot_script mame_dump.lua -autoboot_delay 0
-- Output: /tmp/mame_dump_<game>_f<frame>.json
--
-- Configure per game:
local TARGET_FRAME = 100          -- frame to dump at
local OUTPUT_DIR   = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"

-- Per-game config: key = MAME short name
local CONFIGS = {
    tetrist = {
        cpu       = ":maincpu",
        pal_start = 0xA00000,  -- palette RAM (4096 words × 2 bytes)
        pal_words = 0x1000,
        vcu_start = 0x400000,  -- VCU VRAM (first 32KB covers tile+sprite RAM)
        vcu_words = 0x4000,
    },
    taitob = {  -- alias
        cpu       = ":maincpu",
        pal_start = 0xA00000,
        pal_words = 0x1000,
        vcu_start = 0x400000,
        vcu_words = 0x4000,
    },
    -- add more games here
}

local function get_config()
    local name = manager.machine.system.name
    return CONFIGS[name] or CONFIGS["taitob"]
end

local function dump_words(space, base, count)
    local t = {}
    for i = 0, count - 1 do
        t[i+1] = string.format("%04X", space:read_u16(base + i * 2))
    end
    return t
end

local function write_json(path, data)
    local f = io.open(path, "w")
    if not f then
        print("[mame_dump] ERROR: cannot open " .. path)
        return
    end
    f:write("{\n")
    f:write(string.format('  "game": "%s",\n', manager.machine.system.name))
    f:write(string.format('  "frame": %d,\n', data.frame))

    -- palette
    f:write('  "palette": [')
    for i, v in ipairs(data.palette) do
        if i > 1 then f:write(",") end
        if (i-1) % 16 == 0 then f:write("\n    ") end
        f:write('"' .. v .. '"')
    end
    f:write("\n  ],\n")

    -- vcu
    f:write('  "vcu": [')
    for i, v in ipairs(data.vcu) do
        if i > 1 then f:write(",") end
        if (i-1) % 16 == 0 then f:write("\n    ") end
        f:write('"' .. v .. '"')
    end
    f:write("\n  ],\n")

    -- cpu regs
    f:write('  "cpu": {\n')
    f:write(string.format('    "PC": "0x%06X",\n', data.cpu.pc))
    f:write(string.format('    "SP": "0x%06X"\n', data.cpu.sp))
    f:write("  }\n")
    f:write("}\n")
    f:close()
    print("[mame_dump] wrote " .. path)
end

local frame_count = 0
local done = false

emu.register_frame_done(function()
    if done then return end
    frame_count = frame_count + 1
    if frame_count < TARGET_FRAME then return end
    done = true

    local cfg = get_config()
    local cpu  = manager.machine.devices[cfg.cpu]
    local space = cpu.spaces["program"]

    local data = {
        frame   = frame_count,
        palette = dump_words(space, cfg.pal_start, cfg.pal_words),
        vcu     = dump_words(space, cfg.vcu_start, cfg.vcu_words),
        cpu     = {
            pc = cpu.state["CURPC"].value,
            sp = cpu.state["SP"].value,
        },
    }

    local outfile = string.format("%s/mame_dump_%s_f%d.json",
        OUTPUT_DIR, manager.machine.system.name, frame_count)
    write_json(outfile, data)

    print("[mame_dump] done at frame " .. frame_count)
    manager.machine:exit()
end)
