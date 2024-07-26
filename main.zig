const std = @import("std");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");
const Tests = @import("tests.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var test_file_structure = try TestStruct.TestFileStructure.init(allocator, Tests.TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(allocator, Tests.TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    tree.traverseTree();

    std.debug.print("Found: '{s}': {}\n", .{ "thing", tree.root.findMatchingNodeByName("thing") });
    std.debug.print("Found: '{s}': {}\n", .{ "aha.txt", tree.root.findMatchingNodeByName("aha.txt") });
}
