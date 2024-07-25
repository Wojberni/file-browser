const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const TestFileStructure = struct {
    file_paths: std.ArrayList([]const u8),
    root_dir: std.fs.Dir,
    test_dir: std.fs.Dir,
    test_dir_name: []const u8,
    allocator: std.mem.Allocator,

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

    pub fn deInit(self: *TestFileStructure) !void {
        defer self.test_dir.close();
        defer self.root_dir.close();
        defer self.file_paths.deinit();

        try self.root_dir.deleteTree(self.test_dir_name);
    }

    fn initFilePaths(self: *TestFileStructure) !void {
        var file_list = std.ArrayList([]const u8).init(self.allocator);
        errdefer file_list.deinit();

        try file_list.append("something.txt");
        try file_list.append("some/thing.txt");
        try file_list.append("some/thing/to/install.txt");
        try file_list.append("some/thing/to/do.txt");
        try file_list.append("some/thing/funny.txt");

        self.file_paths = file_list;
    }

    fn initTestDir(self: *TestFileStructure) !void {
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
            try createPathAndFile(self, entry);
        }
    }

    fn createPathAndFile(self: *TestFileStructure, entry: []const u8) !void {
        var full_item_path: []u8 = try self.allocator.alloc(u8, 0);
        defer self.allocator.free(full_item_path);
        var full_item_name: []u8 = try self.allocator.alloc(u8, 0);
        defer self.allocator.free(full_item_name);

        var ring_buffer = try std.RingBuffer.init(self.allocator, MAX_PATH);
        defer ring_buffer.deinit(self.allocator);

        var path_items_iterator = std.mem.splitSequence(u8, entry, "/");
        while (path_items_iterator.next()) |path_item| {
            if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
                try ring_buffer.writeSlice(path_item);
                try ring_buffer.writeSlice("/");
            } else {
                full_item_name = try self.allocator.realloc(full_item_name, path_item.len);
                std.mem.copyForwards(u8, full_item_name, path_item);
            }
        }

        if (ring_buffer.write_index > 0) {
            full_item_path = try self.allocator.realloc(full_item_path, ring_buffer.write_index);
            try ring_buffer.readFirst(full_item_path, ring_buffer.write_index);
        }

        if (!std.mem.eql(u8, full_item_path, "")) {
            var file_path = try self.test_dir.makeOpenPath(full_item_path, .{});
            defer file_path.close();
            var file = try file_path.createFile(full_item_name, .{});
            defer file.close();
        } else {
            var file = try self.test_dir.createFile(full_item_name, .{});
            defer file.close();
        }
    }
};
