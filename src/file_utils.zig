const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

pub fn createPathAndFile(allocator: std.mem.Allocator, root_dir: std.fs.Dir, entry: []const u8) !void {
    var full_item_path: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_path);
    var full_item_name: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_name);

    var ring_buffer = try std.RingBuffer.init(allocator, MAX_PATH);
    defer ring_buffer.deinit(allocator);

    var path_items_iterator = std.mem.tokenizeSequence(u8, entry, "/");
    while (path_items_iterator.next()) |path_item| {
        if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
            try ring_buffer.writeSlice(path_item);
            try ring_buffer.writeSlice("/");
        } else {
            full_item_name = try std.fmt.allocPrint(allocator, "{s}", .{path_item});
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

pub fn deleteDirOrFileFromDir(root_dir: std.fs.Dir, entry: []const u8) !void {
    if (std.mem.eql(u8, std.fs.path.extension(entry), "")) {
        try root_dir.deleteTree(entry);
    } else {
        try root_dir.deleteFile(entry);
    }
}

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

pub fn getLastNameFromPath(path: []const u8) []const u8 {
    var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
    while (path_items_iterator.next()) |path_item| {
        if (path_items_iterator.peek() == null) {
            return path_item;
        }
    }
    return "";
}

pub fn getFirstNameFromPath(path: []const u8) []const u8 {
    var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
    if (path_items_iterator.next()) |first_item| {
        return first_item;
    }
    return "";
}
