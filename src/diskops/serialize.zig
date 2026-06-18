const std = @import("std");
const datamodel = @import("../datamodel.zig");

pub fn toJson(alloc: std.mem.Allocator, project: *const datamodel.Project, jsonOptions: std.json.Stringify.Options) ![]const u8 {
    // try std.json.Stringify.valueAlloc(alloc, project, .{ .whitespace = .indent_2 });

    var out = std.Io.Writer.Allocating.init(alloc);
    defer out.deinit();

    var jsonWriter: std.json.Stringify = .{ .writer = &out.writer, .options = jsonOptions };

    try writeVariableToJson(&jsonWriter, project);
    return try out.toOwnedSlice();
}

fn writeVariableToJson(jw: *std.json.Stringify, variable: anytype) !void {
    const T = @TypeOf(variable);

    if (comptime isStringArrayHashMap(T)) {
        _ = try writeStringArrayHashMap(jw, variable);
        return;
    }

    switch (@typeInfo(T)) {
        .@"struct" => |S| {
            // if the struct has jsonStringify function defined, use that
            if (std.meta.hasFn(T, "jsonStringify")) {
                return try variable.jsonStringify(jw);
            }

            try jw.beginObject();
            inline for (S.fields) |field| {
                try jw.objectField(field.name);
                try writeVariableToJson(jw, @field(variable, field.name));
            }
            try jw.endObject();
        },
        .optional => {
            if (variable) |v| {
                try writeVariableToJson(jw, v);
            } else {
                try jw.write(null);
            }
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice) {
                // If the slice child type is u8, it's a string ([]u8 or []const u8)
                if (ptr_info.child == u8) {
                    try jw.write(variable);
                } else {
                    // Otherwise it's a normal array slice, iterate through it
                    try jw.beginArray();
                    for (variable) |item| {
                        try writeVariableToJson(jw, item);
                    }
                    try jw.endArray();
                }
            } else if (ptr_info.size == .one) {
                try writeVariableToJson(jw, variable.*);
            } else {
                @compileError("Unsupported pointer found: " ++ @typeName(T));
            }
        },
        .bool, .int, .float, .comptime_int, .comptime_float, .null, .@"enum" => {
            try jw.write(variable);
        },
        else => {
            @compileError("Unsupported type for JSON serialization: " ++ @typeName(T));
        },
    }
}

fn isStringArrayHashMap(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    return @hasDecl(T, "iterator") and @hasDecl(T, "put");
}

fn writeStringArrayHashMap(jw: anytype, map: anytype) !void {
    try jw.beginObject();
    var iter = map.iterator();
    while (iter.next()) |entry| {
        try jw.objectField(entry.key_ptr.*);
        try writeVariableToJson(jw, entry.value_ptr.*);
    }
    try jw.endObject();
}
