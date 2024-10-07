const std = @import("std");
const fileUtils = @import("file-browser").fileUtils;

const TestFileStructure = @This();

file_paths: std.ArrayList([]const u8),
root_dir: std.fs.Dir,
test_dir: std.fs.Dir,
test_dir_name: []const u8,
allocator: std.mem.Allocator,

const InitTestDirError = error{CannotBeCurrentDir};

pub fn init(allocator: std.mem.Allocator, test_dir_name: []const u8) !TestFileStructure {
    var test_file_structure = TestFileStructure{
        .allocator = allocator,
        .test_dir_name = test_dir_name,
        .test_dir = undefined,
        .root_dir = undefined,
        .file_paths = undefined,
    };
    try test_file_structure.initFilePaths();
    try test_file_structure.initTestDir();
    try test_file_structure.createTestFileStructure();
    return test_file_structure;
}

pub fn deinit(self: *TestFileStructure) void {
    defer self.test_dir.close();
    defer self.root_dir.close();
    defer self.file_paths.deinit();

    self.root_dir.deleteTree(self.test_dir_name) catch |err| {
        std.debug.print("Failed to delete test directory '{s}': {}\n", .{ self.test_dir_name, err });
    };
}

pub fn getRandomFilePath(self: *TestFileStructure) []const u8 {
    const rand = std.crypto.random;
    const random_index = rand.intRangeAtMost(usize, 0, self.file_paths.items.len - 1);
    return self.file_paths.items[random_index];
}

fn initFilePaths(self: *TestFileStructure) !void {
    var file_list = std.ArrayList([]const u8).init(self.allocator);
    errdefer file_list.deinit();

    try file_list.append("something.txt");
    try file_list.append("some/thing.txt");
    try file_list.append("some/thing/funny.txt");
    try file_list.append("some/thing");
    try file_list.append("some/thing/to/install.txt");
    try file_list.append("some/thing/to/do.txt");
    try file_list.append("some/thing/to");

    self.file_paths = file_list;
}

fn initTestDir(self: *TestFileStructure) !void {
    if (std.mem.eql(u8, self.test_dir_name, ".")) {
        return InitTestDirError.CannotBeCurrentDir;
    }

    self.root_dir = try std.fs.cwd().openDir(".", .{});
    errdefer self.root_dir.close();
    self.root_dir.makeDir(self.test_dir_name) catch |err| {
        std.debug.print("Failed to create test directory '{s}': {}\n", .{ self.test_dir_name, err });
        return err;
    };
    self.test_dir = try self.root_dir.openDir(self.test_dir_name, .{});
    errdefer self.test_dir.close();
}

fn createTestFileStructure(self: *TestFileStructure) !void {
    for (self.file_paths.items) |entry| {
        try fileUtils.createPathAndFile(self.allocator, self.test_dir, entry);
    }
}
