const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

/// Creates a file and subdirectories if passed in path.
///
/// NOTE: It might bug out for hidden files due to std.fs.path.extension implementation.
pub fn createPathAndFile(allocator: std.mem.Allocator, root_dir: std.fs.Dir, path: []const u8) !void {
    var full_item_path: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_path);
    var full_item_name: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_name);

    var ring_buffer = try std.RingBuffer.init(allocator, MAX_PATH);
    defer ring_buffer.deinit(allocator);

    var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
    while (path_items_iterator.next()) |path_item| {
        if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
            try ring_buffer.writeSlice(path_item);
            try ring_buffer.writeSlice("/");
        } else {
            full_item_name = try allocator.dupe(u8, path_item);
        }
    }

    if (ring_buffer.write_index > 0) {
        full_item_path = try allocator.realloc(full_item_path, ring_buffer.write_index);
        try ring_buffer.readFirst(full_item_path, ring_buffer.write_index);
    }

    var file_parent_dir = root_dir;
    if (!std.mem.eql(u8, full_item_path, "")) {
        file_parent_dir = try root_dir.makeOpenPath(full_item_path, .{});
    }
    if (!std.mem.eql(u8, full_item_name, "")) {
        var file = try file_parent_dir.createFile(full_item_name, .{});
        defer file.close();
    }
    if (file_parent_dir.fd != root_dir.fd) {
        file_parent_dir.close();
    }
}

/// Deletes all files from given path.
pub fn deleteDirOrFileFromDir(root_dir: std.fs.Dir, path: []const u8) !void {
    if (std.mem.eql(u8, std.fs.path.extension(path), "")) {
        try root_dir.deleteTree(path);
    } else {
        try root_dir.deleteFile(path);
    }
}

/// Given string ArrayList returns concatenated path with '/'.
pub fn joinArraylistToPath(allocator: std.mem.Allocator, arraylist: *std.ArrayList([]u8)) ![]const u8 {
    var ring_buffer = try std.RingBuffer.init(allocator, MAX_PATH);
    defer ring_buffer.deinit(allocator);

    for (arraylist.items, 0..) |item, index| {
        try ring_buffer.writeSlice(item);
        if (index < arraylist.items.len - 1) {
            try ring_buffer.writeSlice("/");
        }
    }
    const path = try allocator.alloc(u8, ring_buffer.write_index);
    errdefer allocator.free(path);
    try ring_buffer.readFirst(path, ring_buffer.write_index);
    return path;
}

/// Returns root dir name, useful from relative path.
pub fn getFirstNameFromPath(path: []const u8) []const u8 {
    var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
    if (path_items_iterator.next()) |first_item| {
        return first_item;
    }
    return "";
}
