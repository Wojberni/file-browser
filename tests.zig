const std = @import("std");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");

const ALLOCATOR = std.testing.allocator;
pub const TEST_DIR_NAME = "testing_dir";

test "check if test files are initialized correctly" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();
}

test "check if tree can be initialized" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
}

test "check if tree is initialized correctly" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    tree.traverseTree();
}

test "check if value can be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    const result = tree.root.findMatchingNodeByName("install.txt");
    try std.testing.expect(result);
}

test "check if value cannot be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    const result = tree.root.findMatchingNodeByName("aha.txt");
    try std.testing.expect(!result);
}
