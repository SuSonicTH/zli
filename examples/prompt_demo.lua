-- Interactive project setup using the prompt library.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt_demo.lua
--
-- When stdin is a pipe the same prompts use their plain-text fallback.

local prompt = require "prompt"

local function pause(milliseconds)
    local deadline = os.nanotime() + milliseconds / 1000
    while os.nanotime() < deadline do end
end

local function need(value, message)
    if value == nil then
        print("cancelled: " .. tostring(message or "cancelled"))
        os.exit(0)
    end
    return value
end

local environment = need(prompt.select {
    message = "Target environment",
    items = {
        { label = "development", value = "dev", description = "local machine" },
        { label = "staging", value = "stage", description = "shared test server" },
        { label = "production", value = "prod", description = "live users" },
    },
    default = "stage",
})

local features = need(prompt.multiselect {
    message = "Enable features",
    items = { "cache", "metrics", "tracing", "backups" },
    default = { "cache", "metrics" },
    min = 1,
})

local name = need(prompt.text {
    message = "Project name",
    default = "demo",
    placeholder = "lowercase, no spaces",
    validate = function(value)
        if value:find("%s") then return nil, "spaces are not allowed" end
        return true
    end,
})

local release = need(prompt.date {
    message = "Release date",
    default = os.date("*t"),
    as = "string",
})

local write = need(prompt.confirm { message = "Write the configuration?", default = true })
if not write then
    print("nothing written")
    os.exit(0)
end

local progress = prompt.progress {
    total = #features,
    label = "Applying " .. environment .. " settings",
}
for _, feature in ipairs(features) do
    -- Replace this with real work.
    pause(750)
    progress:advance()
end
progress:finish("Configuration ready")

local spinner = prompt.spinner { text = "Warming caches" }
for step = 1, 4 do
    pause(750)
    spinner:step("Warming caches " .. step .. "/4")
end
spinner:finish("Caches warm")

print(string.format("project=%s env=%s release=%s features=%s",
    name, environment, release, table.concat(features, ",")))
