-- Interactive project setup using the prompt library.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt_demo.lua
--
-- When stdin is a pipe the same prompts use their plain-text fallback.

local prompt = require "prompt"

local environment = prompt.select {
    message = "Target environment",
    items = {
        { label = "development", value = "dev", description = "local machine" },
        { label = "staging", value = "stage", description = "shared test server" },
        { label = "production", value = "prod", description = "live users" },
    },
    default = "stage",
}
if environment == nil then
    print("cancelled")
    os.exit(0)
end

local features = prompt.multiselect {
    message = "Enable features",
    items = { "cache", "metrics", "tracing", "backups" },
    default = { "cache", "metrics" },
    min = 1,
}

local name = prompt.text {
    message = "Project name",
    default = "demo",
    placeholder = "lowercase, no spaces",
    validate = function(value)
        if value:find("%s") then return nil, "spaces are not allowed" end
        return true
    end,
}

local release = prompt.date {
    message = "Release date",
    default = os.date("*t"),
    as = "string",
}

if not prompt.confirm { message = "Write the configuration?", default = true } then
    print("nothing written")
    os.exit(0)
end

local progress = prompt.progress {
    total = #features,
    label = "Applying " .. environment .. " settings",
}
for _, feature in ipairs(features) do
    -- Replace this with real work.
    for _ = 1, 20000 do end
    progress:advance()
end
progress:finish("Configuration ready")

local spinner = prompt.spinner { text = "Warming caches" }
for step = 1, 4 do
    for _ = 1, 120000 do end
    spinner:step("Warming caches " .. step .. "/4")
end
spinner:finish("Caches warm")

print(string.format("project=%s env=%s release=%s features=%s",
    name, environment, release, table.concat(features, ",")))
