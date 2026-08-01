local io = require("io")
local json = require("cjson")
local F = require("F")
local spec = require("raylib_api")
local output_path = "./src/raylib.zig"

local LF = "\n"
local IND = "    "

local out = assert(io.open(output_path, "w"))


local type_mapping = setmetatable({
    ["char"] = "u8",
    ["unsigned char"] = "u8",
    ["unsigned char *"] = "[*c]u8",
    ["unsigned short"] = "c_ushort",
    ["unsigned short *"] = "[*c]c_ushort",
    ["int"] = "c_int",
    ["int *"] = "[*c]c_int",
    ["unsigned int"] = "c_uint",
    ["unsigned int *"] = "[*c]c_uint",
    ["float"] = "f32",
    ["float *"] = "[*c]f32",
    ["void *"] = '*anyopaque',
    ["char **"] = "[*c][*c]u8",
}, {
    __index = function(t, k)
        --local struct_ptr = k:match("^(%u[%u%l]+) %*$")
        --if struct_ptr then
        --    return "[*c]" .. struct_ptr
        --end
        --
        --local opaque_ptr = k:match("^(r[%u%l]+) %*$")
        --if opaque_ptr then
        --    return "*" .. opaque_ptr
        --end
        --local array, size = k:match("(%a+)(%[%d+%])")
        --if array then
        --    return size .. t[array]
        --end
        return "rl.struct_" .. k
    end
})

local parameter_mapping = {
    int = function(pos, name)
        return 'const ' .. name ..
            ' = luax.getArgIntOrError(c_int, lua, ' .. pos .. ', "expecting ' .. name .. ' as integer");'
    end,
    float = function(pos, name)
        return 'const ' .. name ..
            ' = luax.getArgFloatOrError(lua, ' .. pos .. ', "expecting ' .. name .. ' as number");'
    end,

    ["const char *"] = function(pos, name)
        return 'const ' .. name ..
            ' = luax.getArgStringOrError(lua, ' .. pos .. ', "expecting ' .. name .. ' as string");'
    end,
}

local exported_functions = {}

local function addExportedFunction(name, lua)
    lua = lua or name:sub(1, 1):lower() .. name:sub(2)
    exported_functions[#exported_functions + 1] = { name = name, lua = lua }
end

local function write_structs()
    for _, struct in ipairs(spec.structs) do
        for _, field in ipairs(struct.fields) do
            if field.type:find("%*") or type_mapping[field.type]:match("rl%.struct") then
                goto continue
            end
        end

        parameter_mapping[struct.name] = function(pos, name)
            return 'const ' .. name .. ' = ' .. struct.name .. '_from_lua(lua, ' .. pos .. ');'
        end

        out:write("fn ", struct.name, "_from_lua(lua: *Lua, index:i32) rl.struct_", struct.name, " {", LF)
        out:write(IND, "if (lua.typeOf(index) == .userdata) {", LF)
        out:write(IND, IND, "return (lua.toUserdata(rl.struct_", struct.name, ", index) catch @panic(\"expecting ",
            struct.name, " object\")).*;", LF)
        out:write(IND, "}", LF)

        out:write(IND, "return .{", LF)
        for _, field in ipairs(struct.fields) do
            if field.type == 'float' then
                out:write(IND, IND, ".", field.name, " = luax.getArgTableFloat(lua, f32, index, \"", field.name,
                    "\",\"expecting ", struct.name, " table\"),", LF)
            else
                print("~~~~~", type_mapping[field.type], type_mapping[field.type]:match("rl%.struct"))
                out:write(IND, IND, ".", field.name, " = luax.getArgTableInteger(lua, ", type_mapping[field.type],
                    ", index, \"", field.name,
                    "\",\"expecting ", struct.name, " table\"),", LF)
            end
        end
        out:write(IND, "};", LF)
        out:write("}", LF, LF)

        out:write("fn ", struct.name, "(lua: *Lua) i32 {", LF)
        out:write(IND, "const val: *rl.struct_", struct.name, " = lua.newUserdata(rl.struct_", struct.name, ", 0);", LF)
        out:write(IND, "val.* = ", struct.name, "_from_lua(lua, 1);", LF)
        out:write(IND, "return 1;", LF)
        out:write("}", LF, LF)

        addExportedFunction(struct.name, struct.name)

        ::continue::
    end
end


local function getParameters(func)
    local parameters = {}
    local list = {}
    if func.params then
        for i, param in ipairs(func.params) do
            local mapping = parameter_mapping[param.type]
            if mapping then
                parameters[i] = mapping(i, param.name)
                list[i] = param.name
            else
                return nil, nil, "unknown parameter " .. param.type
            end
        end
    end
    return parameters, table.concat(list, ", ")
end

local missing_param_mapping = {}
local function report_missing_param_mapping(error)
    if not missing_param_mapping[error] then
        missing_param_mapping[error] = true
        print(error)
    end
end

local return_mapping = {
    void = "void",
    bool = "lua.pushBoolean(ret);",
}



local function write_functions()
    for _, func in ipairs(spec.functions) do
        local parameters, list, err = getParameters(func)
        local retmapping = return_mapping[func.returnType];

        if parameters then
            if retmapping then
                addExportedFunction(func.name);

                out:write('pub fn ', func.name, '(lua: *Lua) i32 {', LF)
                for _, param in ipairs(parameters) do
                    out:write(IND, param, LF)
                end
                if #parameters == 0 and retmapping == 'void' then
                    out:write(IND, '_ = lua;', LF)
                end

                if retmapping == 'void' then
                    out:write(IND, 'rl.', func.name, '(', list, ');', LF)
                    out:write(IND, 'return 0;', LF)
                else
                    out:write(IND, 'const ret = rl.', func.name, '(', list, ');', LF)
                    out:write(IND, retmapping, LF)
                    out:write(IND, 'return 1;', LF)
                end
                out:write('}', LF, LF)
            end
        else
            report_missing_param_mapping(err)
        end
    end
end

local function write_exported_functions()
    out:write("const exported_functions = [_]zlua.FnReg{\n")
    table.sort(exported_functions, function(a, b) return a.lua < b.lua end)
    for _, func in ipairs(exported_functions) do
        out:write('    .{ .name = "', func.lua, '", .func = zlua.wrap(', func.name, ') },', LF)
    end
    out:write("};\n\n")
end

--[[MAIN]]
out:write [[
const std = @import("std");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");
const rl = @import("raylib");

pub fn register(lua: *Lua) i32 {
    lua.newLib(&exported_functions);

    const exteded = @embedFile("raylib.lua");
    luax.registerExtended(lua, exteded, "raylib", "zli_raylib");
    return 1;
}

pub const rAudioBuffer = opaque {};
pub const rAudioProcessor = opaque {};

]]

write_structs()

write_functions()

write_exported_functions()

out:close()
