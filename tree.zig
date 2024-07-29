const std = @import("std");
const Node = @import("node.zig");
const FileStruct = @import("file_struct.zig");

pub const Tree = struct {
    root: Node.Node,

    pub fn init(allocator: std.mem.Allocator, root_dir_name: []const u8) !Tree {
        const current_dir = try std.fs.cwd().openDir(root_dir_name, .{ .iterate = true });
        const current_path = try current_dir.realpathAlloc(allocator, ".");
        defer allocator.free(current_path);
        const current_dir_name = std.fs.path.basename(current_path);

        const allocated_file_name = try allocator.alloc(u8, current_dir_name.len);
        std.mem.copyForwards(u8, allocated_file_name, current_dir_name);

        const file_struct = FileStruct.FileStruct.init(allocated_file_name, FileStruct.FileStruct.FileUnion{ .dir = current_dir });
        return Tree{ .root = Node.Node.init(allocator, null, file_struct) };
    }

    pub fn deinit(self: *Tree) void {
        self.root.deinit();
    }

    pub fn traverseTree(self: *Tree) void {
        self.root.traverseNodeChildren(0);
    }

    pub fn loadTreeFromDir(self: *Tree) !void {
        try self.root.addChildrenToNode();
    }

    pub fn findMatchingNodeByName(self: *Tree, name: []const u8) ![]const u8 {
        var arraylist = std.ArrayList([]u8).init(self.root.allocator);
        defer arraylist.deinit();
        return try self.root.findMatchingNodeByName(&arraylist, name);
    }

    pub fn insertNodeWithPath(self: *Tree, path: []const u8) !void {
        var path_items_iterator = std.mem.splitSequence(u8, path, "/");
        var node_item = self.root;
        while (path_items_iterator.next()) |item| {
            node_item = node_item.addChild(item);
        }
        
    }
};
