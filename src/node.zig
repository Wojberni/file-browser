const std = @import("std");
const FileStruct = @import("file_struct.zig").FileStruct;
const FileUtils = @import("file_utils.zig");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const Node = struct {
    value: FileStruct,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,
    parent: ?*Node,

    pub const SearchError = error{
        NotFound,
    };

    pub fn init(allocator: std.mem.Allocator, parent: ?*Node, value: FileStruct) !*Node {
        var children = std.ArrayList(*Node).init(allocator);
        errdefer children.deinit();
        const node = try allocator.create(Node);
        errdefer allocator.destroy(node);
        node.* = .{ .value = value, .children = children, .allocator = allocator, .parent = parent };
        return node;
    }

    pub fn deinit(self: *const Node) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        self.allocator.free(self.value.name);
        switch (self.value.file_union) {
            .dir => |dir| {
                var node_dir = dir;
                node_dir.close();
            },
            .file => |file| {
                var node_file = file;
                node_file.close();
            },
        }
        self.allocator.destroy(self);
    }

    pub fn isChildless(self: *Node) bool {
        if (self.children.items.len > 0) {
            return false;
        }
        return true;
    }

    pub fn loadNodeChildren(self: *Node) !void {
        const root_dir = self.value.file_union.dir;

        var iterator = root_dir.iterate();
        while (try iterator.next()) |entry| {
            switch (entry.kind) {
                std.fs.File.Kind.directory => {
                    if (self.checkIfChildExists(entry.name)) |node| {
                        try node.loadNodeChildren();
                        continue;
                    }
                    var entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
                    errdefer entry_dir.close();
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});
                    errdefer self.allocator.free(allocated_file_name);

                    const file_struct = FileStruct.init(allocated_file_name, .{ .dir = entry_dir });
                    const node = try Node.init(self.allocator, self, file_struct);
                    try self.children.append(node);
                    try self.children.items[self.children.items.len - 1].loadNodeChildren();
                },
                std.fs.File.Kind.file => {
                    if (self.checkIfChildExists(entry.name)) |_| {
                        continue;
                    }
                    var entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_only });
                    errdefer entry_file.close();
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});
                    errdefer self.allocator.free(allocated_file_name);

                    const file_struct = FileStruct.init(allocated_file_name, .{ .file = entry_file });
                    try self.children.append(try Node.init(self.allocator, self, file_struct));
                },
                else => unreachable,
                // TODO: add std.fs.File.Kind.sym_link support?
            }
        }
    }

    pub fn insertNodeWithPath(self: *Node, path: []const u8) !void {
        try FileUtils.createPathAndFile(self.allocator, self.value.file_union.dir, path);
        var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
        var node_iter = self;
        while (path_items_iterator.next()) |path_item| {
            if (node_iter.checkIfChildExists(path_item)) |node| {
                node_iter = node;
                continue;
            }
            const allocated_name = try std.fmt.allocPrint(self.allocator, "{s}", .{path_item});
            errdefer self.allocator.free(allocated_name);
            var file_struct: FileStruct = undefined;
            if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
                const dir = try node_iter.value.file_union.dir.openDir(path_item, .{ .iterate = true });
                file_struct = FileStruct.init(allocated_name, .{ .dir = dir });
            } else {
                const file = try node_iter.value.file_union.dir.openFile(path_item, .{ .mode = std.fs.File.OpenMode.read_only });
                file_struct = FileStruct.init(allocated_name, .{ .file = file });
            }
            const node = try Node.init(self.allocator, node_iter, file_struct);
            try node_iter.children.append(node);
            node_iter = node_iter.children.items[node_iter.children.items.len - 1];
        }
    }

    pub fn deleteNodeWithPath(self: *Node, path: []const u8) !*Node {
        var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
        var node_iter = self;
        while (path_items_iterator.next()) |path_item| {
            if (node_iter.checkIfChildExists(path_item)) |node| {
                node_iter = node;
            } else {
                return SearchError.NotFound;
            }
        }
        const parent = node_iter.parent.?;
        const last_name = FileUtils.getLastNameFromPath(path);
        try FileUtils.deleteDirOrFileFromDir(parent.value.file_union.dir, last_name);
        return parent.children.orderedRemove(try getChildIndex(parent, last_name));
    }

    fn checkIfChildExists(self: *const Node, name: []const u8) ?*Node {
        for (self.children.items) |item| {
            if (std.mem.eql(u8, name, item.value.name)) {
                return item;
            }
        }
        return null;
    }

    fn getChildIndex(self: *const Node, name: []const u8) !usize {
        for (self.children.items, 0..) |item, index| {
            if (std.mem.eql(u8, name, item.value.name)) {
                return index;
            }
        }
        return SearchError.NotFound;
    }

    pub fn findFirstMatchingName(self: *Node, name: []const u8) ![]const u8 {
        var queue = std.ArrayList(*Node).init(self.allocator);
        defer queue.deinit();
        try queue.insert(0, self);

        while (queue.items.len > 0) {
            const current_node = queue.pop();
            if (std.mem.eql(u8, current_node.value.name, name)) {
                return current_node.getPathFromRoot();
            }
            for (current_node.children.items) |child| {
                try queue.insert(0, child);
            }
        }
        return SearchError.NotFound;
    }

    pub fn findAllContainingName(self: *Node, name: []const u8) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);
        if (name.len == 0) {
            return result;
        }

        var queue = std.ArrayList(*Node).init(self.allocator);
        defer queue.deinit();
        try queue.insert(0, self);

        while (queue.items.len > 0) {
            const current_node = queue.pop();
            if (std.mem.indexOf(u8, current_node.value.name, name) != null) {
                try result.insert(0, try current_node.getPathFromRoot());
            }
            for (current_node.children.items) |child| {
                try queue.insert(0, child);
            }
        }
        return result;
    }

    pub fn getPathFromRoot(self: ?*const Node) ![]const u8 {
        var queue = std.ArrayList([]u8).init(self.?.allocator);
        defer queue.deinit();

        var iterator = self;
        while (iterator != null) : (iterator = iterator.?.parent) {
            try queue.insert(0, iterator.?.value.name);
        }
        const result = try FileUtils.joinArraylistToPath(self.?.allocator, &queue);
        return result;
    }

    pub fn traverseNodeChildren(self: *const Node, nested_level: u32) void {
        for (0..nested_level) |_| {
            std.debug.print("│   ", .{});
        }
        std.debug.print("├── {s}\n", .{self.value.name});
        for (self.children.items) |child| {
            switch (child.value.file_union) {
                .dir => {
                    child.traverseNodeChildren(nested_level + 1);
                },
                .file => {
                    for (0..nested_level + 1) |_| {
                        std.debug.print("│   ", .{});
                    }
                    std.debug.print("├── {s}\n", .{child.value.name});
                },
            }
        }
    }
};
