const std = @import("std");
const FileStruct = @import("file_struct.zig");
const FileUtils = @import("file_utils.zig");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const Node = struct {
    value: FileStruct.FileStruct,
    children: std.ArrayList(Node),
    allocator: std.mem.Allocator,
    parent: ?*const Node,

    pub const SearchError = error{
        NotFound,
    };

    pub fn init(allocator: std.mem.Allocator, parent: ?*const Node, value: FileStruct.FileStruct) Node {
        var children = std.ArrayList(Node).init(allocator);
        errdefer children.deinit();

        return Node{ .value = value, .children = children, .allocator = allocator, .parent = parent };
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

    pub fn addChildrenToNode(self: *Node) !void {
        const root_dir = self.value.file_union.dir;

        var iterator = root_dir.iterate();

        while (try iterator.next()) |entry| {
            switch (entry.kind) {
                std.fs.File.Kind.directory => {
                    const entry_dir = try root_dir.openDir(entry.name, .{ .iterate = true });
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});

                    const file_struct = FileStruct.FileStruct.init(allocated_file_name, FileStruct.FileStruct.FileUnion{ .dir = entry_dir });
                    const node = Node.init(self.allocator, self, file_struct);
                    try self.children.append(node);
                    try self.children.items[self.children.items.len - 1].addChildrenToNode();
                },
                std.fs.File.Kind.file => {
                    const entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_write });
                    const allocated_file_name = try std.fmt.allocPrint(self.allocator, "{s}", .{entry.name});

                    const file_struct = FileStruct.FileStruct.init(allocated_file_name, FileStruct.FileStruct.FileUnion{ .file = entry_file });
                    try self.children.append(Node.init(self.allocator, self, file_struct));
                },
                else => unreachable,
            }
        }
    }

    pub fn addChild(self: *Node, name: []u8) !*Node {
        for (self.children.items) |*item| {
            if (std.mem.eql(u8, name, item.value.name)) {
                return item;
            }
        }
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
