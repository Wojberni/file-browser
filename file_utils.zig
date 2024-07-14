const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

pub fn createTestDirectoriesStructure(allocator: std.mem.Allocator, test_dir: []const u8, test_file_paths: *std.ArrayList([]const u8)) !void {
    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();

    current_dir.makeDir(test_dir) catch |err| {
        std.debug.print("Failed to create test directory '{s}': {}\n", .{ test_dir, err });
        return err;
    };

    for (test_file_paths.items) |dir_entry| {
        try createPathAndFile(allocator, current_dir, test_dir, dir_entry);
    }
}

fn createPathAndFile(allocator: std.mem.Allocator, current_dir: std.fs.Dir, test_dir_name: []const u8, path: []const u8) !void {
    var root_dir = try current_dir.openDir(test_dir_name, .{});
    defer root_dir.close();

    var full_item_path: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_path);
    var full_item_name: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_name);

    var ring_buffer = try std.RingBuffer.init(allocator, MAX_PATH);
    defer ring_buffer.deinit(allocator);

    var path_items_iterator = std.mem.splitSequence(u8, path, "/");
    while (path_items_iterator.next()) |path_item| {
        if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
            try ring_buffer.writeSlice(path_item);
            try ring_buffer.writeSlice("/");
        } else {
            full_item_name = try allocator.realloc(full_item_name, path_item.len);
            std.mem.copyForwards(u8, full_item_name, path_item);
        }
    }

    if (ring_buffer.write_index > 0) {
        full_item_path = try allocator.realloc(full_item_path, ring_buffer.write_index);
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

pub fn cleanUp(test_dir_name: []const u8) !void {
    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();
    try current_dir.deleteTree(test_dir_name);
}
