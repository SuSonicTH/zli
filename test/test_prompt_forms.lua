local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local live = require "prompt.live"
local prompt = require "prompt"
local config = require "prompt.config"
local render = require "prompt.render"

local support = require "test/prompt_support"
local process = require "test/support"

Test_prompt_forms = {}

local function frame_text(frame)
    return support.frame_text(frame)
end

local function all_frames(frames)
    return support.frames_text(frames)
end

function Test_prompt_forms.Test_form_collects_values()
    local result = support.drive({
        support.char("d"), support.char("e"), support.char("m"), support.char("o"),
        support.key("tab"),
        support.key("down"),
        support.key("tab"),
        support.key("enter"),
    }, function()
        return prompt.form {
            title = "New project",
            fields = {
                { name = "name", type = "text", message = "Name", required = true },
                { name = "env", type = "select", message = "Environment", items = { "dev", "prod" } },
                { name = "enabled", type = "confirm", message = "Enabled", default = true },
            },
        }
    end)
    lu.assertEquals("demo", result[1].name)
    lu.assertEquals("prod", result[1].env)
    lu.assertEquals(true, result[1].enabled)
end

function Test_prompt_forms.Test_form_ctrl_enter_submits_from_any_field()
    local result = support.drive({
        support.key("enter"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "first", type = "text", message = "First", default = "a" },
                { name = "second", type = "text", message = "Second", default = "b" },
            },
        }
    end)
    lu.assertEquals("a", result[1].first)
    lu.assertEquals("b", result[1].second)
end

function Test_prompt_forms.Test_form_multiline_enter_and_alt_enter()
    local result = support.drive({
        support.char("a"),
        support.key("enter"),
        support.char("b"),
        support.key("enter", { alt = true }),
        support.char("t"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "body", type = "multiline", message = "Body", rows = 2 },
                { name = "tag", type = "text", message = "Tag" },
            },
        }
    end)
    lu.assertEquals("a\nb", result[1].body)
    lu.assertEquals("t", result[1].tag)
end

function Test_prompt_forms.Test_form_validation_focuses_first_invalid()
    local result, frames = support.drive({
        support.key("enter", { control = true }),
        support.char("x"),
        support.key("enter", { control = true }),
        support.char("a"), support.char("@"), support.char("b"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "name", type = "text", message = "Name", required = true },
                {
                    name = "email", type = "text", message = "Email",
                    validate = function(value)
                        if not value:find("@", 1, true) then return nil, "Use an email address." end
                        return true
                    end,
                },
            },
        }
    end)
    lu.assertEquals("x", result[1].name)
    lu.assertEquals("a@b", result[1].email)
    lu.assertStrContains(all_frames(frames), "An answer is required.")
    lu.assertStrContains(all_frames(frames), "Use an email address.")
end

function Test_prompt_forms.Test_form_level_validate_renders_footer()
    local result, frames = support.drive({
        support.key("enter", { control = true }),
        support.key("esc"),
    }, function()
        return prompt.form {
            fields = {
                { name = "name", type = "text", message = "Name", default = "taken" },
            },
            validate = function(values)
                if values.name == "taken" then return false, "That name is already in use." end
                return true
            end,
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "That name is already in use.")
end

function Test_prompt_forms.Test_form_cancel_and_eof()
    local result = support.drive({ support.key("esc") }, function()
        return prompt.form { fields = { { name = "a", type = "text", message = "A" } } }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])

    result = support.drive({}, function()
        return prompt.form { fields = { { name = "a", type = "text", message = "A" } } }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("eof", result[2])
end

function Test_prompt_forms.Test_form_scrolls_to_the_focused_field()
    local fields = {}
    for index = 1, 20 do
        fields[index] = { name = "field" .. index, type = "text", message = "Field " .. index,
            default = "value" .. index }
    end
    local events = {}
    for _ = 1, 19 do events[#events + 1] = support.key("tab") end
    events[#events + 1] = support.key("esc")

    local _, frames = support.drive(events, function()
        return prompt.form { fields = fields }
    end)
    lu.assertStrContains(frame_text(frames[#frames]), "Field 20")
end

function Test_prompt_forms.Test_form_field_types()
    local result = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "when", type = "date", message = "Date", default = "2026-11-15", as = "string" },
                { name = "at", type = "time", message = "Time", default = { hour = 10, min = 30 }, as = "string" },
                { name = "confirm", type = "confirm", message = "OK", default = false },
                { name = "secret", type = "password", message = "Secret", default = "s" },
            },
        }
    end)
    lu.assertEquals("2026-11-15", result[1].when)
    lu.assertEquals("10:30", result[1].at)
    lu.assertEquals(false, result[1].confirm)
    lu.assertEquals("s", result[1].secret)
end

function Test_prompt_forms.Test_form_initial_values()
    local result = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            values = { name = "seed", env = "prod" },
            fields = {
                { name = "name", type = "text", message = "Name" },
                { name = "env", type = "select", message = "Environment", items = { "dev", "prod" } },
                { name = "extra", type = "text", message = "Extra", default = "x" },
            },
        }
    end)
    lu.assertEquals("seed", result[1].name)
    lu.assertEquals("prod", result[1].env)
    lu.assertEquals("x", result[1].extra)
end

function Test_prompt_forms.Test_form_fallback()
    local script = process.temp_file("prompt_form_fallback", [[
local prompt = require "prompt"
local values = prompt.form {
    title = "Setup",
    fields = {
        { name = "name", type = "text", message = "Name", required = true },
        { name = "env", type = "select", message = "Environment", items = { "dev", "prod" }, default = "dev" },
        { name = "enabled", type = "confirm", message = "Enabled?", default = true },
    },
}
print(values.name .. "|" .. values.env .. "|" .. tostring(values.enabled))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_form_home"),
        stdin = "demo\n\n\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Setup")
    lu.assertStrContains(stdout, "demo|dev|true")
end

function Test_prompt_forms.Test_form_fallback_validates_field_specs()
    local script = process.temp_file("prompt_form_bad_spec", [[
local prompt = require "prompt"
local ok, message = pcall(function()
    return prompt.form { fields = { { type = "text", message = "No name" } } }
end)
print(tostring(ok), tostring(message):find("needs a name") ~= nil)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_form_bad_spec_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "false\ttrue")
end

function Test_prompt_forms.Test_wizard_merges_values_and_reviews()
    local result, frames = support.drive({
        support.key("enter"),
        support.key("enter"),
        support.key("enter"),
    }, function()
        return prompt.wizard {
            review = true,
            steps = {
                {
                    title = "Basics",
                    fields = {
                        { name = "name", type = "text", message = "Name", default = "demo" },
                    },
                },
                {
                    title = "Details",
                    fields = {
                        { name = "env", type = "select", message = "Environment", items = { "dev", "prod" } },
                    },
                },
            },
        }
    end)
    lu.assertEquals("demo", result[1].name)
    lu.assertEquals("dev", result[1].env)
    lu.assertStrContains(all_frames(frames), "Review")
    lu.assertStrContains(all_frames(frames), "Basics")
end

function Test_prompt_forms.Test_wizard_back_restores_edited_values()
    local result, frames = support.drive({
        support.key("char", { char = "x" }),
        support.key("enter"),
        support.key("char", { char = "y" }),
        support.key("left", { alt = true }),
        support.key("enter"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "One",
                    fields = { { name = "name", type = "text", message = "Name", default = "a" } },
                },
                {
                    title = "Two",
                    fields = { { name = "tag", type = "text", message = "Tag", default = "b" } },
                },
            },
        }
    end)
    lu.assertEquals("ax", result[1].name)
    lu.assertEquals("by", result[1].tag)
    lu.assertStrContains(all_frames(frames), "ax")
end

function Test_prompt_forms.Test_wizard_skip()
    local result = support.drive({
        support.key("enter"),
        support.key("enter"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "Enable",
                    fields = {
                        { name = "enabled", type = "confirm", message = "Enabled?", default = false },
                    },
                },
                {
                    title = "Reason",
                    skip = function(values) return values.enabled == false end,
                    fields = { { name = "reason", type = "text", message = "Reason", default = "because" } },
                },
                {
                    title = "Done",
                    fields = { { name = "done", type = "text", message = "Done", default = "yes" } },
                },
            },
        }
    end)
    lu.assertEquals(false, result[1].enabled)
    lu.assertEquals(nil, result[1].reason)
    lu.assertEquals("yes", result[1].done)
end

function Test_prompt_forms.Test_wizard_step_validation_blocks_advance()
    local result, frames = support.drive({
        support.key("enter", { control = true }),
        support.key("esc"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "One",
                    validate = function() return false, "This step is not ready." end,
                    fields = { { name = "name", type = "text", message = "Name", default = "a" } },
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "This step is not ready.")
end

function Test_prompt_forms.Test_wizard_esc_confirms_discard()
    local result, frames = support.drive({
        support.char("x"),
        support.key("esc"),
        support.key("esc"),
    }, function()
        return prompt.wizard {
            steps = {
                { title = "One", fields = { { name = "name", type = "text", message = "Name", default = "a" } } },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "Discard changes?")

    result = support.drive({ support.key("esc") }, function()
        return prompt.wizard {
            steps = {
                { title = "One", fields = { { name = "name", type = "text", message = "Name", default = "a" } } },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_forms.Test_wizard_rejects_duplicate_field_names()
    lu.assertError(function()
        prompt.wizard {
            steps = {
                {
                    title = "One",
                    fields = { { name = "x", type = "text", message = "X", default = "one" } },
                },
                {
                    title = "Two",
                    fields = { { name = "x", type = "text", message = "X", default = "two" } },
                },
            },
        }
    end)
end

function Test_prompt_forms.Test_wizard_fallback()
    local script = process.temp_file("prompt_wizard_fallback", [[
local prompt = require "prompt"
local values = prompt.wizard {
    review = true,
    steps = {
        {
            title = "Basics",
            fields = { { name = "name", type = "text", message = "Name", default = "demo" } },
        },
        {
            title = "Details",
            fields = { { name = "env", type = "select", message = "Environment", items = { "dev", "prod" }, default = "dev" } },
        },
    },
}
print(values.name .. "|" .. values.env)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_wizard_home"),
        stdin = "\n\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Basics")
    lu.assertStrContains(stdout, "Details")
    lu.assertStrContains(stdout, "Review")
    lu.assertStrContains(stdout, "demo|dev")
end

function Test_prompt_forms.Test_steps_indicator()
    config.reset()
    config.configure { symbols = "ascii", color = "never" }
    local text = prompt.steps {
        steps = { "Basics", "Details", "Review" },
        current = 2,
        width = 80,
    }
    lu.assertEquals("ok Basics  * Details  o Review", text)
    text = prompt.steps {
        steps = { "Basics", "Details", "Review" },
        current = 2,
        width = 12,
    }
    lu.assertEquals("2/3 Details", text)
    text = prompt.steps {
        steps = { { title = "Files" }, "Details" },
        current = 1,
        width = 80,
    }
    lu.assertEquals("* Files  o Details", text)
    lu.assertError(function() prompt.steps { steps = {} } end)
    lu.assertError(function() prompt.steps { steps = { "a" }, current = 2 } end)
    config.reset()
end

function Test_prompt_forms.Test_pause()
    local result = support.drive({ support.char("x") }, function()
        return prompt.pause { message = "Press", any = true }
    end)
    lu.assertEquals(true, result[1])

    result = support.drive({ support.char("x"), support.key("enter") }, function()
        return prompt.pause { message = "Press" }
    end)
    lu.assertEquals(true, result[1])

    result = support.drive({ support.key("esc") }, function()
        return prompt.pause { message = "Press", any = true }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])

    local script = process.temp_file("prompt_pause", [[
local prompt = require "prompt"
print(tostring(prompt.pause { message = "Wait" }))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_pause_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Wait\ntrue")
end

function Test_prompt_forms.Test_toast_capture_and_persist()
    live.capture = {}
    local ok, result = pcall(function()
        return support.drive({ support.char("x") }, function()
            return prompt.toast { message = "Saved", kind = "success", timeout = 5 }
        end)
    end)
    local capture = live.capture
    live.capture = nil
    lu.assertTrue(ok, result)
    lu.assertEquals(true, result[1])
    lu.assertStrContains(capture[1].text, "Saved")

    live.capture = {}
    ok, result = pcall(function()
        return support.drive({ support.char("x") }, function()
            return prompt.toast { message = "Stored", kind = "info", timeout = 5, persist = true }
        end)
    end)
    capture = live.capture
    live.capture = nil
    lu.assertTrue(ok, result)
    lu.assertEquals("finish", capture[#capture].kind)
    lu.assertEquals("Stored", capture[#capture].text)

    live.capture = {}
    ok, result = pcall(function()
        return support.drive({}, function()
            return prompt.toast { message = "Instant", timeout = 0 }
        end)
    end)
    capture = live.capture
    live.capture = nil
    lu.assertTrue(ok, result)
    lu.assertEquals(true, result[1])
    lu.assertEquals(0, #capture)

    live.capture = {}
    ok, result = pcall(function()
        return support.drive({}, function()
            return prompt.toast { message = "Left behind", timeout = 0, persist = true }
        end)
    end)
    capture = live.capture
    live.capture = nil
    lu.assertTrue(ok, result)
    lu.assertEquals(true, result[1])
    lu.assertEquals("finish", capture[#capture].kind)
    lu.assertEquals("Left behind", capture[#capture].text)
end

function Test_prompt_forms.Test_toast_validation_and_fallback()
    lu.assertError(function() prompt.toast {} end)
    lu.assertError(function() prompt.toast { message = "x", kind = "nope" } end)

    local script = process.temp_file("prompt_toast", [[
local prompt = require "prompt"
print(tostring(prompt.toast { message = "Plain notice", kind = "warning" }))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_toast_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Plain notice")
    lu.assertStrContains(stdout, "true")
end

function Test_prompt_forms.Test_progress_multi_lines()
    live.capture = {}
    local bars = prompt.progress.multi {
        label = "Copying",
        items = {
            { key = "src", label = "src", total = 10 },
            { key = "docs", label = "docs", total = 10 },
        },
    }
    bars:update("src", 5)
    bars:advance("docs")
    bars:set_total("docs", 20)
    bars:set_label("Copying files")
    bars:finish("Copied")
    local capture = live.capture
    live.capture = nil

    local texts = {}
    for _, entry in ipairs(capture) do texts[#texts + 1] = entry.text or entry.status end
    local combined = table.concat(texts, "\n")
    lu.assertStrContains(combined, "Copying")
    lu.assertStrContains(combined, "src")
    lu.assertStrContains(combined, "5/10")
    lu.assertStrContains(combined, "1/20")
    lu.assertStrContains(combined, "Copied")
    lu.assertError(function() bars:update("missing", 1) end)
end

function Test_prompt_forms.Test_progress_multi_stacked()
    live.capture = {}
    local bars = prompt.progress.multi {
        label = "Copying",
        stacked = true,
        items = {
            { key = "src", label = "src", total = 10 },
            { key = "docs", label = "docs", total = 30 },
        },
    }
    bars:update("src", 10)
    bars:finish("Copied")
    local capture = live.capture
    live.capture = nil
    lu.assertNotNil(capture[1].lines)
    lu.assertStrContains(capture[1].lines[1], "[")
    lu.assertStrContains(capture[1].lines[2], "src")
    lu.assertStrContains(capture[1].lines[2], "docs")
end

function Test_prompt_forms.Test_progress_multi_fallback()
    local script = process.temp_file("prompt_multi", [[
local prompt = require "prompt"
local bars = prompt.progress.multi {
    label = "Copying",
    items = { { key = "src", label = "source" }, { key = "docs", label = "docs" } },
}
bars:update("src", 1)
bars:finish("Copied")
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_multi_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Copying...")
    lu.assertStrContains(stdout, "source")
    lu.assertStrContains(stdout, "docs")
    lu.assertStrContains(stdout, "Copied")
end

function Test_prompt_forms.Test_progress_multi_validation()
    lu.assertError(function() prompt.progress.multi { items = {} } end)
    lu.assertError(function()
        prompt.progress.multi {
            items = { { key = "a" }, { key = "a" } },
        }
    end)
    lu.assertError(function()
        prompt.progress.multi { items = { { key = "a", total = -1 } } }
    end)
end

function Test_prompt_forms.Test_form_password_confirmation_cannot_be_bypassed()
    local result, frames = support.drive({
        support.char("p"), support.char("w"),
        support.key("enter", { control = true }),
        support.char("p"), support.char("w"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "secret", type = "password", message = "Secret", confirm = true },
            },
        }
    end)
    lu.assertEquals("pw", result[1].secret)
    lu.assertStrContains(all_frames(frames), "Confirm the password.")
end

function Test_prompt_forms.Test_form_commits_typed_dates_before_advancing()
    local result = support.drive({
        support.char("2"), support.char("0"), support.char("2"), support.char("6"),
        support.char("-"), support.char("1"), support.char("2"), support.char("-"),
        support.char("0"), support.char("1"),
        support.key("tab"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "when", type = "date", message = "Date", default = "2026-11-15", as = "string" },
                { name = "tag", type = "text", message = "Tag", default = "x" },
            },
        }
    end)
    lu.assertEquals("2026-12-01", result[1].when)
    lu.assertEquals("x", result[1].tag)
end

function Test_prompt_forms.Test_form_commits_typed_datetime_before_submitting()
    local result = support.drive({
        support.char("2"), support.char("0"), support.char("2"), support.char("7"),
        support.char("-"), support.char("0"), support.char("2"), support.char("-"),
        support.char("0"), support.char("3"),
        support.char(" "), support.char("0"), support.char("4"), support.char(":"),
        support.char("0"), support.char("5"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                {
                    name = "when", type = "datetime", message = "When",
                    default = "2026-11-15 10:30", as = "string",
                },
            },
        }
    end)
    lu.assertEquals("2027-02-03 04:05", result[1].when)
end

function Test_prompt_forms.Test_form_applies_trim_on_ctrl_enter()
    local result = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "name", type = "text", message = "Name", default = "  x  ", trim = true },
            },
        }
    end)
    lu.assertEquals("x", result[1].name)
end

function Test_prompt_forms.Test_wizard_starts_at_first_visible_step()
    local result, frames = support.drive({
        support.key("enter"),
    }, function()
        return prompt.wizard {
            values = { simple = true },
            steps = {
                {
                    title = "Ignored",
                    skip = function(values) return values.simple == true end,
                    fields = { { name = "ignored", type = "text", message = "Ignored", default = "no" } },
                },
                {
                    title = "Second",
                    fields = { { name = "done", type = "text", message = "Done", default = "yes" } },
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1].ignored)
    lu.assertEquals("yes", result[1].done)
    lu.assertStrContains(all_frames(frames), "Second")
    lu.assertNotStrContains(all_frames(frames), "Ignored")
end

function Test_prompt_forms.Test_wizard_all_steps_skipped_returns_values()
    local result = support.drive({}, function()
        return prompt.wizard {
            values = { kept = 1 },
            steps = {
                {
                    title = "Skipped",
                    skip = function() return true end,
                    fields = { { name = "ignored", type = "text", message = "Ignored" } },
                },
            },
        }
    end)
    lu.assertEquals(1, result[1].kept)
    lu.assertEquals(nil, result[1].ignored)
end

function Test_prompt_forms.Test_wizard_fallback_review_masks_and_handles_table_values()
    local script = process.temp_file("prompt_wizard_masked", [[
local prompt = require "prompt"
local pair = { "a", "b" }
local values = prompt.wizard {
    review = true,
    steps = {
        {
            title = "Details",
            fields = {
                { name = "password", type = "password", message = "Password", default = "hunter2" },
                { name = "choice", type = "select", message = "Choice",
                  items = { { label = "pair", value = pair } }, default = pair },
                { name = "partial", type = "select", message = "Partial",
                  items = { { label = "year", value = { year = 2024 } } }, default = { year = 2024 } },
            },
        },
    },
}
print(values.password .. "|" .. table.concat(values.choice, ",") .. "|" .. tostring(values.partial.year))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_wizard_masked_home"),
        stdin = "\n\n\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Password: *******")
    lu.assertNotStrContains(stdout, "Password: hunter2")
    lu.assertStrContains(stdout, "Choice: a, b")
    lu.assertStrContains(stdout, "Partial: {year=2024}")
    lu.assertStrContains(stdout, "hunter2|a,b|2024")
end

function Test_prompt_forms.Test_wizard_rechecks_skips_after_commit()
    local result, frames = support.drive({
        support.char("2"), support.char("0"), support.char("2"), support.char("6"),
        support.char("-"), support.char("1"), support.char("2"), support.char("-"),
        support.char("0"), support.char("1"),
        support.key("enter", { control = true }),
        support.key("esc"),
        support.key("esc"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "First",
                    fields = {
                        {
                            name = "date", type = "date", message = "Date",
                            default = "2026-11-15", as = "string",
                        },
                    },
                },
                {
                    title = "Second",
                    skip = function(values) return values.date == "2026-11-15" end,
                    fields = { { name = "reason", type = "text", message = "Reason", required = true } },
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "An answer is required.")
end

function Test_prompt_forms.Test_wizard_step_validate_sees_collected_values_only()
    local result = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "First",
                    validate = function(values)
                        if values.later ~= nil then return false, "saw a later default" end
                        return true
                    end,
                    fields = { { name = "name", type = "text", message = "Name", default = "a" } },
                },
                {
                    title = "Second",
                    fields = { { name = "later", type = "confirm", message = "Later", default = true } },
                },
            },
        }
    end)
    lu.assertEquals("a", result[1].name)
    lu.assertEquals(true, result[1].later)
end

function Test_prompt_forms.Test_wizard_all_skipped_review_stays_on_review()
    local result, frames = support.drive({
        support.key("left", { alt = true }),
        support.key("enter"),
    }, function()
        return prompt.wizard {
            review = true,
            values = { kept = 1 },
            steps = {
                {
                    title = "Skipped",
                    skip = function() return true end,
                    fields = { { name = "ignored", type = "text", message = "Ignored" } },
                },
            },
        }
    end)
    lu.assertEquals(1, result[1].kept)
    lu.assertStrContains(all_frames(frames), "Review")
    lu.assertNotStrContains(all_frames(frames), "? Ignored")
end

function Test_prompt_forms.Test_wizard_does_not_construct_skipped_steps()
    local result = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "First",
                    fields = { { name = "name", type = "text", message = "Name", default = "a" } },
                },
                {
                    title = "Skipped",
                    skip = function() return true end,
                    fields = {
                        { name = "bad", type = "date", message = "Bad", default = "not a date" },
                    },
                },
            },
        }
    end)
    lu.assertEquals("a", result[1].name)
    lu.assertEquals(nil, result[1].bad)
end

function Test_prompt_forms.Test_form_commits_pending_time_digits()
    local result = support.drive({
        support.char("1"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "at", type = "time", message = "Time", default = { hour = 9, min = 30 }, as = "string" },
            },
        }
    end)
    lu.assertEquals("01:30", result[1].at)
end

function Test_prompt_forms.Test_form_commits_datetime_time_digits()
    local result = support.drive({
        support.key("char", { char = "t", control = true }),
        support.char("1"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                {
                    name = "when", type = "datetime", message = "When",
                    default = "2026-11-15 10:30", as = "string",
                },
            },
        }
    end)
    lu.assertEquals("2026-11-15 01:30", result[1].when)
end

function Test_prompt_forms.Test_form_time_digits_still_type_two_digits()
    local result = support.drive({
        support.char("1"), support.char("2"),
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "at", type = "time", message = "Time", default = { hour = 9, min = 30 }, as = "string" },
            },
        }
    end)
    lu.assertEquals("12:30", result[1].at)
end

function Test_prompt_forms.Test_field_values_include_pending_time_digits()
    local time = require("prompt.time").new_field {
        message = "Time", default = { hour = 9, min = 30 }, as = "string",
    }
    time:handle(support.char("1"))
    lu.assertEquals("01:30", time:value())
    time:commit()
    lu.assertEquals("01:30", time:value())
    time:close()

    local datetime = require("prompt.datetime").new_field {
        message = "When", default = "2026-11-15 10:30", as = "string",
    }
    datetime:handle(support.key("char", { char = "t", control = true }))
    datetime:handle(support.char("1"))
    lu.assertEquals("2026-11-15 01:30", datetime:value())
    datetime:commit()
    lu.assertEquals("2026-11-15 01:30", datetime:value())
    datetime:close()
end

function Test_prompt_forms.Test_wizard_dirty_tracks_pending_edits_only()
    local result, frames = support.drive({
        support.char("2"), support.char("0"), support.char("2"), support.char("6"),
        support.char("-"), support.char("1"), support.char("2"), support.char("-"),
        support.char("0"), support.char("1"),
        support.key("esc"),
        support.key("esc"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "Date",
                    fields = {
                        {
                            name = "date", type = "date", message = "Date",
                            default = "2026-11-15", as = "string",
                        },
                    },
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "Discard changes?")

    result, frames = support.drive({
        support.key("tab"),
        support.key("esc"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "Text",
                    fields = { { name = "name", type = "text", message = "Name", default = "  x  ", trim = true } },
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    lu.assertNotStrContains(all_frames(frames), "Discard changes?")
end

function Test_prompt_forms.Test_wizard_review_omits_steps_skipped_by_later_answers()
    local result, frames = support.drive({
        support.char("y"),
        support.key("enter"),
    }, function()
        return prompt.wizard {
            review = true,
            steps = {
                {
                    title = "First",
                    fields = { { name = "enabled", type = "confirm", message = "Enabled?", default = false } },
                },
                {
                    title = "Middle",
                    skip = function(values) return values.enabled == true end,
                    fields = { { name = "mid", type = "text", message = "Mid", default = "m" } },
                },
            },
        }
    end)
    lu.assertEquals(true, result[1].enabled)
    lu.assertEquals(nil, result[1].mid)
    lu.assertNotStrContains(all_frames(frames), "? Mid")
end

function Test_prompt_forms.Test_wizard_fallback_review_matches_final_skips()
    local script = process.temp_file("prompt_wizard_visited", [[
local prompt = require "prompt"
local values = prompt.wizard {
    review = true,
    steps = {
        {
            title = "One",
            fields = { { name = "go", type = "confirm", message = "Go?", default = false } },
        },
        {
            title = "Two",
            skip = function(values) return values.hide == true end,
            fields = { { name = "reason", type = "text", message = "Reason", default = "kept" } },
        },
        {
            title = "Three",
            fields = { { name = "hide", type = "confirm", message = "Hide?", default = true } },
        },
    },
}
print(values.go, values.hide, values.reason)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_wizard_visited_home"),
        stdin = "\n\n\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Reason: kept")
    lu.assertStrContains(stdout, "false\ttrue\tkept")
end

function Test_prompt_forms.Test_wizard_fallback_review_omits_skipped_steps()
    local script = process.temp_file("prompt_wizard_skipped_review", [[
local prompt = require "prompt"
local values = prompt.wizard {
    review = true,
    steps = {
        {
            title = "First",
            fields = { { name = "enabled", type = "confirm", message = "Enabled?", default = true } },
        },
        {
            title = "Middle",
            skip = function(values) return values.enabled == true end,
            fields = { { name = "mid", type = "text", message = "Mid", default = "m" } },
        },
    },
}
print(values.enabled, values.mid)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_wizard_skipped_review_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertNotStrContains(stdout, "Mid: m")
    lu.assertStrContains(stdout, "true\tnil")
end

function Test_prompt_forms.Test_commit_modes()
    local _, frames = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            title = "Committed",
            commit = "frame",
            fields = { { name = "a", type = "text", message = "A", default = "x" } },
        }
    end)
    lu.assertEquals("frame", frames.commits[1].kind)
    lu.assertNotNil(frames.commits[1].frame)

    _, frames = support.drive({
        support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            title = "Committed",
            fields = { { name = "a", type = "text", message = "A", default = "x" } },
        }
    end)
    lu.assertEquals("summary", frames.commits[1].kind)
    lu.assertStrContains(render.plain(frames.commits[1].summary), "Committed")

    _, frames = support.drive({
        support.key("enter"),
    }, function()
        return prompt.pause { message = "Paused" }
    end)
    lu.assertEquals("summary", frames.commits[1].kind)
    lu.assertStrContains(render.plain(frames.commits[1].summary), "Paused")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
