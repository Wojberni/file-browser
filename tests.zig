const std = @import("std");
const Node = @import("node.zig");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");

const ALLOCATOR = std.testing.allocator;
pub const TEST_DIR_NAME = "testing_dir";

test "check if test files are initialized correctly" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    try test_file_structure.deInit();
}

test "check if tree can be initialized" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);

    var tree = try Tree.initTree(ALLOCATOR, TEST_DIR_NAME);
    defer Node.deinitNodeChildren(ALLOCATOR, &tree.root);

    try Node.addChildrenToNode(ALLOCATOR, &tree.root);

    try test_file_structure.deInit();
}

test "check if tree is initialized correctly" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);

    var tree = try Tree.initTree(ALLOCATOR, TEST_DIR_NAME);
    defer Node.deinitNodeChildren(ALLOCATOR, &tree.root);

    try Node.addChildrenToNode(ALLOCATOR, &tree.root);
    Node.traverseNodeChildren(&tree.root, 0);

    try test_file_structure.deInit();
}

test "check if value can be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);

    var tree = try Tree.initTree(ALLOCATOR, TEST_DIR_NAME);
    defer Node.deinitNodeChildren(ALLOCATOR, &tree.root);

    try Node.addChildrenToNode(ALLOCATOR, &tree.root);
    const result = Node.findMatchingNodeByName(&tree.root, "install.txt");
    try std.testing.expect(result);

    try test_file_structure.deInit();
}

test "check if value cannot be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);

    var tree = try Tree.initTree(ALLOCATOR, TEST_DIR_NAME);
    defer Node.deinitNodeChildren(ALLOCATOR, &tree.root);

    try Node.addChildrenToNode(ALLOCATOR, &tree.root);
    const result = Node.findMatchingNodeByName(&tree.root, "aha.txt");
    try std.testing.expect(!result);

    try test_file_structure.deInit();
}
