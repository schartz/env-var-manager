const std = @import("std");
const utils = @import("utils.zig");
const datamodel = @import("datamodel.zig");
const Io = std.Io;

const envmgr = @import("envmgr");

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
}
