const std = @import("std");
const NodeValue = @import("NodeValue.zig");
const fileUtils = @import("file_utils.zig");

const Node = @This();

value: NodeValue,
children: std.ArrayList(*Node),
allocator: std.mem.Allocator,
parent: ?*Node,
cwd_dir: *std.fs.Dir,

pub const SearchError = error{
    NotFound,
};

pub fn init(allocator: std.mem.Allocator, cwd_dir: *std.fs.Dir, parent: ?*Node, value: NodeValue) !*Node {
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();
    const node = try allocator.create(Node);
    errdefer allocator.destroy(node);
    node.* = .{
        .value = value,
        .children = children,
        .allocator = allocator,
        .parent = parent,
        .cwd_dir = cwd_dir,
    };
    return node;
}

pub fn deinit(self: *const Node) void {
    for (self.children.items) |child| {
        child.deinit();
    }
    self.children.deinit();
    self.value.deinit(self.allocator);
    self.allocator.destroy(self);
}

/// Returns if Node has items in ArrayList.
pub fn isChildless(self: *Node) bool {
    if (self.children.items.len > 0) {
        return false;
    }
    return true;
}

/// Loads directory structure to the library tree structure.
pub fn loadNodeChildren(self: *Node) !void {
    var cur_dir = try self.getDirOfNode();
    defer {
        if (self.parent) |_| {
            cur_dir.close();
        }
    }

    var iterator = cur_dir.iterate();
    while (try iterator.next()) |entry| {
        switch (entry.kind) {
            std.fs.File.Kind.directory => {
                if (self.checkIfChildExists(entry.name)) |node| {
                    try node.loadNodeChildren();
                    continue;
                }
                var entry_dir = try cur_dir.openDir(entry.name, .{});
                defer entry_dir.close();
                const allocated_file_name = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(allocated_file_name);

                const value = NodeValue.init(allocated_file_name, .{
                    .dir = .{
                        .metadata = try entry_dir.metadata(),
                    },
                });
                const node = try Node.init(self.allocator, self.cwd_dir, self, value);
                try self.children.append(node);
                try self.children.items[self.children.items.len - 1].loadNodeChildren();
            },
            std.fs.File.Kind.file => {
                if (self.checkIfChildExists(entry.name)) |_| {
                    continue;
                }
                var entry_file = try cur_dir.openFile(entry.name, .{ .mode = std.fs.File.OpenMode.read_only });
                defer entry_file.close();
                const allocated_file_name = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(allocated_file_name);

                const value = NodeValue.init(allocated_file_name, .{
                    .file = .{
                        .metadata = try entry_file.metadata(),
                    },
                });
                try self.children.append(try Node.init(self.allocator, self.cwd_dir, self, value));
            },
            std.fs.File.Kind.sym_link => {
                if (self.checkIfChildExists(entry.name)) |_| {
                    continue;
                }
                const buffer: []u8 = try self.allocator.alloc(u8, 1024);
                defer self.allocator.free(buffer);
                const target = try cur_dir.readLink(entry.name, buffer);

                const allocated_target = try self.allocator.dupe(u8, target);
                errdefer self.allocator.free(allocated_target);

                const allocated_file_name = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(allocated_file_name);

                const value = NodeValue.init(allocated_file_name, .{
                    .sym_link = .{
                        .target = allocated_target,
                    },
                });
                try self.children.append(try Node.init(self.allocator, self.cwd_dir, self, value));
            },
            else => {
                if (self.checkIfChildExists(entry.name)) |_| {
                    continue;
                }

                const allocated_name = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(allocated_name);

                const value = NodeValue.init(allocated_name, .{
                    .other = .{
                        .type = entry.kind,
                    },
                });
                try self.children.append(try Node.init(self.allocator, self.cwd_dir, self, value));
            },
        }
    }
}

/// Creates node and adds it to tree file structure on given path.
/// If no extension given, it creates a directory. Otherwise it will create a file.
/// Returns error if file cannot be created.
///
/// IMPORTANT: Do use with care! This function operates on real files, so it will create new files!
pub fn insertNodeWithPath(self: *Node, path: []const u8) !void {
    var cur_dir = try self.getDirOfNode();
    defer {
        if (self.parent) |_| {
            cur_dir.close();
        }
    }

    try fileUtils.createPathAndFile(self.allocator, cur_dir, path);
    var path_items_iterator = std.mem.tokenizeSequence(u8, path, "/");
    var node_iter = self;
    while (path_items_iterator.next()) |path_item| {
        if (node_iter.checkIfChildExists(path_item)) |node| {
            node_iter = node;
            continue;
        }
        const allocated_name = try self.allocator.dupe(u8, path_item);
        errdefer self.allocator.free(allocated_name);
        var file_struct: NodeValue = undefined;
        var iter_dir = try node_iter.getDirOfNode();

        if (std.mem.eql(u8, std.fs.path.extension(path_item), "")) {
            const dir = try iter_dir.openDir(path_item, .{});
            file_struct = NodeValue.init(allocated_name, .{
                .dir = .{
                    .metadata = try dir.metadata(),
                },
            });
        } else {
            const file = try iter_dir.openFile(path_item, .{ .mode = std.fs.File.OpenMode.read_only });
            file_struct = NodeValue.init(allocated_name, .{
                .file = .{
                    .metadata = try file.metadata(),
                },
            });
        }

        if (node_iter.parent) |_| {
            iter_dir.close();
        }

        const node = try Node.init(self.allocator, self.cwd_dir, node_iter, file_struct);
        try node_iter.children.append(node);
        node_iter = node_iter.children.items[node_iter.children.items.len - 1];
    }
}

/// Given path removes passed node with children its contains.
/// Returns found node or SearchError.NotFound, if node is not found.
///
/// NOTE: As node is removed only from arraylist, you MUST deinitialize it later.
///
/// IMPORTANT: Do use with care! This function operates on real files, so deleting with remove your files!
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
    const last_name = std.fs.path.basename(path);
    var parent_dir = try parent.getDirOfNode();
    defer {
        if (parent.parent) |_| {
            parent_dir.close();
        }
    }
    try fileUtils.deleteDirOrFileFromDir(parent_dir, last_name);
    return parent.children.orderedRemove(try getChildIndex(parent, last_name));
}

/// Checks if child node is found.
///
/// Returns matching node or null, if node is not found.
fn checkIfChildExists(self: *const Node, name: []const u8) ?*Node {
    for (self.children.items) |item| {
        if (std.mem.eql(u8, name, item.value.name)) {
            return item;
        }
    }
    return null;
}

/// Looks for a child in node items.
///
/// Returns SearchError.NotFound, if no matching node found or current element index in items array.
fn getChildIndex(self: *const Node, name: []const u8) !usize {
    for (self.children.items, 0..) |item, index| {
        if (std.mem.eql(u8, name, item.value.name)) {
            return index;
        }
    }
    return SearchError.NotFound;
}

/// Find using BFS algorithm - Bread First Search.
/// Returns a path to a first found matching node.
///
/// NOTE: as it returns string, don't forget to free it.
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

/// Returns all nodes mathing passed substring.
///
/// NOTE: As it returns ArrayList, don't forget to free it.
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

/// Returns a path, that you have to traverse to get from parent node to selected node.
///
/// NOTE: As it returns string, don't forget to free it.
pub fn getPathFromRoot(self: ?*const Node) ![]const u8 {
    var queue = std.ArrayList([]u8).init(self.?.allocator);
    defer queue.deinit();

    var iterator = self;
    while (iterator != null) : (iterator = iterator.?.parent) {
        try queue.insert(0, iterator.?.value.name);
    }
    return try fileUtils.joinArraylistToPath(self.?.allocator, &queue);
}

/// Returns a path without root directory, used for Dir struct creation.
///
/// NOTE: As it returns string, don't forget to free it.
fn getPathWithoutRoot(self: ?*const Node) ![]const u8 {
    var queue = std.ArrayList([]u8).init(self.?.allocator);
    defer queue.deinit();

    var iterator = self;
    while (iterator.?.parent != null) : (iterator = iterator.?.parent) {
        try queue.insert(0, iterator.?.value.name);
    }
    return try fileUtils.joinArraylistToPath(self.?.allocator, &queue);
}

/// Prints all items in directory and subdirectories recursively.
pub fn traverseNodeChildren(self: *const Node, nested_level: u32) void {
    for (0..nested_level) |_| {
        std.debug.print("│   ", .{});
    }
    std.debug.print("├── {s}\n", .{self.value.name});
    for (self.children.items) |child| {
        switch (child.value.file_type) {
            .dir => {
                child.traverseNodeChildren(nested_level + 1);
            },
            else => {
                for (0..nested_level + 1) |_| {
                    std.debug.print("│   ", .{});
                }
                std.debug.print("├── {s}\n", .{child.value.name});
            },
        }
    }
}

/// Returns struct containing file descriptor of Dir.
///
/// NOTE: Do not forget to close it.
fn getDirOfNode(self: ?*const Node) !std.fs.Dir {
    switch (self.?.value.file_type) {
        .dir => {
            const full_path = try self.?.getPathWithoutRoot();
            defer self.?.allocator.free(full_path);
            if (full_path.len == 0) {
                return self.?.cwd_dir.*;
            }
            return try self.?.cwd_dir.openDir(full_path, .{ .iterate = true });
        },
        else => return undefined,
    }
}
