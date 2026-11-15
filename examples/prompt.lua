-- A tour of the `prompt` library using a fictional mission launch.
--
-- Everything here is simulated: no files are written, no server is contacted
-- and the progress bars only exist to look busy.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt.lua
--
-- With piped input the same questions use the plain-text fallback.

local prompt = require "prompt"

local function heading(text)
    print()
    print("== " .. text .. " ==")
end

local function pause(milliseconds)
    local deadline = os.nanotime() + milliseconds / 1000
    while os.nanotime() < deadline do end
end

local function need(value, message)
    if value == nil then
        print("Showcase cancelled: " .. tostring(message or "cancelled"))
        os.exit(0)
    end
    return value
end

heading("Prompt showcase")

local style = need(prompt.select {
    message = "Presentation style",
    items = {
        { label = "Inline", value = "inline", description = "keep the scrollback" },
        { label = "Alternate screen", value = "alternate", description = "full-screen, restored on exit" },
    },
    default = "inline",
})

local manifest = prompt.screen(style, function()
    local mission = need(prompt.select {
        message = "Choose a fictional mission",
        items = {
            { label = "Espresso orbital station", value = "espresso", description = "zero-g crema research" },
            { label = "Lunar bakery", value = "bakery", description = "sourdough at one sixth gravity" },
            { label = "Asteroid bookshop", value = "bookshop", description = "rare titles, low gravity" },
            { label = "Retired volcano lair", value = "lair", disabled = true, description = "currently evil-free" },
        },
        default = "espresso",
        filter = "auto",
    })

    local modules = need(prompt.multiselect {
        message = "Install made-up modules",
        items = { "gravity", "crumpet", "radio", "mirrors", "tea" },
        default = { "gravity", "radio" },
        min = 1,
    })

    local callsign = need(prompt.text {
        message = "Crew call sign",
        default = "Nova",
        placeholder = "no spaces, 16 characters max",
        max_length = 16,
        validate = function(value)
            if value:find("%s") then return nil, "spaces are not allowed" end
            return true
        end,
    })

    local motto = need(prompt.multiline {
        message = "Mission motto",
        default = "We came. We brewed. We left a tidy orbit.",
        rows = 3,
        max_length = 160,
    })

    local secret = need(prompt.password {
        message = "Launch code",
        default = "correct-horse",
        confirm = true,
        confirm_message = "Launch code (one more time)",
    })

    local launch_date = need(prompt.date {
        message = "Launch date",
        default = os.date("*t"),
        min = os.date("%Y-%m-%d"),
        as = "string",
    })

    local launch_time = need(prompt.time {
        message = "Launch time",
        default = { hour = 9, min = 30 },
        as = "string",
    })

    local briefing = need(prompt.datetime {
        message = "Crew briefing",
        default = os.date("*t"),
        as = "string",
    })

    local go = prompt.confirm {
        message = "Authorise the simulated launch?",
        default = true,
    }
    if not go then
        print("Launch aborted. Nothing happened.")
        os.exit(0)
    end

    heading("Simulated preparation")

    local calibration = prompt.progress {
        total = #modules * 3,
        label = "Calibrating " .. mission,
        show = "both",
    }
    for step = 1, #modules * 3 do
        pause(180)
        calibration:update(step)
    end
    calibration:finish("Calibration complete")

    for _, module in prompt.progress.each(modules, { label = "Installing modules" }) do
        pause(540)
    end

    local spinner = prompt.spinner {
        text = "Polishing chrome",
        show_elapsed = true,
        interval = 0.05,
    }
    for step = 1, 8 do
        pause(270)
        spinner:step("Polishing chrome " .. step .. "/8")
    end
    spinner:finish("All systems shiny")

    return {
        mission = mission,
        modules = modules,
        callsign = callsign,
        motto = motto,
        secret = secret,
        date = launch_date,
        time = launch_time,
        briefing = briefing,
    }
end)

heading("Simulated launch manifest")

print("  presentation : " .. style)
print("  mission      : " .. manifest.mission)
print("  call sign    : " .. manifest.callsign)
print("  modules      : " .. table.concat(manifest.modules, ", "))
print("  motto        : " .. manifest.motto:gsub("\n", " / "))
print("  launch code  : " .. string.rep("*", #manifest.secret))
print("  launch       : " .. manifest.date .. " at " .. manifest.time)
print("  briefing     : " .. manifest.briefing)
print()
print("Nothing above is real. This is only a prompt showcase.")
