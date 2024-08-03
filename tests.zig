const std = @import("std");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");
const FileUtils = @import("file_utils.zig");

const ALLOCATOR = std.testing.allocator;
pub const TEST_DIR_NAME = "testing_dir";
const NODE_NOT_FOUND = @import("node.zig").Node.SearchError.NotFound;

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

test "check if tree can be traversed" {
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
    const random_file_path = test_file_structure.getRandomFilePath();

    const node_path = try tree.findMatchingNodeByName(FileUtils.getLastNameFromPath(random_file_path));
    defer ALLOCATOR.free(node_path);
    const expected_path = try std.fmt.allocPrint(ALLOCATOR, "{s}/{s}", .{ test_file_structure.test_dir_name, random_file_path });
    defer ALLOCATOR.free(expected_path);

    try std.testing.expectEqualStrings(expected_path, node_path);
}

test "check if value cannot be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    const not_found_name = "aha.txt";
    const node_path = tree.findMatchingNodeByName(not_found_name);

    try std.testing.expect(node_path == NODE_NOT_FOUND);
}

test "check if value is inserted into tree and found after" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const inserted_node = "some/thing/interesting.txt";
    try tree.insertNodeWithPath(inserted_node);

    const node_path = try tree.findMatchingNodeByName(FileUtils.getLastNameFromPath(inserted_node));
    defer ALLOCATOR.free(node_path);
    const expected_path = try std.fmt.allocPrint(ALLOCATOR, "{s}/{s}", .{ test_file_structure.test_dir_name, inserted_node });
    defer ALLOCATOR.free(expected_path);

    try std.testing.expectEqualStrings(expected_path, node_path);
}

test "check if value is deleted from tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const random_file_path = test_file_structure.getRandomFilePath();
    const deleted_node = try tree.deleteNodeWithPath(random_file_path);
    defer deleted_node.deinit();
    
    try std.testing.expectEqualStrings(FileUtils.getLastNameFromPath(random_file_path), deleted_node.value.name);
}

test "check if value cannot be deleted from tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const not_deleted_node = "not/valid/name.txt";
    const deleted_node = tree.deleteNodeWithPath(not_deleted_node);
    
    try std.testing.expect(deleted_node == NODE_NOT_FOUND);
}