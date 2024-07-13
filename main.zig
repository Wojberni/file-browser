const std = @import("std");

const Tree = @import("tree.zig");
const FileStruct = @import("file_struct.zig");
const Node = @import("node.zig");

const Allocator = std.heap.page_allocator;

pub fn main() !void {
    var tree = try initTree();

    try addChildrenToNode(&tree.root);

    traverseNodeChildren(&tree.root);
}

pub fn initTree() !Tree.Tree {
    const current_dir = try std.fs.cwd().openDir("aha", .{ .iterate = true });
    // defer current_dir.close();

    const current_path = try current_dir.realpathAlloc(Allocator, ".");
    defer Allocator.free(current_path);

    const current_dir_name = std.fs.path.basename(current_path);

    const allocated_file_name = try Allocator.alloc(u8, current_dir_name.len);
    std.mem.copyForwards(u8, allocated_file_name, current_dir_name);

    const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .dir = current_dir });
    const node = Node.newNode(file_struct, undefined);

    return Tree.newTree(node);
}

fn addChildrenToNode(root_node: *Node.Node) !void {
    const root_dir = root_node.value.file_union.dir;

    var iterator = root_dir.iterate();
    var counter: u32 = 0;

    while (try iterator.next()) |_| {
        counter += 1;
    }

    root_node.children = try Allocator.alloc(Node.Node, counter);
    // defer Allocator.free(root_node.children);

    iterator = root_dir.iterate();
    counter = 0;

    while (try iterator.next()) |entry| {
        switch (entry.kind) {
            std.fs.File.Kind.directory => {
                const entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
                // defer entry_dir.close();

                const allocated_file_name = try Allocator.alloc(u8, entry.name.len);
                std.mem.copyForwards(u8, allocated_file_name, entry.name);

                const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .dir = entry_dir });
                root_node.children[counter] = Node.newNode(file_struct, undefined);
                try addChildrenToNode(&root_node.children[counter]);
            },
            std.fs.File.Kind.file => {
                const entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_write });
                // defer entry_file.close();

                const allocated_file_name = try Allocator.alloc(u8, entry.name.len);
                std.mem.copyForwards(u8, allocated_file_name, entry.name);

                const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .file = entry_file });
                root_node.children[counter] = Node.newNode(file_struct, undefined);
            },
            else => unreachable,
        }
        counter += 1;
    }
}

pub fn traverseNodeChildren(node: *const Node.Node) void {
    std.debug.print("{s}\n", .{node.value.name});
    for (node.children) |child| {
        switch (child.value.file_union) {
            .dir => {
                traverseNodeChildren(&child);
            },
            .file => {
                std.debug.print("{s}\n", .{child.value.name});
            },
        }
    }
}
