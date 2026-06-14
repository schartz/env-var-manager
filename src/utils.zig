const std = @import("std");

pub const CLIContext = struct {
    alloc: std.mem.Allocator,
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
};

pub fn askUser(ctx: CLIContext, instruction: []const u8) !?[]u8 {
    try ctx.stdout.print("{s}: ", .{instruction});

    const bare_line = (try ctx.stdin.takeDelimiter('\n')) orelse return null;
    const line = std.mem.trim(u8, bare_line, "\r");

    return try ctx.alloc.dupe(u8, line);
}
