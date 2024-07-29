const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const FileStruct = struct {
    name: []u8,
    file_union: FileUnion,

    pub const FileUnion = union(enum) {
        dir: std.fs.Dir,
        file: std.fs.File,
    };

    pub fn init(name: []u8, file_union: FileUnion) FileStruct {
        return FileStruct{ .name = name, .file_union = file_union };
    }
};

pub fn createPathAndFile(allocator: std.mem.Allocator, root_dir: std.fs.Dir, entry: []const u8) !void {
    var full_item_path: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_path);
    var full_item_name: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(full_item_name);

    var ring_buffer = try std.RingBuffer.init(allocator, MAX_PATH);
    defer ring_buffer.deinit(allocator);

    var path_items_iterator = std.mem.splitSequence(u8, entry, "/");
    while (path_items_iterator.next()) |path_item| {
        if (path_items_iterator.peek() != null) {
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
