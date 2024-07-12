const std = @import("std");

const Tree = @import("tree.zig");
const File = @import("file.zig");
const Node = @import("node.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    const current_dir = std.fs.cwd();
    const current_dir_metadata = try current_dir.metadata();
    const current_path = try current_dir.realpathAlloc(allocator, ".");
    defer allocator.free(current_path);

    const file = File.newFile(current_dir.fd, current_dir_metadata);
    const node = Node.newNode(file, try allocator.alloc(Node.Node, 0));
    defer allocator.free(node.children);
    const tree = Tree.newTree(node);

    std.debug.print("{}\n", .{tree});

    var opened_dir = try current_dir.openDir(current_path, .{ .iterate = true });
    defer opened_dir.close();

    try iterateOverDir(&opened_dir, ".");
}

fn addChildren() void {}

fn iterateOverDir(root_dir: *std.fs.Dir, name: []const u8) !void {
    var opened_dir = try root_dir.openDir(name, .{ .iterate = true });
    defer opened_dir.close();

    var iterator = opened_dir.iterate();

    while (try iterator.next()) |entry| {
        std.debug.print("Name: {s}, kind: {any}\n", .{ entry.name, entry.kind });
        if (entry.kind == std.fs.File.Kind.directory) {
            try iterateOverDir(&opened_dir, entry.name);
        }
    }
}
