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
            local name = item:match("[^/\\]+$") or item
            entry = { file = item, name = name }
        end
        if type(entry.file) ~= "string" then
            exit_error("file entry is missing a 'file' field")
        end
        if entry.name == nil then
            entry.name = entry.file:match("[^/\\]+$") or entry.file
        end
        if not fs.exists(entry.file) then
            exit_error("could not find file '" .. entry.file .. "'")
        end
        files[#files + 1] = entry
    end
    config.files = files
end

local function copy_binary(config)
    local source = ZLI.exe_path or arg[0]
    local input, err = io.open(source, "rb")
    if input == nil then
        exit_error("could not read executable '" .. tostring(source) .. "': " .. tostring(err))
    end
    local data = input:read("a")
    input:close()
    io.write_file(config.output_name, data)
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

    if os.is_linux then
        fs.chmod(config.output_name, "755")
    end
end

return {
    execute = execute,
}
