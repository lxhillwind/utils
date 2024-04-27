// Usage:
//   put lf-shell.exe $PATH;
//   lf:
//     set shell lf-shell
//     set shellflag -c
//
// Rationale:
// - lf file manager in win32 quotes $f / $fs / $fx unconditionally
//   (by prepend / append '"'); (this is why we replace "\"\n\"" with "\n")
//   code is here: https://github.com/gokcehan/lf/blob/2620f492c27a24205ace5f5e791a0179f0489f88/os_windows.go#L182-L184
// - fewer option to set
//   (if using busybox directly, we need to set shell to busybox, set shellflag to -c,
//   AND set shellopts to sh)

const std = @import("std");

fn isDoubleQuoted(s: []const u8) bool {
    return s.len >= 2 and s[0] == '"' and s[s.len - 1] == '"';
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const is_win32 = @import("builtin").os.tag == .windows;
    var env_f = std.process.getEnvVarOwned(allocator, if (is_win32) "F" else "f") catch "";
    var env_fs = std.process.getEnvVarOwned(allocator, if (is_win32) "FS" else "fs") catch "";
    var env_fx = std.process.getEnvVarOwned(allocator, if (is_win32) "FX" else "fx") catch "";
    // PWD is not required, since busybox will set it.

    if (isDoubleQuoted(env_f)) {
        env_f = env_f[1 .. env_f.len - 1];
    }
    if (isDoubleQuoted(env_fs)) {
        env_fs = env_fs[1 .. env_fs.len - 1];
        env_fs = try std.mem.replaceOwned(u8, allocator, env_fs, "\"\n\"", "\n");
    }
    if (isDoubleQuoted(env_fx)) {
        env_fx = env_fx[1 .. env_fx.len - 1];
        env_fx = try std.mem.replaceOwned(u8, allocator, env_fx, "\"\n\"", "\n");
    }

    var env_map = try std.process.getEnvMap(allocator);
    // case does not care if in windows; but to work in unix, use uppercase.
    try env_map.put("F", env_f);
    try env_map.put("FS", env_fs);
    try env_map.put("FX", env_fx);

    var argsNew = std.ArrayList([]const u8).init(allocator);
    try argsNew.appendSlice(&[_][]const u8{
        // TODO there will be 4 busybox process in windows in default case;
        // don't know how to solve it yet.
        "busybox", "sh", "-c",
        \\export f=$F;
        \\export fs=$FS;
        \\export fx=$FX;
        \\"$@";
        , // in windows, env is in uppercase; convert them to lowercase inside busybox.
        "-", // $0
        "sh",
    });

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    while (args.next()) |arg| {
        try argsNew.append(arg);
    }
    var process = std.ChildProcess.init(argsNew.items, allocator);
    process.env_map = &env_map;
    const p = try process.spawnAndWait();
    std.process.exit(p.Exited);
}
