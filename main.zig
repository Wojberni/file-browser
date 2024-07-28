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

    const random_file_path = try test_file_structure.getRandomFilePath();
    defer allocator.free(random_file_path);
    const random_file_name = TestStruct.TestFileStructure.getFilenameFromFilePath(random_file_path);
    const found_item = try tree.findMatchingNodeByName(random_file_name);
    defer allocator.free(found_item);
    const not_found_name = "aha.txt";
    const not_found_item = tree.findMatchingNodeByName(not_found_name);

    std.debug.print("Find: '{s}': {s}\n", .{ random_file_name, found_item });
    std.debug.print("Find: '{s}': {any}\n", .{ not_found_name, not_found_item });
}
