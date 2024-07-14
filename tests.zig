const std = @import("std");
// const Main = @import("main.zig");
const Allocator = std.testing.allocator;

const TestDirName = "tests";
const TestDirFiles = [_][]const u8{ "something.txt", "some/thing.txt" };
const MAX_PATH = std.os.linux.PATH_MAX;

test "check if test files are initialized correctly" {
    try createTestDirectoriesStructure();
    try cleanUp();
}

test "check if tree is initialized correctly" {
    try createTestDirectoriesStructure();

    // Main.traverseNodes();

    try cleanUp();
}

fn createTestDirectoriesStructure() !void {
    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();

    current_dir.makeDir(TestDirName) catch |err| {
        std.debug.print("Failed to create directory '{s}': {}\n", .{ TestDirName, err });
        return err;
    };

    for (TestDirFiles) |dir_entry| {
        try createPathAndFile(current_dir, dir_entry);
    }
}

fn createPathAndFile(current_dir: std.fs.Dir, path: []const u8) !void {
    var root_dir = try current_dir.openDir(TestDirName, .{});
    defer root_dir.close();

    var full_item_path: []u8 = try Allocator.alloc(u8, 0);
    defer Allocator.free(full_item_path);
    var full_item_name: []u8 = try Allocator.alloc(u8, 0);
    defer Allocator.free(full_item_name);

    var ring_buffer = try std.RingBuffer.init(Allocator, MAX_PATH);
    defer ring_buffer.deinit(Allocator);

    var path_items_iterator = std.mem.splitSequence(u8, path, "/");
    while (path_items_iterator.next()) |path_item| {
        if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
            try ring_buffer.writeSlice(path_item);
            try ring_buffer.writeSlice("/");
        } else {
            full_item_name = try Allocator.realloc(full_item_name, path_item.len);
            std.mem.copyForwards(u8, full_item_name, path_item);
        }
    }

    if (ring_buffer.write_index > 0) {
        full_item_path = try Allocator.realloc(full_item_path, ring_buffer.write_index);
        try ring_buffer.readFirst(full_item_path, ring_buffer.write_index);
    }

    if (!std.mem.eql(u8, full_item_path, "")) {
        var file_path = try root_dir.makeOpenPath(full_item_path, .{});
        defer file_path.close();
        var file = try file_path.createFile(full_item_name, .{});
        defer file.close();
    } else {
        var file = try root_dir.createFile(full_item_name, .{});
        defer file.close();
    }
}

fn cleanUp() !void {
    const current_dir = try std.fs.cwd().openDir(".", .{});
    try current_dir.deleteTree(TestDirName);
}
