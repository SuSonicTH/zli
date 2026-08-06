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

fn Vector2_from_lua(lua: *Lua, index: i32) rl.struct_Vector2 {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Vector2, index) catch @panic("expecting Vector2 object")).*;
    }
    return .{
        .x = luax.getArgTableFloat(lua, f32, index, "x", "expecting Vector2 table"),
        .y = luax.getArgTableFloat(lua, f32, index, "y", "expecting Vector2 table"),
    };
}

fn Vector2(lua: *Lua) i32 {
    const val: *rl.struct_Vector2 = lua.newUserdata(rl.struct_Vector2, 0);
    val.* = Vector2_from_lua(lua, 1);
    return 1;
}

fn Vector3_from_lua(lua: *Lua, index: i32) rl.struct_Vector3 {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Vector3, index) catch @panic("expecting Vector3 object")).*;
    }
    return .{
        .x = luax.getArgTableFloat(lua, f32, index, "x", "expecting Vector3 table"),
        .y = luax.getArgTableFloat(lua, f32, index, "y", "expecting Vector3 table"),
        .z = luax.getArgTableFloat(lua, f32, index, "z", "expecting Vector3 table"),
    };
}

fn Vector3(lua: *Lua) i32 {
    const val: *rl.struct_Vector3 = lua.newUserdata(rl.struct_Vector3, 0);
    val.* = Vector3_from_lua(lua, 1);
    return 1;
}

fn Vector4_from_lua(lua: *Lua, index: i32) rl.struct_Vector4 {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Vector4, index) catch @panic("expecting Vector4 object")).*;
    }
    return .{
        .x = luax.getArgTableFloat(lua, f32, index, "x", "expecting Vector4 table"),
        .y = luax.getArgTableFloat(lua, f32, index, "y", "expecting Vector4 table"),
        .z = luax.getArgTableFloat(lua, f32, index, "z", "expecting Vector4 table"),
        .w = luax.getArgTableFloat(lua, f32, index, "w", "expecting Vector4 table"),
    };
}

fn Vector4(lua: *Lua) i32 {
    const val: *rl.struct_Vector4 = lua.newUserdata(rl.struct_Vector4, 0);
    val.* = Vector4_from_lua(lua, 1);
    return 1;
}

fn Matrix_from_lua(lua: *Lua, index: i32) rl.struct_Matrix {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Matrix, index) catch @panic("expecting Matrix object")).*;
    }
    return .{
        .m0 = luax.getArgTableFloat(lua, f32, index, "m0", "expecting Matrix table"),
        .m4 = luax.getArgTableFloat(lua, f32, index, "m4", "expecting Matrix table"),
        .m8 = luax.getArgTableFloat(lua, f32, index, "m8", "expecting Matrix table"),
        .m12 = luax.getArgTableFloat(lua, f32, index, "m12", "expecting Matrix table"),
        .m1 = luax.getArgTableFloat(lua, f32, index, "m1", "expecting Matrix table"),
        .m5 = luax.getArgTableFloat(lua, f32, index, "m5", "expecting Matrix table"),
        .m9 = luax.getArgTableFloat(lua, f32, index, "m9", "expecting Matrix table"),
        .m13 = luax.getArgTableFloat(lua, f32, index, "m13", "expecting Matrix table"),
        .m2 = luax.getArgTableFloat(lua, f32, index, "m2", "expecting Matrix table"),
        .m6 = luax.getArgTableFloat(lua, f32, index, "m6", "expecting Matrix table"),
        .m10 = luax.getArgTableFloat(lua, f32, index, "m10", "expecting Matrix table"),
        .m14 = luax.getArgTableFloat(lua, f32, index, "m14", "expecting Matrix table"),
        .m3 = luax.getArgTableFloat(lua, f32, index, "m3", "expecting Matrix table"),
        .m7 = luax.getArgTableFloat(lua, f32, index, "m7", "expecting Matrix table"),
        .m11 = luax.getArgTableFloat(lua, f32, index, "m11", "expecting Matrix table"),
        .m15 = luax.getArgTableFloat(lua, f32, index, "m15", "expecting Matrix table"),
    };
}

fn Matrix(lua: *Lua) i32 {
    const val: *rl.struct_Matrix = lua.newUserdata(rl.struct_Matrix, 0);
    val.* = Matrix_from_lua(lua, 1);
    return 1;
}

fn Color_from_lua(lua: *Lua, index: i32) rl.struct_Color {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Color, index) catch @panic("expecting Color object")).*;
    }
    return .{
        .r = luax.getArgTableInteger(lua, u8, index, "r", "expecting Color table"),
        .g = luax.getArgTableInteger(lua, u8, index, "g", "expecting Color table"),
        .b = luax.getArgTableInteger(lua, u8, index, "b", "expecting Color table"),
        .a = luax.getArgTableInteger(lua, u8, index, "a", "expecting Color table"),
    };
}

fn Color(lua: *Lua) i32 {
    const val: *rl.struct_Color = lua.newUserdata(rl.struct_Color, 0);
    val.* = Color_from_lua(lua, 1);
    return 1;
}

fn Rectangle_from_lua(lua: *Lua, index: i32) rl.struct_Rectangle {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Rectangle, index) catch @panic("expecting Rectangle object")).*;
    }
    return .{
        .x = luax.getArgTableFloat(lua, f32, index, "x", "expecting Rectangle table"),
        .y = luax.getArgTableFloat(lua, f32, index, "y", "expecting Rectangle table"),
        .width = luax.getArgTableFloat(lua, f32, index, "width", "expecting Rectangle table"),
        .height = luax.getArgTableFloat(lua, f32, index, "height", "expecting Rectangle table"),
    };
}

fn Rectangle(lua: *Lua) i32 {
    const val: *rl.struct_Rectangle = lua.newUserdata(rl.struct_Rectangle, 0);
    val.* = Rectangle_from_lua(lua, 1);
    return 1;
}

fn Texture_from_lua(lua: *Lua, index: i32) rl.struct_Texture {
    if (lua.typeOf(index) == .userdata) {
        return (lua.toUserdata(rl.struct_Texture, index) catch @panic("expecting Texture object")).*;
    }
    return .{
        .id = luax.getArgTableInteger(lua, c_uint, index, "id", "expecting Texture table"),
        .width = luax.getArgTableInteger(lua, c_int, index, "width", "expecting Texture table"),
        .height = luax.getArgTableInteger(lua, c_int, index, "height", "expecting Texture table"),
        .mipmaps = luax.getArgTableInteger(lua, c_int, index, "mipmaps", "expecting Texture table"),
        .format = luax.getArgTableInteger(lua, c_int, index, "format", "expecting Texture table"),
    };
}

fn Texture(lua: *Lua) i32 {
    const val: *rl.struct_Texture = lua.newUserdata(rl.struct_Texture, 0);
    val.* = Texture_from_lua(lua, 1);
    return 1;
}

pub fn InitWindow(lua: *Lua) i32 {
    const width = luax.getArgIntOrError(c_int, lua, 1, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 2, "expecting height as integer");
    const title = luax.getArgStringOrError(lua, 3, "expecting title as string");
    rl.InitWindow(width, height, title);
    return 0;
}

pub fn CloseWindow(lua: *Lua) i32 {
    _ = lua;
    rl.CloseWindow();
    return 0;
}

pub fn WindowShouldClose(lua: *Lua) i32 {
    const ret = rl.WindowShouldClose();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowReady(lua: *Lua) i32 {
    const ret = rl.IsWindowReady();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowFullscreen(lua: *Lua) i32 {
    const ret = rl.IsWindowFullscreen();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowHidden(lua: *Lua) i32 {
    const ret = rl.IsWindowHidden();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowMinimized(lua: *Lua) i32 {
    const ret = rl.IsWindowMinimized();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowMaximized(lua: *Lua) i32 {
    const ret = rl.IsWindowMaximized();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowFocused(lua: *Lua) i32 {
    const ret = rl.IsWindowFocused();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowResized(lua: *Lua) i32 {
    const ret = rl.IsWindowResized();
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsWindowState(lua: *Lua) i32 {
    const flag = luax.getArgIntOrError(c_uint, lua, 1, "expecting flag as integer");
    const ret = rl.IsWindowState(flag);
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetWindowState(lua: *Lua) i32 {
    const flags = luax.getArgIntOrError(c_uint, lua, 1, "expecting flags as integer");
    rl.SetWindowState(flags);
    return 0;
}

pub fn ClearWindowState(lua: *Lua) i32 {
    const flags = luax.getArgIntOrError(c_uint, lua, 1, "expecting flags as integer");
    rl.ClearWindowState(flags);
    return 0;
}

pub fn ToggleFullscreen(lua: *Lua) i32 {
    _ = lua;
    rl.ToggleFullscreen();
    return 0;
}

pub fn ToggleBorderlessWindowed(lua: *Lua) i32 {
    _ = lua;
    rl.ToggleBorderlessWindowed();
    return 0;
}

pub fn MaximizeWindow(lua: *Lua) i32 {
    _ = lua;
    rl.MaximizeWindow();
    return 0;
}

pub fn MinimizeWindow(lua: *Lua) i32 {
    _ = lua;
    rl.MinimizeWindow();
    return 0;
}

pub fn RestoreWindow(lua: *Lua) i32 {
    _ = lua;
    rl.RestoreWindow();
    return 0;
}

pub fn SetWindowTitle(lua: *Lua) i32 {
    const title = luax.getArgStringOrError(lua, 1, "expecting title as string");
    rl.SetWindowTitle(title);
    return 0;
}

pub fn SetWindowPosition(lua: *Lua) i32 {
    const x = luax.getArgIntOrError(c_int, lua, 1, "expecting x as integer");
    const y = luax.getArgIntOrError(c_int, lua, 2, "expecting y as integer");
    rl.SetWindowPosition(x, y);
    return 0;
}

pub fn SetWindowMonitor(lua: *Lua) i32 {
    const monitor = luax.getArgIntOrError(c_int, lua, 1, "expecting monitor as integer");
    rl.SetWindowMonitor(monitor);
    return 0;
}

pub fn SetWindowMinSize(lua: *Lua) i32 {
    const width = luax.getArgIntOrError(c_int, lua, 1, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 2, "expecting height as integer");
    rl.SetWindowMinSize(width, height);
    return 0;
}

pub fn SetWindowMaxSize(lua: *Lua) i32 {
    const width = luax.getArgIntOrError(c_int, lua, 1, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 2, "expecting height as integer");
    rl.SetWindowMaxSize(width, height);
    return 0;
}

pub fn SetWindowSize(lua: *Lua) i32 {
    const width = luax.getArgIntOrError(c_int, lua, 1, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 2, "expecting height as integer");
    rl.SetWindowSize(width, height);
    return 0;
}

pub fn SetWindowOpacity(lua: *Lua) i32 {
    const opacity = luax.getArgFloatOrError(lua, 1, "expecting opacity as number");
    rl.SetWindowOpacity(opacity);
    return 0;
}

pub fn SetWindowFocused(lua: *Lua) i32 {
    _ = lua;
    rl.SetWindowFocused();
    return 0;
}

pub fn SetClipboardText(lua: *Lua) i32 {
    const text = luax.getArgStringOrError(lua, 1, "expecting text as string");
    rl.SetClipboardText(text);
    return 0;
}

pub fn EnableEventWaiting(lua: *Lua) i32 {
    _ = lua;
    rl.EnableEventWaiting();
    return 0;
}

pub fn DisableEventWaiting(lua: *Lua) i32 {
    _ = lua;
    rl.DisableEventWaiting();
    return 0;
}

pub fn ShowCursor(lua: *Lua) i32 {
    _ = lua;
    rl.ShowCursor();
    return 0;
}

pub fn HideCursor(lua: *Lua) i32 {
    _ = lua;
    rl.HideCursor();
    return 0;
}

pub fn IsCursorHidden(lua: *Lua) i32 {
    const ret = rl.IsCursorHidden();
    lua.pushBoolean(ret);
    return 1;
}

pub fn EnableCursor(lua: *Lua) i32 {
    _ = lua;
    rl.EnableCursor();
    return 0;
}

pub fn DisableCursor(lua: *Lua) i32 {
    _ = lua;
    rl.DisableCursor();
    return 0;
}

pub fn IsCursorOnScreen(lua: *Lua) i32 {
    const ret = rl.IsCursorOnScreen();
    lua.pushBoolean(ret);
    return 1;
}

pub fn ClearBackground(lua: *Lua) i32 {
    const color = Color_from_lua(lua, 1);
    rl.ClearBackground(color);
    return 0;
}

pub fn BeginDrawing(lua: *Lua) i32 {
    _ = lua;
    rl.BeginDrawing();
    return 0;
}

pub fn EndDrawing(lua: *Lua) i32 {
    _ = lua;
    rl.EndDrawing();
    return 0;
}

pub fn EndMode2D(lua: *Lua) i32 {
    _ = lua;
    rl.EndMode2D();
    return 0;
}

pub fn EndMode3D(lua: *Lua) i32 {
    _ = lua;
    rl.EndMode3D();
    return 0;
}

pub fn EndTextureMode(lua: *Lua) i32 {
    _ = lua;
    rl.EndTextureMode();
    return 0;
}

pub fn EndShaderMode(lua: *Lua) i32 {
    _ = lua;
    rl.EndShaderMode();
    return 0;
}

pub fn BeginBlendMode(lua: *Lua) i32 {
    const mode = luax.getArgIntOrError(c_int, lua, 1, "expecting mode as integer");
    rl.BeginBlendMode(mode);
    return 0;
}

pub fn EndBlendMode(lua: *Lua) i32 {
    _ = lua;
    rl.EndBlendMode();
    return 0;
}

pub fn BeginScissorMode(lua: *Lua) i32 {
    const x = luax.getArgIntOrError(c_int, lua, 1, "expecting x as integer");
    const y = luax.getArgIntOrError(c_int, lua, 2, "expecting y as integer");
    const width = luax.getArgIntOrError(c_int, lua, 3, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 4, "expecting height as integer");
    rl.BeginScissorMode(x, y, width, height);
    return 0;
}

pub fn EndScissorMode(lua: *Lua) i32 {
    _ = lua;
    rl.EndScissorMode();
    return 0;
}

pub fn EndVrStereoMode(lua: *Lua) i32 {
    _ = lua;
    rl.EndVrStereoMode();
    return 0;
}

pub fn SetTargetFPS(lua: *Lua) i32 {
    const fps = luax.getArgIntOrError(c_int, lua, 1, "expecting fps as integer");
    rl.SetTargetFPS(fps);
    return 0;
}

pub fn SwapScreenBuffer(lua: *Lua) i32 {
    _ = lua;
    rl.SwapScreenBuffer();
    return 0;
}

pub fn PollInputEvents(lua: *Lua) i32 {
    _ = lua;
    rl.PollInputEvents();
    return 0;
}

pub fn WaitTime(lua: *Lua) i32 {
    const seconds = luax.getArgDoubleOrError(lua, 1, "expecting seconds as number");
    rl.WaitTime(seconds);
    return 0;
}

pub fn SetRandomSeed(lua: *Lua) i32 {
    const seed = luax.getArgIntOrError(c_uint, lua, 1, "expecting seed as integer");
    rl.SetRandomSeed(seed);
    return 0;
}

pub fn UnloadRandomSequence(lua: *Lua) i32 {
    var sequence = luax.getArgIntOrError(c_int, lua, 1, "expecting sequence as integer");
    rl.UnloadRandomSequence(&sequence);
    return 0;
}

pub fn TakeScreenshot(lua: *Lua) i32 {
    const fileName = luax.getArgStringOrError(lua, 1, "expecting fileName as string");
    rl.TakeScreenshot(fileName);
    return 0;
}

pub fn SetConfigFlags(lua: *Lua) i32 {
    const flags = luax.getArgIntOrError(c_uint, lua, 1, "expecting flags as integer");
    rl.SetConfigFlags(flags);
    return 0;
}

pub fn OpenURL(lua: *Lua) i32 {
    const url = luax.getArgStringOrError(lua, 1, "expecting url as string");
    rl.OpenURL(url);
    return 0;
}

pub fn SetTraceLogLevel(lua: *Lua) i32 {
    const logLevel = luax.getArgIntOrError(c_int, lua, 1, "expecting logLevel as integer");
    rl.SetTraceLogLevel(logLevel);
    return 0;
}

pub fn UnloadFileText(lua: *Lua) i32 {
    var text = luax.getArgIntOrError(u8, lua, 1, "expecting text as integer");
    rl.UnloadFileText(&text);
    return 0;
}

pub fn SaveFileText(lua: *Lua) i32 {
    const fileName = luax.getArgStringOrError(lua, 1, "expecting fileName as string");
    const text = luax.getArgStringOrError(lua, 2, "expecting text as string");
    const ret = rl.SaveFileText(fileName, text);
    lua.pushBoolean(ret);
    return 1;
}

pub fn FileExists(lua: *Lua) i32 {
    const fileName = luax.getArgStringOrError(lua, 1, "expecting fileName as string");
    const ret = rl.FileExists(fileName);
    lua.pushBoolean(ret);
    return 1;
}

pub fn DirectoryExists(lua: *Lua) i32 {
    const dirPath = luax.getArgStringOrError(lua, 1, "expecting dirPath as string");
    const ret = rl.DirectoryExists(dirPath);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsFileExtension(lua: *Lua) i32 {
    const fileName = luax.getArgStringOrError(lua, 1, "expecting fileName as string");
    const ext = luax.getArgStringOrError(lua, 2, "expecting ext as string");
    const ret = rl.IsFileExtension(fileName, ext);
    lua.pushBoolean(ret);
    return 1;
}

pub fn ChangeDirectory(lua: *Lua) i32 {
    const dirPath = luax.getArgStringOrError(lua, 1, "expecting dirPath as string");
    const ret = rl.ChangeDirectory(dirPath);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsPathFile(lua: *Lua) i32 {
    const path = luax.getArgStringOrError(lua, 1, "expecting path as string");
    const ret = rl.IsPathFile(path);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsFileNameValid(lua: *Lua) i32 {
    const fileName = luax.getArgStringOrError(lua, 1, "expecting fileName as string");
    const ret = rl.IsFileNameValid(fileName);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsFileDropped(lua: *Lua) i32 {
    const ret = rl.IsFileDropped();
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetAutomationEventBaseFrame(lua: *Lua) i32 {
    const frame = luax.getArgIntOrError(c_int, lua, 1, "expecting frame as integer");
    rl.SetAutomationEventBaseFrame(frame);
    return 0;
}

pub fn StartAutomationEventRecording(lua: *Lua) i32 {
    _ = lua;
    rl.StartAutomationEventRecording();
    return 0;
}

pub fn StopAutomationEventRecording(lua: *Lua) i32 {
    _ = lua;
    rl.StopAutomationEventRecording();
    return 0;
}

pub fn IsKeyPressed(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    const ret = rl.IsKeyPressed(key);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsKeyPressedRepeat(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    const ret = rl.IsKeyPressedRepeat(key);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsKeyDown(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    const ret = rl.IsKeyDown(key);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsKeyReleased(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    const ret = rl.IsKeyReleased(key);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsKeyUp(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    const ret = rl.IsKeyUp(key);
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetExitKey(lua: *Lua) i32 {
    const key = luax.getArgIntOrError(c_int, lua, 1, "expecting key as integer");
    rl.SetExitKey(key);
    return 0;
}

pub fn IsGamepadAvailable(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const ret = rl.IsGamepadAvailable(gamepad);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsGamepadButtonPressed(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const button = luax.getArgIntOrError(c_int, lua, 2, "expecting button as integer");
    const ret = rl.IsGamepadButtonPressed(gamepad, button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsGamepadButtonDown(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const button = luax.getArgIntOrError(c_int, lua, 2, "expecting button as integer");
    const ret = rl.IsGamepadButtonDown(gamepad, button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsGamepadButtonReleased(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const button = luax.getArgIntOrError(c_int, lua, 2, "expecting button as integer");
    const ret = rl.IsGamepadButtonReleased(gamepad, button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsGamepadButtonUp(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const button = luax.getArgIntOrError(c_int, lua, 2, "expecting button as integer");
    const ret = rl.IsGamepadButtonUp(gamepad, button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetGamepadVibration(lua: *Lua) i32 {
    const gamepad = luax.getArgIntOrError(c_int, lua, 1, "expecting gamepad as integer");
    const leftMotor = luax.getArgFloatOrError(lua, 2, "expecting leftMotor as number");
    const rightMotor = luax.getArgFloatOrError(lua, 3, "expecting rightMotor as number");
    const duration = luax.getArgFloatOrError(lua, 4, "expecting duration as number");
    rl.SetGamepadVibration(gamepad, leftMotor, rightMotor, duration);
    return 0;
}

pub fn IsMouseButtonPressed(lua: *Lua) i32 {
    const button = luax.getArgIntOrError(c_int, lua, 1, "expecting button as integer");
    const ret = rl.IsMouseButtonPressed(button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsMouseButtonDown(lua: *Lua) i32 {
    const button = luax.getArgIntOrError(c_int, lua, 1, "expecting button as integer");
    const ret = rl.IsMouseButtonDown(button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsMouseButtonReleased(lua: *Lua) i32 {
    const button = luax.getArgIntOrError(c_int, lua, 1, "expecting button as integer");
    const ret = rl.IsMouseButtonReleased(button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn IsMouseButtonUp(lua: *Lua) i32 {
    const button = luax.getArgIntOrError(c_int, lua, 1, "expecting button as integer");
    const ret = rl.IsMouseButtonUp(button);
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetMousePosition(lua: *Lua) i32 {
    const x = luax.getArgIntOrError(c_int, lua, 1, "expecting x as integer");
    const y = luax.getArgIntOrError(c_int, lua, 2, "expecting y as integer");
    rl.SetMousePosition(x, y);
    return 0;
}

pub fn SetMouseOffset(lua: *Lua) i32 {
    const offsetX = luax.getArgIntOrError(c_int, lua, 1, "expecting offsetX as integer");
    const offsetY = luax.getArgIntOrError(c_int, lua, 2, "expecting offsetY as integer");
    rl.SetMouseOffset(offsetX, offsetY);
    return 0;
}

pub fn SetMouseScale(lua: *Lua) i32 {
    const scaleX = luax.getArgFloatOrError(lua, 1, "expecting scaleX as number");
    const scaleY = luax.getArgFloatOrError(lua, 2, "expecting scaleY as number");
    rl.SetMouseScale(scaleX, scaleY);
    return 0;
}

pub fn SetMouseCursor(lua: *Lua) i32 {
    const cursor = luax.getArgIntOrError(c_int, lua, 1, "expecting cursor as integer");
    rl.SetMouseCursor(cursor);
    return 0;
}

pub fn SetGesturesEnabled(lua: *Lua) i32 {
    const flags = luax.getArgIntOrError(c_uint, lua, 1, "expecting flags as integer");
    rl.SetGesturesEnabled(flags);
    return 0;
}

pub fn IsGestureDetected(lua: *Lua) i32 {
    const gesture = luax.getArgIntOrError(c_uint, lua, 1, "expecting gesture as integer");
    const ret = rl.IsGestureDetected(gesture);
    lua.pushBoolean(ret);
    return 1;
}

pub fn DrawPixel(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    const color = Color_from_lua(lua, 3);
    rl.DrawPixel(posX, posY, color);
    return 0;
}

pub fn DrawPixelV(lua: *Lua) i32 {
    const position = Vector2_from_lua(lua, 1);
    const color = Color_from_lua(lua, 2);
    rl.DrawPixelV(position, color);
    return 0;
}

pub fn DrawLine(lua: *Lua) i32 {
    const startPosX = luax.getArgIntOrError(c_int, lua, 1, "expecting startPosX as integer");
    const startPosY = luax.getArgIntOrError(c_int, lua, 2, "expecting startPosY as integer");
    const endPosX = luax.getArgIntOrError(c_int, lua, 3, "expecting endPosX as integer");
    const endPosY = luax.getArgIntOrError(c_int, lua, 4, "expecting endPosY as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawLine(startPosX, startPosY, endPosX, endPosY, color);
    return 0;
}

pub fn DrawLineV(lua: *Lua) i32 {
    const startPos = Vector2_from_lua(lua, 1);
    const endPos = Vector2_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawLineV(startPos, endPos, color);
    return 0;
}

pub fn DrawLineEx(lua: *Lua) i32 {
    const startPos = Vector2_from_lua(lua, 1);
    const endPos = Vector2_from_lua(lua, 2);
    const thick = luax.getArgFloatOrError(lua, 3, "expecting thick as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawLineEx(startPos, endPos, thick, color);
    return 0;
}

pub fn DrawLineBezier(lua: *Lua) i32 {
    const startPos = Vector2_from_lua(lua, 1);
    const endPos = Vector2_from_lua(lua, 2);
    const thick = luax.getArgFloatOrError(lua, 3, "expecting thick as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawLineBezier(startPos, endPos, thick, color);
    return 0;
}

pub fn DrawLineDashed(lua: *Lua) i32 {
    const startPos = Vector2_from_lua(lua, 1);
    const endPos = Vector2_from_lua(lua, 2);
    const dashSize = luax.getArgIntOrError(c_int, lua, 3, "expecting dashSize as integer");
    const spaceSize = luax.getArgIntOrError(c_int, lua, 4, "expecting spaceSize as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawLineDashed(startPos, endPos, dashSize, spaceSize, color);
    return 0;
}

pub fn DrawCircle(lua: *Lua) i32 {
    const centerX = luax.getArgIntOrError(c_int, lua, 1, "expecting centerX as integer");
    const centerY = luax.getArgIntOrError(c_int, lua, 2, "expecting centerY as integer");
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawCircle(centerX, centerY, radius, color);
    return 0;
}

pub fn DrawCircleV(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const color = Color_from_lua(lua, 3);
    rl.DrawCircleV(center, radius, color);
    return 0;
}

pub fn DrawCircleGradient(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const inner = Color_from_lua(lua, 3);
    const outer = Color_from_lua(lua, 4);
    rl.DrawCircleGradient(center, radius, inner, outer);
    return 0;
}

pub fn DrawCircleSector(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const startAngle = luax.getArgFloatOrError(lua, 3, "expecting startAngle as number");
    const endAngle = luax.getArgFloatOrError(lua, 4, "expecting endAngle as number");
    const segments = luax.getArgIntOrError(c_int, lua, 5, "expecting segments as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCircleSector(center, radius, startAngle, endAngle, segments, color);
    return 0;
}

pub fn DrawCircleSectorLines(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const startAngle = luax.getArgFloatOrError(lua, 3, "expecting startAngle as number");
    const endAngle = luax.getArgFloatOrError(lua, 4, "expecting endAngle as number");
    const segments = luax.getArgIntOrError(c_int, lua, 5, "expecting segments as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCircleSectorLines(center, radius, startAngle, endAngle, segments, color);
    return 0;
}

pub fn DrawCircleLines(lua: *Lua) i32 {
    const centerX = luax.getArgIntOrError(c_int, lua, 1, "expecting centerX as integer");
    const centerY = luax.getArgIntOrError(c_int, lua, 2, "expecting centerY as integer");
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawCircleLines(centerX, centerY, radius, color);
    return 0;
}

pub fn DrawCircleLinesV(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const color = Color_from_lua(lua, 3);
    rl.DrawCircleLinesV(center, radius, color);
    return 0;
}

pub fn DrawEllipse(lua: *Lua) i32 {
    const centerX = luax.getArgIntOrError(c_int, lua, 1, "expecting centerX as integer");
    const centerY = luax.getArgIntOrError(c_int, lua, 2, "expecting centerY as integer");
    const radiusH = luax.getArgFloatOrError(lua, 3, "expecting radiusH as number");
    const radiusV = luax.getArgFloatOrError(lua, 4, "expecting radiusV as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawEllipse(centerX, centerY, radiusH, radiusV, color);
    return 0;
}

pub fn DrawEllipseV(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radiusH = luax.getArgFloatOrError(lua, 2, "expecting radiusH as number");
    const radiusV = luax.getArgFloatOrError(lua, 3, "expecting radiusV as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawEllipseV(center, radiusH, radiusV, color);
    return 0;
}

pub fn DrawEllipseLines(lua: *Lua) i32 {
    const centerX = luax.getArgIntOrError(c_int, lua, 1, "expecting centerX as integer");
    const centerY = luax.getArgIntOrError(c_int, lua, 2, "expecting centerY as integer");
    const radiusH = luax.getArgFloatOrError(lua, 3, "expecting radiusH as number");
    const radiusV = luax.getArgFloatOrError(lua, 4, "expecting radiusV as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawEllipseLines(centerX, centerY, radiusH, radiusV, color);
    return 0;
}

pub fn DrawEllipseLinesV(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radiusH = luax.getArgFloatOrError(lua, 2, "expecting radiusH as number");
    const radiusV = luax.getArgFloatOrError(lua, 3, "expecting radiusV as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawEllipseLinesV(center, radiusH, radiusV, color);
    return 0;
}

pub fn DrawRing(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const innerRadius = luax.getArgFloatOrError(lua, 2, "expecting innerRadius as number");
    const outerRadius = luax.getArgFloatOrError(lua, 3, "expecting outerRadius as number");
    const startAngle = luax.getArgFloatOrError(lua, 4, "expecting startAngle as number");
    const endAngle = luax.getArgFloatOrError(lua, 5, "expecting endAngle as number");
    const segments = luax.getArgIntOrError(c_int, lua, 6, "expecting segments as integer");
    const color = Color_from_lua(lua, 7);
    rl.DrawRing(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
    return 0;
}

pub fn DrawRingLines(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const innerRadius = luax.getArgFloatOrError(lua, 2, "expecting innerRadius as number");
    const outerRadius = luax.getArgFloatOrError(lua, 3, "expecting outerRadius as number");
    const startAngle = luax.getArgFloatOrError(lua, 4, "expecting startAngle as number");
    const endAngle = luax.getArgFloatOrError(lua, 5, "expecting endAngle as number");
    const segments = luax.getArgIntOrError(c_int, lua, 6, "expecting segments as integer");
    const color = Color_from_lua(lua, 7);
    rl.DrawRingLines(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
    return 0;
}

pub fn DrawRectangle(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    const width = luax.getArgIntOrError(c_int, lua, 3, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 4, "expecting height as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawRectangle(posX, posY, width, height, color);
    return 0;
}

pub fn DrawRectangleV(lua: *Lua) i32 {
    const position = Vector2_from_lua(lua, 1);
    const size = Vector2_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawRectangleV(position, size, color);
    return 0;
}

pub fn DrawRectangleRec(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const color = Color_from_lua(lua, 2);
    rl.DrawRectangleRec(rec, color);
    return 0;
}

pub fn DrawRectanglePro(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const origin = Vector2_from_lua(lua, 2);
    const rotation = luax.getArgFloatOrError(lua, 3, "expecting rotation as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawRectanglePro(rec, origin, rotation, color);
    return 0;
}

pub fn DrawRectangleGradientV(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    const width = luax.getArgIntOrError(c_int, lua, 3, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 4, "expecting height as integer");
    const top = Color_from_lua(lua, 5);
    const bottom = Color_from_lua(lua, 6);
    rl.DrawRectangleGradientV(posX, posY, width, height, top, bottom);
    return 0;
}

pub fn DrawRectangleGradientH(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    const width = luax.getArgIntOrError(c_int, lua, 3, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 4, "expecting height as integer");
    const left = Color_from_lua(lua, 5);
    const right = Color_from_lua(lua, 6);
    rl.DrawRectangleGradientH(posX, posY, width, height, left, right);
    return 0;
}

pub fn DrawRectangleGradientEx(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const topLeft = Color_from_lua(lua, 2);
    const bottomLeft = Color_from_lua(lua, 3);
    const bottomRight = Color_from_lua(lua, 4);
    const topRight = Color_from_lua(lua, 5);
    rl.DrawRectangleGradientEx(rec, topLeft, bottomLeft, bottomRight, topRight);
    return 0;
}

pub fn DrawRectangleLines(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    const width = luax.getArgIntOrError(c_int, lua, 3, "expecting width as integer");
    const height = luax.getArgIntOrError(c_int, lua, 4, "expecting height as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawRectangleLines(posX, posY, width, height, color);
    return 0;
}

pub fn DrawRectangleLinesEx(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const lineThick = luax.getArgFloatOrError(lua, 2, "expecting lineThick as number");
    const color = Color_from_lua(lua, 3);
    rl.DrawRectangleLinesEx(rec, lineThick, color);
    return 0;
}

pub fn DrawRectangleRounded(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const roundness = luax.getArgFloatOrError(lua, 2, "expecting roundness as number");
    const segments = luax.getArgIntOrError(c_int, lua, 3, "expecting segments as integer");
    const color = Color_from_lua(lua, 4);
    rl.DrawRectangleRounded(rec, roundness, segments, color);
    return 0;
}

pub fn DrawRectangleRoundedLines(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const roundness = luax.getArgFloatOrError(lua, 2, "expecting roundness as number");
    const segments = luax.getArgIntOrError(c_int, lua, 3, "expecting segments as integer");
    const color = Color_from_lua(lua, 4);
    rl.DrawRectangleRoundedLines(rec, roundness, segments, color);
    return 0;
}

pub fn DrawRectangleRoundedLinesEx(lua: *Lua) i32 {
    const rec = Rectangle_from_lua(lua, 1);
    const roundness = luax.getArgFloatOrError(lua, 2, "expecting roundness as number");
    const segments = luax.getArgIntOrError(c_int, lua, 3, "expecting segments as integer");
    const lineThick = luax.getArgFloatOrError(lua, 4, "expecting lineThick as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawRectangleRoundedLinesEx(rec, roundness, segments, lineThick, color);
    return 0;
}

pub fn DrawTriangle(lua: *Lua) i32 {
    const v1 = Vector2_from_lua(lua, 1);
    const v2 = Vector2_from_lua(lua, 2);
    const v3 = Vector2_from_lua(lua, 3);
    const color = Color_from_lua(lua, 4);
    rl.DrawTriangle(v1, v2, v3, color);
    return 0;
}

pub fn DrawTriangleLines(lua: *Lua) i32 {
    const v1 = Vector2_from_lua(lua, 1);
    const v2 = Vector2_from_lua(lua, 2);
    const v3 = Vector2_from_lua(lua, 3);
    const color = Color_from_lua(lua, 4);
    rl.DrawTriangleLines(v1, v2, v3, color);
    return 0;
}

pub fn DrawPoly(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const sides = luax.getArgIntOrError(c_int, lua, 2, "expecting sides as integer");
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const rotation = luax.getArgFloatOrError(lua, 4, "expecting rotation as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawPoly(center, sides, radius, rotation, color);
    return 0;
}

pub fn DrawPolyLines(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const sides = luax.getArgIntOrError(c_int, lua, 2, "expecting sides as integer");
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const rotation = luax.getArgFloatOrError(lua, 4, "expecting rotation as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawPolyLines(center, sides, radius, rotation, color);
    return 0;
}

pub fn DrawPolyLinesEx(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const sides = luax.getArgIntOrError(c_int, lua, 2, "expecting sides as integer");
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const rotation = luax.getArgFloatOrError(lua, 4, "expecting rotation as number");
    const lineThick = luax.getArgFloatOrError(lua, 5, "expecting lineThick as number");
    const color = Color_from_lua(lua, 6);
    rl.DrawPolyLinesEx(center, sides, radius, rotation, lineThick, color);
    return 0;
}

pub fn DrawSplineSegmentLinear(lua: *Lua) i32 {
    const p1 = Vector2_from_lua(lua, 1);
    const p2 = Vector2_from_lua(lua, 2);
    const thick = luax.getArgFloatOrError(lua, 3, "expecting thick as number");
    const color = Color_from_lua(lua, 4);
    rl.DrawSplineSegmentLinear(p1, p2, thick, color);
    return 0;
}

pub fn DrawSplineSegmentBasis(lua: *Lua) i32 {
    const p1 = Vector2_from_lua(lua, 1);
    const p2 = Vector2_from_lua(lua, 2);
    const p3 = Vector2_from_lua(lua, 3);
    const p4 = Vector2_from_lua(lua, 4);
    const thick = luax.getArgFloatOrError(lua, 5, "expecting thick as number");
    const color = Color_from_lua(lua, 6);
    rl.DrawSplineSegmentBasis(p1, p2, p3, p4, thick, color);
    return 0;
}

pub fn DrawSplineSegmentCatmullRom(lua: *Lua) i32 {
    const p1 = Vector2_from_lua(lua, 1);
    const p2 = Vector2_from_lua(lua, 2);
    const p3 = Vector2_from_lua(lua, 3);
    const p4 = Vector2_from_lua(lua, 4);
    const thick = luax.getArgFloatOrError(lua, 5, "expecting thick as number");
    const color = Color_from_lua(lua, 6);
    rl.DrawSplineSegmentCatmullRom(p1, p2, p3, p4, thick, color);
    return 0;
}

pub fn DrawSplineSegmentBezierQuadratic(lua: *Lua) i32 {
    const p1 = Vector2_from_lua(lua, 1);
    const c2 = Vector2_from_lua(lua, 2);
    const p3 = Vector2_from_lua(lua, 3);
    const thick = luax.getArgFloatOrError(lua, 4, "expecting thick as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawSplineSegmentBezierQuadratic(p1, c2, p3, thick, color);
    return 0;
}

pub fn DrawSplineSegmentBezierCubic(lua: *Lua) i32 {
    const p1 = Vector2_from_lua(lua, 1);
    const c2 = Vector2_from_lua(lua, 2);
    const c3 = Vector2_from_lua(lua, 3);
    const p4 = Vector2_from_lua(lua, 4);
    const thick = luax.getArgFloatOrError(lua, 5, "expecting thick as number");
    const color = Color_from_lua(lua, 6);
    rl.DrawSplineSegmentBezierCubic(p1, c2, c3, p4, thick, color);
    return 0;
}

pub fn CheckCollisionRecs(lua: *Lua) i32 {
    const rec1 = Rectangle_from_lua(lua, 1);
    const rec2 = Rectangle_from_lua(lua, 2);
    const ret = rl.CheckCollisionRecs(rec1, rec2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionCircles(lua: *Lua) i32 {
    const center1 = Vector2_from_lua(lua, 1);
    const radius1 = luax.getArgFloatOrError(lua, 2, "expecting radius1 as number");
    const center2 = Vector2_from_lua(lua, 3);
    const radius2 = luax.getArgFloatOrError(lua, 4, "expecting radius2 as number");
    const ret = rl.CheckCollisionCircles(center1, radius1, center2, radius2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionCircleRec(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const rec = Rectangle_from_lua(lua, 3);
    const ret = rl.CheckCollisionCircleRec(center, radius, rec);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionCircleLine(lua: *Lua) i32 {
    const center = Vector2_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const p1 = Vector2_from_lua(lua, 3);
    const p2 = Vector2_from_lua(lua, 4);
    const ret = rl.CheckCollisionCircleLine(center, radius, p1, p2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionPointRec(lua: *Lua) i32 {
    const point = Vector2_from_lua(lua, 1);
    const rec = Rectangle_from_lua(lua, 2);
    const ret = rl.CheckCollisionPointRec(point, rec);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionPointCircle(lua: *Lua) i32 {
    const point = Vector2_from_lua(lua, 1);
    const center = Vector2_from_lua(lua, 2);
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const ret = rl.CheckCollisionPointCircle(point, center, radius);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionPointTriangle(lua: *Lua) i32 {
    const point = Vector2_from_lua(lua, 1);
    const p1 = Vector2_from_lua(lua, 2);
    const p2 = Vector2_from_lua(lua, 3);
    const p3 = Vector2_from_lua(lua, 4);
    const ret = rl.CheckCollisionPointTriangle(point, p1, p2, p3);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionPointLine(lua: *Lua) i32 {
    const point = Vector2_from_lua(lua, 1);
    const p1 = Vector2_from_lua(lua, 2);
    const p2 = Vector2_from_lua(lua, 3);
    const threshold = luax.getArgIntOrError(c_int, lua, 4, "expecting threshold as integer");
    const ret = rl.CheckCollisionPointLine(point, p1, p2, threshold);
    lua.pushBoolean(ret);
    return 1;
}

pub fn CheckCollisionLines(lua: *Lua) i32 {
    const startPos1 = Vector2_from_lua(lua, 1);
    const endPos1 = Vector2_from_lua(lua, 2);
    const startPos2 = Vector2_from_lua(lua, 3);
    const endPos2 = Vector2_from_lua(lua, 4);
    var collisionPoint = Vector2_from_lua(lua, 5);
    const ret = rl.CheckCollisionLines(startPos1, endPos1, startPos2, endPos2, &collisionPoint);
    lua.pushBoolean(ret);
    return 1;
}

pub fn UnloadImageColors(lua: *Lua) i32 {
    var colors = Color_from_lua(lua, 1);
    rl.UnloadImageColors(&colors);
    return 0;
}

pub fn UnloadImagePalette(lua: *Lua) i32 {
    var colors = Color_from_lua(lua, 1);
    rl.UnloadImagePalette(&colors);
    return 0;
}

pub fn ColorIsEqual(lua: *Lua) i32 {
    const col1 = Color_from_lua(lua, 1);
    const col2 = Color_from_lua(lua, 2);
    const ret = rl.ColorIsEqual(col1, col2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn DrawFPS(lua: *Lua) i32 {
    const posX = luax.getArgIntOrError(c_int, lua, 1, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 2, "expecting posY as integer");
    rl.DrawFPS(posX, posY);
    return 0;
}

pub fn DrawText(lua: *Lua) i32 {
    const text = luax.getArgStringOrError(lua, 1, "expecting text as string");
    const posX = luax.getArgIntOrError(c_int, lua, 2, "expecting posX as integer");
    const posY = luax.getArgIntOrError(c_int, lua, 3, "expecting posY as integer");
    const fontSize = luax.getArgIntOrError(c_int, lua, 4, "expecting fontSize as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawText(text, posX, posY, fontSize, color);
    return 0;
}

pub fn SetTextLineSpacing(lua: *Lua) i32 {
    const spacing = luax.getArgIntOrError(c_int, lua, 1, "expecting spacing as integer");
    rl.SetTextLineSpacing(spacing);
    return 0;
}

pub fn UnloadUTF8(lua: *Lua) i32 {
    var text = luax.getArgIntOrError(u8, lua, 1, "expecting text as integer");
    rl.UnloadUTF8(&text);
    return 0;
}

pub fn UnloadCodepoints(lua: *Lua) i32 {
    var codepoints = luax.getArgIntOrError(c_int, lua, 1, "expecting codepoints as integer");
    rl.UnloadCodepoints(&codepoints);
    return 0;
}

pub fn TextIsEqual(lua: *Lua) i32 {
    const text1 = luax.getArgStringOrError(lua, 1, "expecting text1 as string");
    const text2 = luax.getArgStringOrError(lua, 2, "expecting text2 as string");
    const ret = rl.TextIsEqual(text1, text2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn TextAppend(lua: *Lua) i32 {
    var text = luax.getArgIntOrError(u8, lua, 1, "expecting text as integer");
    const append = luax.getArgStringOrError(lua, 2, "expecting append as string");
    var position = luax.getArgIntOrError(c_int, lua, 3, "expecting position as integer");
    rl.TextAppend(&text, append, &position);
    return 0;
}

pub fn DrawLine3D(lua: *Lua) i32 {
    const startPos = Vector3_from_lua(lua, 1);
    const endPos = Vector3_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawLine3D(startPos, endPos, color);
    return 0;
}

pub fn DrawPoint3D(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const color = Color_from_lua(lua, 2);
    rl.DrawPoint3D(position, color);
    return 0;
}

pub fn DrawCircle3D(lua: *Lua) i32 {
    const center = Vector3_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const rotationAxis = Vector3_from_lua(lua, 3);
    const rotationAngle = luax.getArgFloatOrError(lua, 4, "expecting rotationAngle as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawCircle3D(center, radius, rotationAxis, rotationAngle, color);
    return 0;
}

pub fn DrawTriangle3D(lua: *Lua) i32 {
    const v1 = Vector3_from_lua(lua, 1);
    const v2 = Vector3_from_lua(lua, 2);
    const v3 = Vector3_from_lua(lua, 3);
    const color = Color_from_lua(lua, 4);
    rl.DrawTriangle3D(v1, v2, v3, color);
    return 0;
}

pub fn DrawCube(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const width = luax.getArgFloatOrError(lua, 2, "expecting width as number");
    const height = luax.getArgFloatOrError(lua, 3, "expecting height as number");
    const length = luax.getArgFloatOrError(lua, 4, "expecting length as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawCube(position, width, height, length, color);
    return 0;
}

pub fn DrawCubeV(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const size = Vector3_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawCubeV(position, size, color);
    return 0;
}

pub fn DrawCubeWires(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const width = luax.getArgFloatOrError(lua, 2, "expecting width as number");
    const height = luax.getArgFloatOrError(lua, 3, "expecting height as number");
    const length = luax.getArgFloatOrError(lua, 4, "expecting length as number");
    const color = Color_from_lua(lua, 5);
    rl.DrawCubeWires(position, width, height, length, color);
    return 0;
}

pub fn DrawCubeWiresV(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const size = Vector3_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawCubeWiresV(position, size, color);
    return 0;
}

pub fn DrawSphere(lua: *Lua) i32 {
    const centerPos = Vector3_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const color = Color_from_lua(lua, 3);
    rl.DrawSphere(centerPos, radius, color);
    return 0;
}

pub fn DrawSphereEx(lua: *Lua) i32 {
    const centerPos = Vector3_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const rings = luax.getArgIntOrError(c_int, lua, 3, "expecting rings as integer");
    const slices = luax.getArgIntOrError(c_int, lua, 4, "expecting slices as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawSphereEx(centerPos, radius, rings, slices, color);
    return 0;
}

pub fn DrawSphereWires(lua: *Lua) i32 {
    const centerPos = Vector3_from_lua(lua, 1);
    const radius = luax.getArgFloatOrError(lua, 2, "expecting radius as number");
    const rings = luax.getArgIntOrError(c_int, lua, 3, "expecting rings as integer");
    const slices = luax.getArgIntOrError(c_int, lua, 4, "expecting slices as integer");
    const color = Color_from_lua(lua, 5);
    rl.DrawSphereWires(centerPos, radius, rings, slices, color);
    return 0;
}

pub fn DrawCylinder(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const radiusTop = luax.getArgFloatOrError(lua, 2, "expecting radiusTop as number");
    const radiusBottom = luax.getArgFloatOrError(lua, 3, "expecting radiusBottom as number");
    const height = luax.getArgFloatOrError(lua, 4, "expecting height as number");
    const slices = luax.getArgIntOrError(c_int, lua, 5, "expecting slices as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCylinder(position, radiusTop, radiusBottom, height, slices, color);
    return 0;
}

pub fn DrawCylinderEx(lua: *Lua) i32 {
    const startPos = Vector3_from_lua(lua, 1);
    const endPos = Vector3_from_lua(lua, 2);
    const startRadius = luax.getArgFloatOrError(lua, 3, "expecting startRadius as number");
    const endRadius = luax.getArgFloatOrError(lua, 4, "expecting endRadius as number");
    const sides = luax.getArgIntOrError(c_int, lua, 5, "expecting sides as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCylinderEx(startPos, endPos, startRadius, endRadius, sides, color);
    return 0;
}

pub fn DrawCylinderWires(lua: *Lua) i32 {
    const position = Vector3_from_lua(lua, 1);
    const radiusTop = luax.getArgFloatOrError(lua, 2, "expecting radiusTop as number");
    const radiusBottom = luax.getArgFloatOrError(lua, 3, "expecting radiusBottom as number");
    const height = luax.getArgFloatOrError(lua, 4, "expecting height as number");
    const slices = luax.getArgIntOrError(c_int, lua, 5, "expecting slices as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCylinderWires(position, radiusTop, radiusBottom, height, slices, color);
    return 0;
}

pub fn DrawCylinderWiresEx(lua: *Lua) i32 {
    const startPos = Vector3_from_lua(lua, 1);
    const endPos = Vector3_from_lua(lua, 2);
    const startRadius = luax.getArgFloatOrError(lua, 3, "expecting startRadius as number");
    const endRadius = luax.getArgFloatOrError(lua, 4, "expecting endRadius as number");
    const sides = luax.getArgIntOrError(c_int, lua, 5, "expecting sides as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCylinderWiresEx(startPos, endPos, startRadius, endRadius, sides, color);
    return 0;
}

pub fn DrawCapsule(lua: *Lua) i32 {
    const startPos = Vector3_from_lua(lua, 1);
    const endPos = Vector3_from_lua(lua, 2);
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const slices = luax.getArgIntOrError(c_int, lua, 4, "expecting slices as integer");
    const rings = luax.getArgIntOrError(c_int, lua, 5, "expecting rings as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCapsule(startPos, endPos, radius, slices, rings, color);
    return 0;
}

pub fn DrawCapsuleWires(lua: *Lua) i32 {
    const startPos = Vector3_from_lua(lua, 1);
    const endPos = Vector3_from_lua(lua, 2);
    const radius = luax.getArgFloatOrError(lua, 3, "expecting radius as number");
    const slices = luax.getArgIntOrError(c_int, lua, 4, "expecting slices as integer");
    const rings = luax.getArgIntOrError(c_int, lua, 5, "expecting rings as integer");
    const color = Color_from_lua(lua, 6);
    rl.DrawCapsuleWires(startPos, endPos, radius, slices, rings, color);
    return 0;
}

pub fn DrawPlane(lua: *Lua) i32 {
    const centerPos = Vector3_from_lua(lua, 1);
    const size = Vector2_from_lua(lua, 2);
    const color = Color_from_lua(lua, 3);
    rl.DrawPlane(centerPos, size, color);
    return 0;
}

pub fn DrawGrid(lua: *Lua) i32 {
    const slices = luax.getArgIntOrError(c_int, lua, 1, "expecting slices as integer");
    const spacing = luax.getArgFloatOrError(lua, 2, "expecting spacing as number");
    rl.DrawGrid(slices, spacing);
    return 0;
}

pub fn CheckCollisionSpheres(lua: *Lua) i32 {
    const center1 = Vector3_from_lua(lua, 1);
    const radius1 = luax.getArgFloatOrError(lua, 2, "expecting radius1 as number");
    const center2 = Vector3_from_lua(lua, 3);
    const radius2 = luax.getArgFloatOrError(lua, 4, "expecting radius2 as number");
    const ret = rl.CheckCollisionSpheres(center1, radius1, center2, radius2);
    lua.pushBoolean(ret);
    return 1;
}

pub fn InitAudioDevice(lua: *Lua) i32 {
    _ = lua;
    rl.InitAudioDevice();
    return 0;
}

pub fn CloseAudioDevice(lua: *Lua) i32 {
    _ = lua;
    rl.CloseAudioDevice();
    return 0;
}

pub fn IsAudioDeviceReady(lua: *Lua) i32 {
    const ret = rl.IsAudioDeviceReady();
    lua.pushBoolean(ret);
    return 1;
}

pub fn SetMasterVolume(lua: *Lua) i32 {
    const volume = luax.getArgFloatOrError(lua, 1, "expecting volume as number");
    rl.SetMasterVolume(volume);
    return 0;
}

pub fn UnloadWaveSamples(lua: *Lua) i32 {
    var samples = luax.getArgFloatOrError(lua, 1, "expecting samples as number");
    rl.UnloadWaveSamples(&samples);
    return 0;
}

pub fn SetAudioStreamBufferSizeDefault(lua: *Lua) i32 {
    const size = luax.getArgIntOrError(c_int, lua, 1, "expecting size as integer");
    rl.SetAudioStreamBufferSizeDefault(size);
    return 0;
}

const exported_functions = [_]zlua.FnReg{
    .{ .name = "Color", .func = zlua.wrap(Color) },
    .{ .name = "Matrix", .func = zlua.wrap(Matrix) },
    .{ .name = "Rectangle", .func = zlua.wrap(Rectangle) },
    .{ .name = "Texture", .func = zlua.wrap(Texture) },
    .{ .name = "Vector2", .func = zlua.wrap(Vector2) },
    .{ .name = "Vector3", .func = zlua.wrap(Vector3) },
    .{ .name = "Vector4", .func = zlua.wrap(Vector4) },
    .{ .name = "beginBlendMode", .func = zlua.wrap(BeginBlendMode) },
    .{ .name = "beginDrawing", .func = zlua.wrap(BeginDrawing) },
    .{ .name = "beginScissorMode", .func = zlua.wrap(BeginScissorMode) },
    .{ .name = "changeDirectory", .func = zlua.wrap(ChangeDirectory) },
    .{ .name = "checkCollisionCircleLine", .func = zlua.wrap(CheckCollisionCircleLine) },
    .{ .name = "checkCollisionCircleRec", .func = zlua.wrap(CheckCollisionCircleRec) },
    .{ .name = "checkCollisionCircles", .func = zlua.wrap(CheckCollisionCircles) },
    .{ .name = "checkCollisionLines", .func = zlua.wrap(CheckCollisionLines) },
    .{ .name = "checkCollisionPointCircle", .func = zlua.wrap(CheckCollisionPointCircle) },
    .{ .name = "checkCollisionPointLine", .func = zlua.wrap(CheckCollisionPointLine) },
    .{ .name = "checkCollisionPointRec", .func = zlua.wrap(CheckCollisionPointRec) },
    .{ .name = "checkCollisionPointTriangle", .func = zlua.wrap(CheckCollisionPointTriangle) },
    .{ .name = "checkCollisionRecs", .func = zlua.wrap(CheckCollisionRecs) },
    .{ .name = "checkCollisionSpheres", .func = zlua.wrap(CheckCollisionSpheres) },
    .{ .name = "clearBackground", .func = zlua.wrap(ClearBackground) },
    .{ .name = "clearWindowState", .func = zlua.wrap(ClearWindowState) },
    .{ .name = "closeAudioDevice", .func = zlua.wrap(CloseAudioDevice) },
    .{ .name = "closeWindow", .func = zlua.wrap(CloseWindow) },
    .{ .name = "colorIsEqual", .func = zlua.wrap(ColorIsEqual) },
    .{ .name = "directoryExists", .func = zlua.wrap(DirectoryExists) },
    .{ .name = "disableCursor", .func = zlua.wrap(DisableCursor) },
    .{ .name = "disableEventWaiting", .func = zlua.wrap(DisableEventWaiting) },
    .{ .name = "drawCapsule", .func = zlua.wrap(DrawCapsule) },
    .{ .name = "drawCapsuleWires", .func = zlua.wrap(DrawCapsuleWires) },
    .{ .name = "drawCircle", .func = zlua.wrap(DrawCircle) },
    .{ .name = "drawCircle3D", .func = zlua.wrap(DrawCircle3D) },
    .{ .name = "drawCircleGradient", .func = zlua.wrap(DrawCircleGradient) },
    .{ .name = "drawCircleLines", .func = zlua.wrap(DrawCircleLines) },
    .{ .name = "drawCircleLinesV", .func = zlua.wrap(DrawCircleLinesV) },
    .{ .name = "drawCircleSector", .func = zlua.wrap(DrawCircleSector) },
    .{ .name = "drawCircleSectorLines", .func = zlua.wrap(DrawCircleSectorLines) },
    .{ .name = "drawCircleV", .func = zlua.wrap(DrawCircleV) },
    .{ .name = "drawCube", .func = zlua.wrap(DrawCube) },
    .{ .name = "drawCubeV", .func = zlua.wrap(DrawCubeV) },
    .{ .name = "drawCubeWires", .func = zlua.wrap(DrawCubeWires) },
    .{ .name = "drawCubeWiresV", .func = zlua.wrap(DrawCubeWiresV) },
    .{ .name = "drawCylinder", .func = zlua.wrap(DrawCylinder) },
    .{ .name = "drawCylinderEx", .func = zlua.wrap(DrawCylinderEx) },
    .{ .name = "drawCylinderWires", .func = zlua.wrap(DrawCylinderWires) },
    .{ .name = "drawCylinderWiresEx", .func = zlua.wrap(DrawCylinderWiresEx) },
    .{ .name = "drawEllipse", .func = zlua.wrap(DrawEllipse) },
    .{ .name = "drawEllipseLines", .func = zlua.wrap(DrawEllipseLines) },
    .{ .name = "drawEllipseLinesV", .func = zlua.wrap(DrawEllipseLinesV) },
    .{ .name = "drawEllipseV", .func = zlua.wrap(DrawEllipseV) },
    .{ .name = "drawFPS", .func = zlua.wrap(DrawFPS) },
    .{ .name = "drawGrid", .func = zlua.wrap(DrawGrid) },
    .{ .name = "drawLine", .func = zlua.wrap(DrawLine) },
    .{ .name = "drawLine3D", .func = zlua.wrap(DrawLine3D) },
    .{ .name = "drawLineBezier", .func = zlua.wrap(DrawLineBezier) },
    .{ .name = "drawLineDashed", .func = zlua.wrap(DrawLineDashed) },
    .{ .name = "drawLineEx", .func = zlua.wrap(DrawLineEx) },
    .{ .name = "drawLineV", .func = zlua.wrap(DrawLineV) },
    .{ .name = "drawPixel", .func = zlua.wrap(DrawPixel) },
    .{ .name = "drawPixelV", .func = zlua.wrap(DrawPixelV) },
    .{ .name = "drawPlane", .func = zlua.wrap(DrawPlane) },
    .{ .name = "drawPoint3D", .func = zlua.wrap(DrawPoint3D) },
    .{ .name = "drawPoly", .func = zlua.wrap(DrawPoly) },
    .{ .name = "drawPolyLines", .func = zlua.wrap(DrawPolyLines) },
    .{ .name = "drawPolyLinesEx", .func = zlua.wrap(DrawPolyLinesEx) },
    .{ .name = "drawRectangle", .func = zlua.wrap(DrawRectangle) },
    .{ .name = "drawRectangleGradientEx", .func = zlua.wrap(DrawRectangleGradientEx) },
    .{ .name = "drawRectangleGradientH", .func = zlua.wrap(DrawRectangleGradientH) },
    .{ .name = "drawRectangleGradientV", .func = zlua.wrap(DrawRectangleGradientV) },
    .{ .name = "drawRectangleLines", .func = zlua.wrap(DrawRectangleLines) },
    .{ .name = "drawRectangleLinesEx", .func = zlua.wrap(DrawRectangleLinesEx) },
    .{ .name = "drawRectanglePro", .func = zlua.wrap(DrawRectanglePro) },
    .{ .name = "drawRectangleRec", .func = zlua.wrap(DrawRectangleRec) },
    .{ .name = "drawRectangleRounded", .func = zlua.wrap(DrawRectangleRounded) },
    .{ .name = "drawRectangleRoundedLines", .func = zlua.wrap(DrawRectangleRoundedLines) },
    .{ .name = "drawRectangleRoundedLinesEx", .func = zlua.wrap(DrawRectangleRoundedLinesEx) },
    .{ .name = "drawRectangleV", .func = zlua.wrap(DrawRectangleV) },
    .{ .name = "drawRing", .func = zlua.wrap(DrawRing) },
    .{ .name = "drawRingLines", .func = zlua.wrap(DrawRingLines) },
    .{ .name = "drawSphere", .func = zlua.wrap(DrawSphere) },
    .{ .name = "drawSphereEx", .func = zlua.wrap(DrawSphereEx) },
    .{ .name = "drawSphereWires", .func = zlua.wrap(DrawSphereWires) },
    .{ .name = "drawSplineSegmentBasis", .func = zlua.wrap(DrawSplineSegmentBasis) },
    .{ .name = "drawSplineSegmentBezierCubic", .func = zlua.wrap(DrawSplineSegmentBezierCubic) },
    .{ .name = "drawSplineSegmentBezierQuadratic", .func = zlua.wrap(DrawSplineSegmentBezierQuadratic) },
    .{ .name = "drawSplineSegmentCatmullRom", .func = zlua.wrap(DrawSplineSegmentCatmullRom) },
    .{ .name = "drawSplineSegmentLinear", .func = zlua.wrap(DrawSplineSegmentLinear) },
    .{ .name = "drawText", .func = zlua.wrap(DrawText) },
    .{ .name = "drawTriangle", .func = zlua.wrap(DrawTriangle) },
    .{ .name = "drawTriangle3D", .func = zlua.wrap(DrawTriangle3D) },
    .{ .name = "drawTriangleLines", .func = zlua.wrap(DrawTriangleLines) },
    .{ .name = "enableCursor", .func = zlua.wrap(EnableCursor) },
    .{ .name = "enableEventWaiting", .func = zlua.wrap(EnableEventWaiting) },
    .{ .name = "endBlendMode", .func = zlua.wrap(EndBlendMode) },
    .{ .name = "endDrawing", .func = zlua.wrap(EndDrawing) },
    .{ .name = "endMode2D", .func = zlua.wrap(EndMode2D) },
    .{ .name = "endMode3D", .func = zlua.wrap(EndMode3D) },
    .{ .name = "endScissorMode", .func = zlua.wrap(EndScissorMode) },
    .{ .name = "endShaderMode", .func = zlua.wrap(EndShaderMode) },
    .{ .name = "endTextureMode", .func = zlua.wrap(EndTextureMode) },
    .{ .name = "endVrStereoMode", .func = zlua.wrap(EndVrStereoMode) },
    .{ .name = "fileExists", .func = zlua.wrap(FileExists) },
    .{ .name = "hideCursor", .func = zlua.wrap(HideCursor) },
    .{ .name = "initAudioDevice", .func = zlua.wrap(InitAudioDevice) },
    .{ .name = "initWindow", .func = zlua.wrap(InitWindow) },
    .{ .name = "isAudioDeviceReady", .func = zlua.wrap(IsAudioDeviceReady) },
    .{ .name = "isCursorHidden", .func = zlua.wrap(IsCursorHidden) },
    .{ .name = "isCursorOnScreen", .func = zlua.wrap(IsCursorOnScreen) },
    .{ .name = "isFileDropped", .func = zlua.wrap(IsFileDropped) },
    .{ .name = "isFileExtension", .func = zlua.wrap(IsFileExtension) },
    .{ .name = "isFileNameValid", .func = zlua.wrap(IsFileNameValid) },
    .{ .name = "isGamepadAvailable", .func = zlua.wrap(IsGamepadAvailable) },
    .{ .name = "isGamepadButtonDown", .func = zlua.wrap(IsGamepadButtonDown) },
    .{ .name = "isGamepadButtonPressed", .func = zlua.wrap(IsGamepadButtonPressed) },
    .{ .name = "isGamepadButtonReleased", .func = zlua.wrap(IsGamepadButtonReleased) },
    .{ .name = "isGamepadButtonUp", .func = zlua.wrap(IsGamepadButtonUp) },
    .{ .name = "isGestureDetected", .func = zlua.wrap(IsGestureDetected) },
    .{ .name = "isKeyDown", .func = zlua.wrap(IsKeyDown) },
    .{ .name = "isKeyPressed", .func = zlua.wrap(IsKeyPressed) },
    .{ .name = "isKeyPressedRepeat", .func = zlua.wrap(IsKeyPressedRepeat) },
    .{ .name = "isKeyReleased", .func = zlua.wrap(IsKeyReleased) },
    .{ .name = "isKeyUp", .func = zlua.wrap(IsKeyUp) },
    .{ .name = "isMouseButtonDown", .func = zlua.wrap(IsMouseButtonDown) },
    .{ .name = "isMouseButtonPressed", .func = zlua.wrap(IsMouseButtonPressed) },
    .{ .name = "isMouseButtonReleased", .func = zlua.wrap(IsMouseButtonReleased) },
    .{ .name = "isMouseButtonUp", .func = zlua.wrap(IsMouseButtonUp) },
    .{ .name = "isPathFile", .func = zlua.wrap(IsPathFile) },
    .{ .name = "isWindowFocused", .func = zlua.wrap(IsWindowFocused) },
    .{ .name = "isWindowFullscreen", .func = zlua.wrap(IsWindowFullscreen) },
    .{ .name = "isWindowHidden", .func = zlua.wrap(IsWindowHidden) },
    .{ .name = "isWindowMaximized", .func = zlua.wrap(IsWindowMaximized) },
    .{ .name = "isWindowMinimized", .func = zlua.wrap(IsWindowMinimized) },
    .{ .name = "isWindowReady", .func = zlua.wrap(IsWindowReady) },
    .{ .name = "isWindowResized", .func = zlua.wrap(IsWindowResized) },
    .{ .name = "isWindowState", .func = zlua.wrap(IsWindowState) },
    .{ .name = "maximizeWindow", .func = zlua.wrap(MaximizeWindow) },
    .{ .name = "minimizeWindow", .func = zlua.wrap(MinimizeWindow) },
    .{ .name = "openURL", .func = zlua.wrap(OpenURL) },
    .{ .name = "pollInputEvents", .func = zlua.wrap(PollInputEvents) },
    .{ .name = "restoreWindow", .func = zlua.wrap(RestoreWindow) },
    .{ .name = "saveFileText", .func = zlua.wrap(SaveFileText) },
    .{ .name = "setAudioStreamBufferSizeDefault", .func = zlua.wrap(SetAudioStreamBufferSizeDefault) },
    .{ .name = "setAutomationEventBaseFrame", .func = zlua.wrap(SetAutomationEventBaseFrame) },
    .{ .name = "setClipboardText", .func = zlua.wrap(SetClipboardText) },
    .{ .name = "setConfigFlags", .func = zlua.wrap(SetConfigFlags) },
    .{ .name = "setExitKey", .func = zlua.wrap(SetExitKey) },
    .{ .name = "setGamepadVibration", .func = zlua.wrap(SetGamepadVibration) },
    .{ .name = "setGesturesEnabled", .func = zlua.wrap(SetGesturesEnabled) },
    .{ .name = "setMasterVolume", .func = zlua.wrap(SetMasterVolume) },
    .{ .name = "setMouseCursor", .func = zlua.wrap(SetMouseCursor) },
    .{ .name = "setMouseOffset", .func = zlua.wrap(SetMouseOffset) },
    .{ .name = "setMousePosition", .func = zlua.wrap(SetMousePosition) },
    .{ .name = "setMouseScale", .func = zlua.wrap(SetMouseScale) },
    .{ .name = "setRandomSeed", .func = zlua.wrap(SetRandomSeed) },
    .{ .name = "setTargetFPS", .func = zlua.wrap(SetTargetFPS) },
    .{ .name = "setTextLineSpacing", .func = zlua.wrap(SetTextLineSpacing) },
    .{ .name = "setTraceLogLevel", .func = zlua.wrap(SetTraceLogLevel) },
    .{ .name = "setWindowFocused", .func = zlua.wrap(SetWindowFocused) },
    .{ .name = "setWindowMaxSize", .func = zlua.wrap(SetWindowMaxSize) },
    .{ .name = "setWindowMinSize", .func = zlua.wrap(SetWindowMinSize) },
    .{ .name = "setWindowMonitor", .func = zlua.wrap(SetWindowMonitor) },
    .{ .name = "setWindowOpacity", .func = zlua.wrap(SetWindowOpacity) },
    .{ .name = "setWindowPosition", .func = zlua.wrap(SetWindowPosition) },
    .{ .name = "setWindowSize", .func = zlua.wrap(SetWindowSize) },
    .{ .name = "setWindowState", .func = zlua.wrap(SetWindowState) },
    .{ .name = "setWindowTitle", .func = zlua.wrap(SetWindowTitle) },
    .{ .name = "showCursor", .func = zlua.wrap(ShowCursor) },
    .{ .name = "startAutomationEventRecording", .func = zlua.wrap(StartAutomationEventRecording) },
    .{ .name = "stopAutomationEventRecording", .func = zlua.wrap(StopAutomationEventRecording) },
    .{ .name = "swapScreenBuffer", .func = zlua.wrap(SwapScreenBuffer) },
    .{ .name = "takeScreenshot", .func = zlua.wrap(TakeScreenshot) },
    .{ .name = "textAppend", .func = zlua.wrap(TextAppend) },
    .{ .name = "textIsEqual", .func = zlua.wrap(TextIsEqual) },
    .{ .name = "toggleBorderlessWindowed", .func = zlua.wrap(ToggleBorderlessWindowed) },
    .{ .name = "toggleFullscreen", .func = zlua.wrap(ToggleFullscreen) },
    .{ .name = "unloadCodepoints", .func = zlua.wrap(UnloadCodepoints) },
    .{ .name = "unloadFileText", .func = zlua.wrap(UnloadFileText) },
    .{ .name = "unloadImageColors", .func = zlua.wrap(UnloadImageColors) },
    .{ .name = "unloadImagePalette", .func = zlua.wrap(UnloadImagePalette) },
    .{ .name = "unloadRandomSequence", .func = zlua.wrap(UnloadRandomSequence) },
    .{ .name = "unloadUTF8", .func = zlua.wrap(UnloadUTF8) },
    .{ .name = "unloadWaveSamples", .func = zlua.wrap(UnloadWaveSamples) },
    .{ .name = "waitTime", .func = zlua.wrap(WaitTime) },
    .{ .name = "windowShouldClose", .func = zlua.wrap(WindowShouldClose) },
};
