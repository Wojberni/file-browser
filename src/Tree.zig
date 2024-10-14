const std = @import("std");
const Node = @import("Node.zig");
const NodeValue = @import("NodeValue.zig");

const Tree = @This();

allocator: std.mem.Allocator,
root: *Node,
root_dir: *std.fs.Dir,

pub fn init(allocator: std.mem.Allocator, root_dir_name: []const u8) !Tree {
    var cwd_dir = try std.fs.cwd().openDir(root_dir_name, .{ .iterate = true });

    const current_path = try cwd_dir.realpathAlloc(allocator, ".");
    defer allocator.free(current_path);

    const current_dir_name = std.fs.path.basename(current_path);
    const allocated_file_name = try allocator.dupe(u8, current_dir_name);
    errdefer allocator.free(allocated_file_name);

    const value = NodeValue.init(
        allocated_file_name,
        .{
            .dir = .{
                .metadata = try cwd_dir.metadata(),
            },
        },
    );
    const root_dir_ptr = try allocator.create(std.fs.Dir);
    root_dir_ptr.* = cwd_dir;
    return .{
        .allocator = allocator,
        .root = try Node.init(allocator, root_dir_ptr, null, value),
        .root_dir = root_dir_ptr,
    };
}

pub fn deinit(self: *Tree) void {
    self.root.deinit();
    self.root_dir.close();
    self.allocator.destroy(self.root_dir);
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
