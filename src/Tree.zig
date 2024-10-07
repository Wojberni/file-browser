const std = @import("std");
const Node = @import("Node.zig");
const FileStruct = @import("FileStruct.zig");

const Tree = @This();

root: *Node,

pub fn init(allocator: std.mem.Allocator, root_dir_name: []const u8) !Tree {
    var current_dir = try std.fs.cwd().openDir(root_dir_name, .{ .iterate = true });
    errdefer current_dir.close();
    const current_path = try current_dir.realpathAlloc(allocator, ".");
    defer allocator.free(current_path);
    const current_dir_name = std.fs.path.basename(current_path);

    const allocated_file_name = try allocator.alloc(u8, current_dir_name.len);
    errdefer allocator.free(allocated_file_name);
    std.mem.copyForwards(u8, allocated_file_name, current_dir_name);

    const file_struct = FileStruct.init(allocated_file_name, .{ .dir = current_dir });
    return .{ .root = try Node.init(allocator, null, file_struct) };
}

pub fn deinit(self: *Tree) void {
    self.root.deinit();
}

pub fn traverseTree(self: *Tree) void {
    self.root.traverseNodeChildren(0);
}

pub fn loadTreeFromDir(self: *Tree) !void {
    try self.root.loadNodeChildren();
}

pub fn findFirstMatchingName(self: *Tree, name: []const u8) ![]const u8 {
    return try self.root.findFirstMatchingName(name);
}

pub fn findAllContainingName(self: *Tree, name: []const u8) !std.ArrayList([]const u8) {
    return try self.root.findAllContainingName(name);
}

pub fn insertNodeWithPath(self: *Tree, path: []const u8) !void {
    try self.root.insertNodeWithPath(path);
}

pub fn deleteNodeWithPath(self: *Tree, path: []const u8) !*Node {
    return try self.root.deleteNodeWithPath(path);
}
