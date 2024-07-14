const std = @import("std");
const Node = @import("node.zig");
const FileStruct = @import("file_struct.zig");

pub const Tree = struct { root: Node.Node };

fn newTree(root: Node.Node) Tree {
    return Tree{ .root = root };
}

pub fn initTree(allocator: std.mem.Allocator, root_dir_name: []const u8) !Tree {
    const current_dir = try std.fs.cwd().openDir(root_dir_name, .{ .iterate = true });
    // defer current_dir.close();

    const current_path = try current_dir.realpathAlloc(allocator, ".");
    defer allocator.free(current_path);

    const current_dir_name = std.fs.path.basename(current_path);

    const allocated_file_name = try allocator.alloc(u8, current_dir_name.len);
    std.mem.copyForwards(u8, allocated_file_name, current_dir_name);

    const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .dir = current_dir });
    const node = Node.newNode(file_struct, undefined);

    return newTree(node);
}
