const std = @import("std");

const Tree = @import("tree.zig");
const FileStruct = @import("file_struct.zig");
const Node = @import("node.zig");

const Allocator = std.heap.page_allocator;

pub fn main() !void {
    var tree = try initTree();

    // std.debug.print("{any}\n", .{tree});

    try addChildrenToNode(&tree.root);

    traverseNodes(&tree.root);
}

pub fn initTree() !Tree.Tree {
    const current_dir = std.fs.cwd();
    // const current_path = try current_dir.realpathAlloc(Allocator, ".");
    const current_path = "/home/wojciech/ZigProjects/file-browser/aha";
    // defer Allocator.free(current_path);

    var opened_dir = try current_dir.openDir(current_path, .{ .iterate = true });
    // defer opened_dir.close();

    const current_dir_name = std.fs.path.basename(current_path);

    const file_struct = FileStruct.newFileStruct(current_dir_name, FileStruct.FileUnion{ .dir = &opened_dir });
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
    // defer Allocator.destroy(root_node.children);

    iterator = root_dir.iterate();
    counter = 0;

    while (try iterator.next()) |entry| {
        std.debug.print("Name: {s}, kind: {any}\n", .{ entry.name, entry.kind });
        if (entry.kind == std.fs.File.Kind.directory) {
            var entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
            // defer entry_dir.close();
            const file_struct = FileStruct.newFileStruct(entry.name, FileStruct.FileUnion{ .dir = &entry_dir });
            var node = Node.newNode(file_struct, undefined);
            root_node.children[counter] = node;
            try addChildrenToNode(&node);
        } else if (entry.kind == std.fs.File.Kind.file) {
            var entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_only });
            // defer entry_file.close();
            const file_struct = FileStruct.newFileStruct(entry.name, FileStruct.FileUnion{ .file = &entry_file });
            const node = Node.newNode(file_struct, undefined);
            root_node.children[counter] = node;
        }
        counter += 1;
    }
}

fn traverseNodes(node: *const Node.Node) void {
    std.debug.print("{s}\n", .{node.value.name});
    for (node.children) |child| {
        switch (child.value.file_union) {
            .dir => |_| {
                traverseNodes(&child);
            },
            .file => |_| {
                std.debug.print("{s}\n", .{child.value.name});
            },
        }
    }
}
