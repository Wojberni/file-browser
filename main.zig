const std = @import("std");
const Tree = @import("tree.zig");
const TestStruct = @import("test_struct.zig");
const Tests = @import("tests.zig");
const FileUtils = @import("file_utils.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var test_file_structure = try TestStruct.TestFileStructure.init(allocator, Tests.TEST_DIR_NAME);
    defer test_file_structure.deinit();

    var tree = try Tree.Tree.init(allocator, Tests.TEST_DIR_NAME);
    defer tree.deinit();

    try tree.loadTreeFromDir();

    const random_file_name = FileUtils.getLastNameFromPath(test_file_structure.getRandomFilePath());
    const found_item = try tree.findMatchingNodeByName(random_file_name);
    defer allocator.free(found_item);

    const not_found_name = "aha.txt";
    const not_found_item = tree.findMatchingNodeByName(not_found_name);

    std.debug.print("Find: '{s}': {s}\n", .{ random_file_name, found_item });
    std.debug.print("Find: '{s}': {any}\n", .{ not_found_name, not_found_item });

    const node_path = "insert/node/name.txt";
    try tree.insertNodeWithPath(node_path);

    tree.traverseTree();
}
