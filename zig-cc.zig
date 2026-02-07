const std = @import("std");
const builtin = @import("builtin");

var gpa: std.mem.Allocator = undefined;
var io: std.Io = undefined;

pub fn main(init: std.process.Init) !void {
    gpa = init.gpa;
    io = init.io;
    var environ = init.minimal.environ;
    var os = environ.getAlloc(gpa, "ZIG_OS") catch @tagName(builtin.os.tag);
    defer gpa.free(os);
    if (std.mem.eql(u8, os, "macosx")) {
        os = "macos";
    }

    var cpu = environ.getAlloc(gpa, "ZIG_CPU") catch @tagName(builtin.cpu.arch);
    defer gpa.free(cpu);
    if (std.mem.eql(u8, cpu, "amd64")) {
        cpu = "x86_64";
    } else if (std.mem.eql(u8, cpu, "arm64")) {
        cpu = "aarch64";
    }

    var target: std.ArrayList(u8) = .empty;
    try target.appendSlice(gpa, cpu);
    try target.appendSlice(gpa, "-");
    try target.appendSlice(gpa, os);
    try target.appendSlice(gpa, "-");
    // abi (TODO)
    if (std.mem.eql(u8, os, "linux")) {
        try target.appendSlice(gpa, "musl");
    } else if (std.mem.eql(u8, os, "macos")) {
        try target.appendSlice(gpa, "none");
    } else {
        try target.appendSlice(gpa, "gnu");
    }

    var debug = environ.getAlloc(gpa, "DEBUG") catch "";
    defer gpa.free(debug);
    if (debug.len > 0) {
        std.debug.print("compiling to: {s}\n", .{target.items});
    }

    var argsNew: std.ArrayList([]const u8) = .empty;
    try argsNew.appendSlice(gpa, &[_][]const u8{ "zig", "cc", "-target" });
    try argsNew.append(gpa, target.items);
    var argsIt = init.minimal.args.iterate();

    // skip self.
    _ = argsIt.next();

    while (argsIt.next()) |arg| {
        try argsNew.append(gpa, arg);
    }
    var process = try std.process.spawn(io, .{
        .argv = argsNew.items
    });
    const p = try process.wait(io);
    std.process.exit(p.exited);
}
