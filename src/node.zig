const std = @import("std");
const FileStruct = @import("file_struct.zig").FileStruct;
const FileUtils = @import("file_utils.zig");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const Node = struct {
    value: FileStruct,
    children: std.ArrayList(Node),
    allocator: std.mem.Allocator,
    parent: ?*Node,

    pub const SearchError = error{
        NotFound,
    };

    pub fn init(allocator: std.mem.Allocator, parent: ?*Node, value: FileStruct) Node {
        var children = std.ArrayList(Node).init(allocator);
        errdefer children.deinit();

        return .{ .value = value, .children = children, .allocator = allocator, .parent = parent };
    }

    pub fn deinit(self: *const Node) void {
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
        for (self.children.items) |child| {
            switch (child.value.file_union) {
                .dir => {
                    child.deinit();
                },
                .file => |file| {
                    self.allocator.free(child.value.name);
                    var child_file = file;
                    child_file.close();
                },
            }
        }
        self.children.deinit();
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
                    const entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});

                    const file_struct = FileStruct.init(allocated_file_name, FileStruct.FileUnion{ .dir = entry_dir });
                    const node = Node.init(self.allocator, self, file_struct);
                    try self.children.append(node);
                    try self.children.items[self.children.items.len - 1].loadNodeChildren();
                },
                std.fs.File.Kind.file => {
                    if (self.checkIfChildExists(entry.name)) |_| {
                        continue;
                    }
                    const entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_only });
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});

                    const file_struct = FileStruct.init(allocated_file_name, FileStruct.FileUnion{ .file = entry_file });
                    try self.children.append(Node.init(self.allocator, self, file_struct));
                },
                else => unreachable,
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
            var file_struct: FileStruct = undefined;
            if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
                const dir = try node_iter.value.file_union.dir.openDir(path_item, .{ .iterate = true });
                file_struct = FileStruct.init(allocated_name, FileStruct.FileUnion{ .dir = dir });
            } else {
                const file = try node_iter.value.file_union.dir.openFile(path_item, .{ .mode = std.fs.File.OpenMode.read_only });
                file_struct = FileStruct.init(allocated_name, FileStruct.FileUnion{ .file = file });
            }
            const node = Node.init(self.allocator, node_iter, file_struct);
            try node_iter.children.append(node);
            node_iter = &node_iter.children.items[node_iter.children.items.len - 1];
        }
    }

    pub fn deleteNodeWithPath(self: *Node, path: []const u8) !Node {
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
        for (self.children.items) |*item| {
            if (std.mem.eql(u8, name, item.value.name)) {
                return item;
            }
        }
        return null;
    }

    fn getChildIndex(self: *const Node, name: []const u8) !usize {
        for (self.children.items, 0..) |*item, index| {
            if (std.mem.eql(u8, name, item.value.name)) {
                return index;
            }
        }
        return SearchError.NotFound;
    }

    pub fn findMatchingNodeByName(self: *Node, name: []const u8) ![]const u8 {
        var queue = std.ArrayList(*Node).init(self.allocator);
        defer queue.deinit();
        try queue.insert(0, self);

        while (queue.items.len > 0) {
            const current_node = queue.pop();
            if (std.mem.eql(u8, current_node.value.name, name)) {
                return current_node.getNodePathFromRoot();
            }
            for (current_node.children.items) |*child| {
                try queue.insert(0, child);
            }
        }
        return SearchError.NotFound;
    }

    fn getNodePathFromRoot(self: ?*const Node) ![]const u8 {
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
