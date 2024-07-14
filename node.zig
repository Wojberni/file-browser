const std = @import("std");
const FileStruct = @import("file_struct.zig");

pub const Node = struct {
    value: FileStruct.FileStruct,
    children: []Node,
};

pub fn newNode(value: FileStruct.FileStruct, children: []Node) Node {
    return Node{ .value = value, .children = children };
}

pub fn addChildrenToNode(allocator: std.mem.Allocator, root_node: *Node) !void {
    const root_dir = root_node.value.file_union.dir;

    var iterator = root_dir.iterate();
    var counter: u32 = 0;

    while (try iterator.next()) |_| {
        counter += 1;
    }

    root_node.children = try allocator.alloc(Node, counter);
    // defer allocator.free(root_node.children);

    iterator = root_dir.iterate();
    counter = 0;

    while (try iterator.next()) |entry| {
        switch (entry.kind) {
            std.fs.File.Kind.directory => {
                const entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
                // defer entry_dir.close();

                const allocated_file_name = try allocator.alloc(u8, entry.name.len);
                std.mem.copyForwards(u8, allocated_file_name, entry.name);

                const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .dir = entry_dir });
                root_node.children[counter] = newNode(file_struct, undefined);
                try addChildrenToNode(allocator, &root_node.children[counter]);
            },
            std.fs.File.Kind.file => {
                const entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_write });
                // defer entry_file.close();

                const allocated_file_name = try allocator.alloc(u8, entry.name.len);
                std.mem.copyForwards(u8, allocated_file_name, entry.name);

                const file_struct = FileStruct.newFileStruct(allocated_file_name, FileStruct.FileUnion{ .file = entry_file });
                root_node.children[counter] = newNode(file_struct, undefined);
            },
            else => unreachable,
        }
        counter += 1;
    }
}

pub fn traverseNodeChildren(node: *const Node, nested_level: u32) void {
    for (0..nested_level) |_| {
        std.debug.print("│   ", .{});
    }
    std.debug.print("├── {s}\n", .{node.value.name});
    for (node.children) |child| {
        switch (child.value.file_union) {
            .dir => {
                traverseNodeChildren(&child, nested_level + 1);
            },
            .file => {
                for (0..nested_level + 1) |_| {
                    std.debug.print("│   ", .{});
                }
                std.debug.print("├── {s}\n", .{child.value.name});
            },
        }
    }
}
