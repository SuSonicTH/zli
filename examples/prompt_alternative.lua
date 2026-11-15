-- A tour of the `prompt` library using a fictional mission launch.
--
-- The showcase runs entirely in the alternate screen.  Everything here is
-- simulated: no files are written, no server is contacted and the progress
-- bars only exist to look busy.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt_alternative.lua
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

local function cancel(message)
    error({ cancelled = true, message = message }, 0)
end

local function need(value, message)
    if value == nil then cancel(message) end
    return value
end

heading("Prompt showcase (alternate screen)")

local ok, manifest = pcall(prompt.screen, "alternate", function()
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

    local go = need(prompt.confirm {
        message = "Authorise the simulated launch?",
        default = true,
    })
    if not go then cancel("launch aborted") end

    local calibration = prompt.progress {
        total = #modules * 3,
        label = "Calibrating " .. mission,
        show = "both",
    }
    for step = 1, #modules * 3 do
        pause(500)
        calibration:update(step)
    end
    calibration:finish("Calibration complete")

    for _, module in prompt.progress.each(modules, { label = "Installing modules" }) do
        pause(750)
    end

    local spinner = prompt.spinner {
        text = "Polishing chrome",
        show_elapsed = true,
        interval = 0.05,
    }
    for step = 1, 8 do
        pause(500)
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

if not ok then
    if type(manifest) == "table" and manifest.cancelled then
        print("Showcase cancelled: " .. tostring(manifest.message or "cancelled"))
        os.exit(0)
    end
    error(manifest, 0)
end

heading("Simulated launch manifest")

print("  mission      : " .. manifest.mission)
print("  call sign    : " .. manifest.callsign)
print("  modules      : " .. table.concat(manifest.modules, ", "))
print("  motto        : " .. manifest.motto:gsub("\n", " / "))
print("  launch code  : " .. string.rep("*", #manifest.secret))
print("  launch       : " .. manifest.date .. " at " .. manifest.time)
print("  briefing     : " .. manifest.briefing)
print()

