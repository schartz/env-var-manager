const std = @import("std");
const envmgr = @import("envmgr");
const datamodel = envmgr.datamodel;

pub fn exportDotEnv(alloc: std.mem.Allocator, io: std.Io, filename: []const u8, secret_store: *const datamodel.SecretStore) !void {
    var dotenv_str: std.ArrayList(u8) = .empty;
    errdefer dotenv_str.deinit(alloc);

    for (secret_store.secrets.values()) |secret| {
        try dotenv_str.appendSlice(alloc, secret.name);
        try dotenv_str.appendSlice(alloc, "=");
        try dotenv_str.appendSlice(alloc, secret.value);

        if (secret.comment) |comment| {
            if (comment.len > 0) {
                try dotenv_str.appendSlice(alloc, " # ");
                try dotenv_str.appendSlice(alloc, comment);
            }
        }
        try dotenv_str.appendSlice(alloc, "\n");
    }

    const file = try std.Io.Dir.cwd().createFile(io, filename, .{});
    defer file.close(io);
    var file_writer = file.writer(io, &.{});
    const writer = &file_writer.interface;

    try writer.writeAll(dotenv_str.items);
}
