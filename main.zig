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

    std.debug.print("Find: '{s}': {s}\n", .{ "thing", try tree.findMatchingNodeByName("thing") });
    std.debug.print("Find: '{s}': {any}\n", .{ "aha.txt", tree.findMatchingNodeByName("aha.txt") });
}
