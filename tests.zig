const std = @import("std");
const Node = @import("node.zig");
const Tree = @import("tree.zig");
const FileUtils = @import("file_utils.zig");

const ALLOCATOR = std.testing.allocator;
pub const TEST_DIR_NAME = "testing_dir";

test "check if test files are initialized correctly" {
    var test_file_paths = std.ArrayList([]const u8).init(ALLOCATOR);
    defer test_file_paths.deinit();
    try initTestFilePaths(&test_file_paths);

    try FileUtils.createTestDirectoriesStructure(ALLOCATOR, TEST_DIR_NAME, &test_file_paths);
    try FileUtils.cleanUp(TEST_DIR_NAME);
}

test "check if tree is initialized correctly" {
    var test_file_paths = std.ArrayList([]const u8).init(ALLOCATOR);
    defer test_file_paths.deinit();
    try initTestFilePaths(&test_file_paths);

    try FileUtils.createTestDirectoriesStructure(ALLOCATOR, TEST_DIR_NAME, &test_file_paths);

    var tree = try Tree.initTree(ALLOCATOR, TEST_DIR_NAME);

    try Node.addChildrenToNode(ALLOCATOR, &tree.root);
    Node.traverseNodeChildren(&tree.root, 0);
    Node.deinitNodeChildren(ALLOCATOR, &tree.root);

    try FileUtils.cleanUp(TEST_DIR_NAME);
}

pub fn initTestFilePaths(file_list: *std.ArrayList([]const u8)) !void {
    try file_list.append("something.txt");
    try file_list.append("some/thing.txt");
    try file_list.append("some/thing/to/install.txt");
    try file_list.append("some/thing/to/do.txt");
    try file_list.append("some/thing/funny.txt");
}
