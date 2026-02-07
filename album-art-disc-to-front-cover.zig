const std = @import("std");

fn printHelp() void {
    std.debug.print("{s}\n", .{
        \\  update id3 tag in .mp3 files:
        \\    convert disc type cover to front cover.
        \\
        \\  usage: {exe} [files to handle...]
    });
}

var io: std.Io = undefined;
var gpa: std.mem.Allocator = undefined;

pub fn main(init: std.process.Init) !void {
    gpa = init.gpa;
    io = init.io;

    var args = init.minimal.args.iterate();
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
    const fp = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write });
    var buf_f: [100]u8 = undefined;
    var buf: [100]u8 = undefined;
    var f_reader = fp.reader(io, &buf_f);
    const reader = &f_reader.interface;

    // reading tag header
    try reader.readSliceAll(buf[0..10]);
    if (!std.mem.eql(u8, "ID3", buf[0..3])) {
        return error.FileTagIsNotID3;
    }

    // id (read above): 3; ver: 2; flag: 1; size: 4 byte(s)
    // so size begin from buf[6];
    // most significant bit of every byte is 0 and discarded.
    const tagSize = @as(usize, buf[6]) * (2 << 21) + @as(usize, buf[7]) * (2 << 14)  + @as(usize, buf[8]) * (2 << 7) + @as(usize, buf[9]);

    // skip extended header
    try reader.readSliceAll(buf[0..4]);
    const extendedHeaderSize: u8 = switch(buf[3]) {
        6 => 6,
        10 => 10,
        else => 0,
    };
    try f_reader.seekTo(10 + extendedHeaderSize);

    _ = iterOnFrame: {
        while(f_reader.logicalPos() < tagSize + 10) {
            // reading a tag
            try reader.readSliceAll(buf[0..10]);
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
                try f_reader.seekBy(1); // skip Text encoding
                _ = try reader.discardDelimiterInclusive('\x00'); // skip MIME type
                const picType = r: {
                    try reader.readSliceAll(buf[0..1]);
                    break :r buf[0];
                };
                std.debug.print("picType: {}\n", .{picType});
                if (picType == 6) {
                    std.debug.print("filename: {s} picType: {d}\n", .{path, picType});
                    try f_reader.seekBy(-1);
                    var f_writer = fp.writer(io, &buf_f);
                    try f_writer.seekTo(f_reader.logicalPos());
                    const w = &f_writer.interface;
                    try w.writeByte('\x03');
                    try w.flush();
                    std.debug.print("  updated.\n", .{});
                }
                break :iterOnFrame;
            }
            try f_reader.seekBy(@intCast(frameSize));
        }
    };
}
