const std = @import("std");

fn printHelp() void {
    std.io.getStdErr().writeAll(
        \\  update id3 tag in .mp3 files:
        \\    convert disc type cover to front cover.
        \\
        \\  usage: {exe} [files to handle...]
        ++ "\n") catch return;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    var noArg = true;
    var failedCount: usize = 0;

    while (args.next()) |fname| {
        if (noArg) {
            noArg = false;
        }
        handleFile(fname) catch |err| {
            std.debug.print("handle file {s} failed: {any}\n", .{fname, err});
            failedCount += 1;
        };
    }

    if (noArg) {
        printHelp();
    }
    std.process.exit(if (failedCount == 0) 0 else 1);
}

fn handleFile(path: []const u8) !void {
    const fp = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    var buf = [_]u8{0} ** 100;
    var reader = fp.reader();

    try assert(10 == try reader.read(buf[0..10]), "reading tag header");
    try assert(std.mem.eql(u8, "ID3", buf[0..3]), "is not id3");

    // id (read above): 3; ver: 2; flag: 1; size: 4 byte(s)
    // so size begin from buf[6];
    // most significant bit of every byte is 0 and discarded.
    const tagSize = @as(usize, buf[6]) * (2 << 21) + @as(usize, buf[7]) * (2 << 14)  + @as(usize, buf[8]) * (2 << 7) + @as(usize, buf[9]);

    // skip extended header
    try assert(4 == try reader.read(buf[0..4]), "reading extended header size");
    const extendedHeaderSize: u8 = switch(buf[3]) {
        6 => 6,
        10 => 10,
        else => 0,
    };
    try fp.seekTo(10 + extendedHeaderSize);

    _ = iterOnFrame: {
        while(try fp.getPos() < tagSize + 10) {
            try assert(10 == try reader.read(buf[0..10]), "reading a tag");
            // frameId must consist of uppercase (and optional 0-9)
            for (buf[0..4]) |ch| {
                if (!
                    (
                     (ch >= 'A' and ch <= 'Z')
                     or (ch >= '0' and ch <= '9')
                    )
                ) {
                    break :iterOnFrame;
                }
            }

            const frameId = buf[0..4];
            const frameSize = @as(usize, buf[4]) * (2 << 21) + @as(usize, buf[5]) * (2 << 14) + @as(usize, buf[6]) * (2 << 7) + @as(usize, buf[7]);

            if (std.mem.eql(u8, frameId, "APIC")) {
                try fp.seekBy(1); // skip Text encoding
                try reader.skipUntilDelimiterOrEof('\x00'); // skip MIME type
                const picType = try reader.readByte();
                if (picType == 6) {
                    std.debug.print("filename: {s} picType: {d}\n", .{path, picType});
                    try fp.seekBy(-1);
                    try fp.writer().writeByte('\x03');
                    std.debug.print("  updated.\n", .{});
                }
                break :iterOnFrame;
            }
            try fp.seekBy(@intCast(frameSize));
        }
    };
}

fn assert(cond: bool, msg: []const u8) !void {
    if (!cond) {
        std.debug.print("{s}: failed.\n", .{msg});
        return error.AssertError;
    }
}
