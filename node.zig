const std = @import("std");
const FileStruct = @import("file_struct.zig");

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
                    const allocated_file_name = try self.allocator.alloc(u8, entry.name.len);
                    std.mem.copyForwards(u8, allocated_file_name, entry.name);

                    const file_struct = FileStruct.FileStruct.init(allocated_file_name, FileStruct.FileStruct.FileUnion{ .dir = entry_dir });
                    const node = Node.init(self.allocator, self, file_struct);
                    try self.children.append(node);
                    try self.children.items[self.children.items.len - 1].addChildrenToNode();
                },
                std.fs.File.Kind.file => {
                    const entry_file = try root_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_write });
                    const allocated_file_name = try self.allocator.alloc(u8, entry.name.len);
                    std.mem.copyForwards(u8, allocated_file_name, entry.name);

                    const file_struct = FileStruct.FileStruct.init(allocated_file_name, FileStruct.FileStruct.FileUnion{ .file = entry_file });
                    try self.children.append(Node.init(self.allocator, self, file_struct));
                },
                else => unreachable,
            }
        }
    }

    pub fn findMatchingNodeByName(self: *const Node, name: []const u8) SearchError![]const u8 {
        if (std.mem.eql(u8, self.value.name, name)) {
            return getNodePathFromParent(self);
        }
        for (self.children.items) |child| {
            switch (child.value.file_union) {
                .dir => {
                    return findMatchingNodeByName(&child, name);
                },
                .file => {
                    if (std.mem.eql(u8, child.value.name, name)) {
                        return getNodePathFromParent(&child);
                    }
                },
            }
        }
        return SearchError.NotFound;
    }

    fn getNodePathFromParent(self: ?*const Node) []const u8 {
        if (self.?.parent) |parent| {
            return getNodePathFromParent(parent);
        }
        // TODO: return full path instead of placeholder name
        return "found";
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
