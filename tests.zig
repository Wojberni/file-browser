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

    const result = try tree.findMatchingNodeByName(FileUtils.getLastNameFromPath(random_file_path));
    defer ALLOCATOR.free(result);
    const expectedPath = try std.fmt.allocPrint(ALLOCATOR, "{s}/{s}", .{ test_file_structure.test_dir_name, random_file_path });
    defer ALLOCATOR.free(expectedPath);

    try std.testing.expectEqualStrings(expectedPath, result);
}

test "check if value cannot be found in tree" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();
    const not_found_name = "aha.txt";
    const result = tree.findMatchingNodeByName(not_found_name);

    try std.testing.expect(result == NODE_NOT_FOUND);
}

test "check if value is inserted into tree and found" {
    var test_file_structure = try TestStruct.TestFileStructure.init(ALLOCATOR, TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(ALLOCATOR, TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const node_path = "some/thing/interesting.txt";
    try tree.insertNodeWithPath(node_path);

    const result = try tree.findMatchingNodeByName(FileUtils.getLastNameFromPath(node_path));
    defer ALLOCATOR.free(result);
    const expectedPath = try std.fmt.allocPrint(ALLOCATOR, "{s}/{s}", .{ test_file_structure.test_dir_name, node_path });
    defer ALLOCATOR.free(expectedPath);

    try std.testing.expectEqualStrings(expectedPath, result);
}
