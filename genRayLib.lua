local io = require("io")
local F = require("F")
local spec = require("raylib_api")
local output_path = "./src/raylib.zig"

local out = assert(io.open(output_path, "wb"))

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
        local line = F 'const {name} = luax.getArgIntOrError(c_int, lua, {pos}, "expecting {name} as integer");'
        return line
    end,
    float = function(pos, name)
        local line = F 'const {name} = luax.getArgFloatOrError(lua, {pos}, "expecting {name} as number");'
        return line
    end,

    ["const char *"] = function(pos, name)
        local line = F 'const {name} = luax.getArgStringOrError(lua, {pos}, "expecting {name} as string");'
        return line
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
            local line = F('const {name} = {struct.name}_from_lua(lua, {pos});', struct)
            return line
        end

        out:write(F [[
fn {struct.name}_from_lua(lua: *Lua, index: i32) rl.struct_{struct.name} {{
    if (lua.typeOf(index) == .userdata) {{
        return (lua.toUserdata(rl.struct_{struct.name}, index) catch @panic("expecting {struct.name} object")).*;
    }
    return .{{
]])
        for _, field in ipairs(struct.fields) do
            if field.type == 'float' then
                out:write(F '        .{field.name} = luax.getArgTableFloat(lua, f32, index, "{field.name}", "expecting {struct.name} table"),\n')
            else
                out:write(F '        .{field.name} = luax.getArgTableInteger(lua, {type_mapping[field.type]}, index, "{field.name}", "expecting {struct.name} table"),\n')
                print("~~~~~", type_mapping[field.type], type_mapping[field.type]:match("rl%.struct"))
            end
        end

        out:write(F [[
    };
}

]])

        out:write(F [[
fn {struct.name}(lua: *Lua) i32 {{
    const val: *rl.struct_{struct.name} = lua.newUserdata(rl.struct_{struct.name}, 0);
    val.* = {struct.name}_from_lua(lua, 1);
    return 1;
}

]])

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

                out:write(F 'pub fn {func.name}(lua: *Lua) i32 {{\n')
                for _, param in ipairs(parameters) do
                    out:write(F '    {param}\n')
                end
                if #parameters == 0 and retmapping == 'void' then
                    out:write(F '    _ = lua;\n')
                end

                if retmapping == 'void' then
                    out:write(F '    rl.{func.name}({list});\n')
                    out:write(F '    return 0;\n')
                else
                    out:write(F '    const ret = rl.{func.name}({list});\n')
                    out:write(F '    {retmapping}\n')
                    out:write(F '    return 1;\n')
                end
                out:write('}\n\n')
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
        out:write(F '    .{{ .name = "{func.lua}", .func = zlua.wrap({func.name}) }},\n')
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
