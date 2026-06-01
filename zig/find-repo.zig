const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

var io: std.Io = undefined;
var gpa: std.mem.Allocator = undefined;

pub fn main(init: std.process.Init) !void {
    gpa = init.gpa;
    io = init.io;

    // Windows requires allocator.
    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    while (args.next()) |path| {
        var path_buf: std.ArrayList(u8) = .empty;
        try path_buf.appendSlice(gpa, path);
        processDir(&path_buf) catch |e| std.debug.print("error: {any}\n", .{e});
    }
}

fn processDir(path: *std.ArrayList(u8)) !void {
    defer path.deinit(gpa);

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
    var new_dir = std.Io.Dir.cwd().openDir(io, path.items, .{ .iterate = true }) catch |e| {
        std.debug.print("error: {any}\n", .{e});
        return;
    };
    defer new_dir.close(io);
    var iterator = new_dir.iterate();

    var entries: std.ArrayList([]const u8) = .empty;
    defer {
        for (entries.items) |i| {
            gpa.free(i);
        }
        entries.deinit(gpa);
    }
    var has_git = false;
    var has_git_submodule = false;
    while (try iterator.next(io)) |item| {
        if (std.mem.eql(u8, ".git", item.name)) {
            has_git = true;
        } else if (std.mem.eql(u8, ".gitmodules", item.name)) {
            has_git_submodule = true;
        } else if (item.kind == .directory) {
            var path_new = try path.clone(gpa);
            if (path_new.getLast() != '/') {
                try path_new.append(gpa, '/');
            }
            try path_new.appendSlice(gpa, item.name);
            try entries.append(gpa, try path_new.toOwnedSlice(gpa));
        }
    }
    if (has_git) {
        print(path.items);
        if (!has_git_submodule) {
            return;
        }
    }
    for (entries.items) |i| {
        var path_new: std.ArrayList(u8) = .empty;
        try path_new.appendSlice(gpa, i);
        processDir(&path_new) catch |e| std.debug.print("error: {any}\n", .{e});
    }
}

fn print(s: []const u8) void {
    const buf: []u8 = gpa.alloc(u8, 1024) catch return;
    defer gpa.free(buf);
    var stdout = std.Io.File.stdout().writer(io, buf);
    const writer = &stdout.interface;
    _ = writer.writeAll(s) catch return;
    _ = writer.writeAll("\n") catch return;
    writer.flush() catch return;
}

const blacklist = [_][]const u8{
    "venv", "node_modules",
};
