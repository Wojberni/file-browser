const std = @import("std");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");
const Node = @import("node.zig");
const Tests = @import("tests.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var test_file_structure = try TestStruct.TestFileStructure.init(allocator, Tests.TEST_DIR_NAME);

    var tree = try Tree.initTree(allocator, Tests.TEST_DIR_NAME);
    defer Node.deinitNodeChildren(allocator, &tree.root);

    try Node.addChildrenToNode(allocator, &tree.root);
    Node.traverseNodeChildren(&tree.root, 0);

    std.debug.print("Found: '{s}': {}\n", .{ "thing", Node.findMatchingNodeByName(&tree.root, "thing") });
    std.debug.print("Found: '{s}': {}\n", .{ "aha.txt", Node.findMatchingNodeByName(&tree.root, "aha.txt") });

    try test_file_structure.deInit();
}
