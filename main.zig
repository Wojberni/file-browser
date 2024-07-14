const std = @import("std");
const Tree = @import("tree.zig");
const FileStruct = @import("file_struct.zig");
const FileUtils = @import("file_utils.zig");
const Node = @import("node.zig");
const Tests = @import("tests.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var test_file_paths = std.ArrayList([]const u8).init(allocator);
    defer test_file_paths.deinit();
    try Tests.initTestFilePaths(&test_file_paths);

    try FileUtils.createTestDirectoriesStructure(allocator, Tests.TEST_DIR_NAME, &test_file_paths);

    var tree = try Tree.initTree(allocator, Tests.TEST_DIR_NAME);

    try Node.addChildrenToNode(allocator, &tree.root);
    Node.traverseNodeChildren(&tree.root, 0);

    try FileUtils.cleanUp(Tests.TEST_DIR_NAME);
}
