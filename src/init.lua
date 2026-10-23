local fs = require "filesystem"

if os.home == nil or os.home == "" then
    print("Error: could not determine the home directory (HOME is not set)")
    os.exit(1)
end

local config = os.home .. "/.config"
if not fs.exists(config) then
    fs.create_tree(config)
end

local config_zli = config .. "/zli"
if not fs.exists(config_zli) then
    fs.create_tree(config_zli)
end

local init = config_zli .. "/init.lua"
if not fs.exists(init) then
    io.write_file(init, [==[
--[================================================================================[
    zli init file

    you can put global initialisations here that will get executed on every
    invocation of zli before the program or script is executed
    it is useful to set local configuration or load default libraries
--]================================================================================]


]==])
end

package.loaded.filesystem = nil
dofile(init)
