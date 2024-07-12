const File = @import("file.zig").File;

pub const Node = struct {
    value: File,
    children: []Node,
};

pub fn newNode(value: File, children: []Node) Node {
    return Node{ .value = value, .children = children };
}
