const std = @import("std");
const envmgr = @import("envmgr");
const dotenvexp = @import("exporting/dotenv.zig");

// Grab what you need from the hub
const utils = envmgr.utils;
const datamodel = envmgr.datamodel;
const diskops = envmgr.diskops;

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    // initialize the allocator for the project
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    // initialize the standard input and output
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buffer);

    var cli_ctx = utils.CLIContext{ .alloc = arena_alloc, .stdin = &stdin_reader.interface, .stdout = &stdout_writer.interface };

    try cli_ctx.stdout.print("Welcome to env var manager\n", .{});

    // take project name
    const project_name = (try utils.askUser(cli_ctx, "To get started please provide your project name. Leave it empty to exit")) orelse {
        std.debug.print("Couldnt get project name. Exiting...", .{});
        return;
    };
    if (project_name.len == 0) {
        return;
    }
    try cli_ctx.stdout.print("{s}\n", .{project_name});

    // take environment name
    var envname = (try utils.askUser(cli_ctx, "Specify what is the environment name? (typical names are dev, staging, prod). Default value is \"dev\"")) orelse "dev";
    if (envname.len == 0) {
        envname = "dev";
    }

    var project = datamodel.Project.init(arena_alloc, project_name, "");
    const new_store = datamodel.SecretStore.init(arena_alloc, envname);
    try project.stores.put(arena_alloc, envname, new_store);
    var active_store = project.stores.getPtr(envname);
    try cli_ctx.stdout.print("Secret store for environment \"{s}\" created for project \"{s}\"\n", .{ envname, project.name });

    // populate secrets in loop
    while (true) {

        // take secret name
        const secret_name = (try utils.askUser(cli_ctx, "Enter the name of secret. (leave blank to end)")) orelse {
            std.debug.print("Err taking in input from terminal.", .{});
            continue;
        };
        if (secret_name.len == 0) {
            std.debug.print("Secret submission ended.\n", .{});
            break;
        }
        // take secret value
        const secret_value = (try utils.askUser(cli_ctx, "Enter the VALUE of secret. (can be left blank, but not recommended)")) orelse {
            std.debug.print("Err taking in input from terminal.", .{});
            continue;
        };

        // take secret value
        const comment_value = (try utils.askUser(cli_ctx, "Enter the comment. (can be left blank)")) orelse {
            std.debug.print("Err taking in input from terminal.", .{});
            continue;
        };

        // add secret
        const secret = datamodel.Secret{ .name = secret_name, .value = secret_value, .comment = comment_value };
        try active_store.?.addSecret(arena_alloc, secret);
    }

    try cli_ctx.stdout.print("Your project secrets are: \n", .{});
    try active_store.?.printSecrets(init.io);
    const json_str = try diskops.toJson(arena_alloc, &project, .{ .whitespace = .indent_2 });
    try cli_ctx.stdout.print("{s}", .{json_str});
    const secretStore = project.stores.get(envname);
    if (secretStore) |str| {
        try dotenvexp.exportDotEnv(arena_alloc, init.io, "text.env", &str);
    }

    // std.debug.print("{s}\n", .{json_string});
}
