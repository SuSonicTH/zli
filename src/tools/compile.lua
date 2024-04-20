local fs = require("filesystem")
local zip = require("zip")

local function exit_error(message)
    print("Error: " .. message)
    os.exit(1)
end

local function check_and_fix_output_file(config)
    if not config.output_name then
        exit_error "mising config 'output_name'"
    end
    if os.is_windows and not config.output_name:ends_with(".exe") then
        config.output_name = config.output_name .. ".exe"
    end
end

local function setup_files(config)
    local files = {}
    if not config.files or #config.files == 0 then
        exit_error "mising or empty config 'files'"
    end
    for _, item in ipairs(config.files) do
        local entry
        if type(item) == "table" then
            entry = item
        else
            entry = { file = item, name = item }
        end
        if not fs.exists(entry.file) then
            exit_error(" could not find file '" .. entry.file .. "'")
        end
        files[#files + 1] = entry
    end
    config.files = files
end

local function copy_binary(config)
    io.write_file(config.output_name, io.read_file(arg[0]))
end

local function append_data(config)
    local data = zip.create_after(config.output_name)
    for _, entry in ipairs(config.files) do
        data:add_file(entry.file, entry.name, 9)
    end
    data:close_zip("zli")
end

local function execute(config)
    check_and_fix_output_file(config)
    setup_files(config)

    copy_binary(config)
    append_data(config)
end

return {
    execute = execute,
}
