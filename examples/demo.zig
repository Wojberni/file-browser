const std = @import("std");
const Tree = @import("file-browser").Tree;
const fileUtils = @import("file-browser").fileUtils;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const allocator = gpa.allocator();

    var tree = try Tree.init(allocator, ".");
    defer tree.deinit();

    try tree.loadTreeFromDir();
    tree.traverseTree();

    const random_file_name = "main.zig";
    const found_item = try tree.findFirstMatchingName(random_file_name);
    defer allocator.free(found_item);

    const not_found_name = "aha.txt";
    const not_found_item = tree.findFirstMatchingName(not_found_name);

    std.debug.print("Find: '{s}': {s}\n", .{ random_file_name, found_item });
    std.debug.print("Find: '{s}': {any}\n", .{ not_found_name, not_found_item });

    const node_path = "insert/node/name.txt";
    try tree.insertNodeWithPath(node_path);

    const substring = ".zig";
    const matching_names = try tree.findAllContainingName(substring);
    defer matching_names.deinit();

    for (matching_names.items) |item| {
        std.debug.print("Found matching substring: {s} with path:{s}\n", .{ substring, item });
        allocator.free(item);
    }

    const deleted_node = try tree.deleteNodeWithPath(fileUtils.getFirstNameFromPath(node_path));
    deleted_node.traverseNodeChildren(0);
    deleted_node.deinit();
    std.debug.print("Inserted and deleted node path: '{s}'\n", .{node_path});
}
