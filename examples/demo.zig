const std = @import("std");
const Tree = @import("file-browser").Tree;
const FileUtils = @import("file-browser").FileUtils;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var tree = try Tree.init(allocator, ".");
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const random_file_name = "main.zig";
    const found_item = try tree.findMatchingNodeByName(random_file_name);
    defer allocator.free(found_item);

    const not_found_name = "aha.txt";
    const not_found_item = tree.findMatchingNodeByName(not_found_name);

    std.debug.print("Find: '{s}': {s}\n", .{ random_file_name, found_item });
    std.debug.print("Find: '{s}': {any}\n", .{ not_found_name, not_found_item });

    const node_path = "insert/node/name.txt";
    try tree.insertNodeWithPath(node_path);

    const deleted_node = try tree.deleteNodeWithPath(FileUtils.getFirstNameFromPath(node_path));
    deleted_node.traverseNodeChildren(0);
    deleted_node.deinit();
    std.debug.print("Inserted and deleted node path: '{s}'\n", .{node_path});

    tree.traverseTree();
}
