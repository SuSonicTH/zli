-- Multi-step project setup built from prompt.wizard, pause, progress.multi and
-- toast.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt_wizard.lua
--
-- When stdin is a pipe the wizard uses the plain-text fallback for every step.

local prompt = require "prompt"

local function need(value, message)
    if value == nil then
        print("cancelled: " .. tostring(message or "cancelled"))
        os.exit(0)
    end
    return value
end

local function pause(milliseconds)
    local deadline = os.nanotime() + milliseconds / 1000
    while os.nanotime() < deadline do end
end

local values = need(prompt.wizard {
    title = "New project",
    review = true,
    submit = "Create",
    steps = {
        {
            title = "Basics",
            fields = {
                {
                    name = "name",
                    type = "text",
                    message = "Name",
                    default = "demo",
                    required = true,
                    validate = function(value)
                        if value:find("%s") then return nil, "spaces are not allowed" end
                        return true
                    end,
                },
                {
                    name = "environment",
                    type = "select",
                    message = "Environment",
                    items = {
                        { label = "development", value = "dev" },
                        { label = "staging", value = "staging" },
                        { label = "production", value = "production" },
                    },
                    default = "staging",
                },
            },
        },
        {
            title = "Features",
            fields = {
                {
                    name = "features",
                    type = "multiselect",
                    message = "Features",
                    items = { "cache", "metrics", "tracing" },
                    default = { "cache" },
                    min = 1,
                },
                {
                    name = "notes",
                    type = "multiline",
                    message = "Notes",
                    rows = 3,
                    placeholder = "Optional release notes",
                },
                {
                    name = "enabled",
                    type = "confirm",
                    message = "Enable now?",
                    default = true,
                },
            },
            validate = function(page)
                if #page.features > 2 and page.enabled then
                    return nil, "disable the project or drop a feature"
                end
                return true
            end,
        },
        {
            title = "Schedule",
            fields = {
                {
                    name = "release",
                    type = "date",
                    message = "Release date",
                    default = os.date("*t"),
                    as = "string",
                },
                {
                    name = "at",
                    type = "time",
                    message = "Release time",
                    default = { hour = 9, min = 0 },
                    as = "string",
                },
            },
        },
    },
})

prompt.pause { message = "Press any key to apply the settings", any = true }

local items = {}
for _, feature in ipairs(values.features) do
    items[#items + 1] = { key = feature, label = feature, total = 3 }
end
local bars = prompt.progress.multi {
    label = "Applying " .. values.environment .. " settings",
    stacked = #items > 1,
    items = items,
}
for _, feature in ipairs(values.features) do
    for _ = 1, 3 do
        pause(150)
        bars:advance(feature)
    end
end
bars:finish("Configuration applied")

prompt.toast {
    message = "Created " .. values.name,
    kind = "success",
    timeout = 1.2,
    persist = true,
}

print(string.format("name=%s env=%s features=%s enabled=%s release=%s at=%s",
    values.name,
    values.environment,
    table.concat(values.features, ","),
    tostring(values.enabled),
    values.release,
    values.at))
