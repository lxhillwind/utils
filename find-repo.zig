const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

const stat = blk: {
    if (builtin.os.tag == .linux and @hasField(std.os.linux.SYS, "stat")) {
        break :blk std.os.linux.stat;
    } else {
        break :blk struct {
            extern "c" fn stat([*:0]const u8, *std.posix.Stat) usize;
        }.stat;
    }
};

pub extern "kernel32" fn GetFileAttributesA(lpFileName: [*:0]const u8) callconv(windows.WINAPI) windows.DWORD;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();

    var path_buf = std.ArrayList(u8).init(allocator);
    while (args.next()) |path| {
        path_buf.clearRetainingCapacity();
        try path_buf.appendSlice(path);
        processDir(try path_buf.clone()) catch |e| std.debug.print("error: {any}\n", .{e});
    }
}

fn processDir(path: std.ArrayList(u8)) !void {
    defer path.deinit();

    var with_git = try path.clone();
    defer with_git.deinit();
    try with_git.appendSlice("/.git");
    try with_git.append(0);

    var with_gitmodules = try path.clone();
    defer with_gitmodules.deinit();
    try with_gitmodules.appendSlice("/.gitmodules");
    try with_gitmodules.append(0);

    if (dirExists(assertCstring(with_git.items)) or fileExists(assertCstring(with_git.items))) {
        print(path.items);
        if (!fileExists(assertCstring(with_gitmodules.items))) {
            return;
        }
    }

    // blacklist
    {
        const sep = if (builtin.os.tag == .windows) "\\/" else "/";
        var bl_iter = std.mem.splitBackwardsAny(u8, path.items, sep);
        if (bl_iter.next()) |stem| {
            for (blacklist) |s| {
                if (std.mem.eql(u8, s, stem)) {
                    return;
                }
            }
        }
    }

    // walkdir
    var new_dir = std.fs.cwd().openDir(path.items, .{ .iterate = true }) catch |e| {
        std.debug.print("error: {any}\n", .{e});
        return;
    };
    defer new_dir.close();
    var iterator = new_dir.iterate();
    while (try iterator.next()) |item| {
        if (item.kind == .directory) {
            var path_new = try path.clone();
            if (path_new.getLast() != '/') {
                try path_new.append('/');
            }
            try path_new.appendSlice(item.name);
            processDir(path_new) catch |e| std.debug.print("error: {any}\n", .{e});
        }
    }
}

fn StatCheck(path: [*:0]const u8, expect: u32) bool {
    var statbuf: std.posix.Stat = undefined;
    const res = stat(path, &statbuf);
    if (res != 0) {
        return false;
    }
    const m = statbuf.mode & std.posix.S.IFMT;
    return m == expect;
}

fn dirExists(path: [*:0]const u8) bool {
    if (builtin.os.tag == .windows) {
        const rc = GetFileAttributesA(path);
        if (rc == windows.INVALID_FILE_ATTRIBUTES) return false;
        return rc & windows.FILE_ATTRIBUTE_DIRECTORY != 0;
    } else {
        return StatCheck(path, std.posix.S.IFDIR);
    }
}

fn fileExists(path: [*:0]const u8) bool {
    if (builtin.os.tag == .windows) {
        const rc = GetFileAttributesA(path);
        if (rc == windows.INVALID_FILE_ATTRIBUTES) return false;
        return rc & windows.FILE_ATTRIBUTE_DIRECTORY == 0;
    } else {
        return StatCheck(path, std.posix.S.IFREG);
    }
}

fn print(s: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    _ = stdout.write(s) catch return;
    _ = stdout.write("\n") catch return;
}

const blacklist = [_][]const u8{
    "venv", "node_modules",
};

fn assertCstring(s: []const u8) [*:0]const u8 {
    if (s[s.len - 1] != 0) unreachable;
    return @ptrCast(s);
}
