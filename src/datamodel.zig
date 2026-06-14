const std = @import("std");

pub const Secret = struct { name: []const u8, value: []const u8, comment: ?[]const u8 };

const SecretStore = struct {
    secrets: std.array_hash_map.String(Secret),
    env: []const u8,
    pub fn init(alloc: std.mem.Allocator, env_name: []const u8) SecretStore {
        _ = alloc;
        return SecretStore{
            .env = env_name,
            .secrets = .{},
        };
    }

    pub fn deinit(self: *SecretStore) void {
        self.secrets.deinit();
    }

    pub fn addSecret(self: *SecretStore, alloc: std.mem.Allocator, inSecret: Secret) !void {
        try self.secrets.put(alloc, inSecret.name, inSecret);
    }

    pub fn printSecrets(self: *SecretStore, io: std.Io) !void {
        var stdout_writer = std.Io.File.stdout().writer(io, &.{});
        const stdout = &stdout_writer.interface;

        try stdout.print("# Environment is: {s}\n\n", .{self.env});
        for (self.secrets.values()) |secret| {
            try stdout.print("{s} = {s}", .{ secret.name, secret.value });
            if (secret.comment) |comment_text| {
                if (comment_text.len > 0) {
                    try stdout.print(" # {s}", .{comment_text});
                }
            }

            try stdout.print("\n", .{});
        }
    }
};

pub const Project = struct {
    name: []const u8,
    description: []const u8,
    store: SecretStore,

    pub fn init(allocator: std.mem.Allocator, project_name: []const u8, envname: []const u8, desc: []const u8) Project {
        return Project{ .name = project_name, .description = desc, .store = SecretStore.init(allocator, envname) };
    }
};
