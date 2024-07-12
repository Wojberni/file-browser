const FileStruct = @import("file_struct.zig").FileStruct;

pub const Node = struct {
    value: FileStruct,
    children: []Node,
};

pub fn newNode(value: FileStruct, children: []Node) Node {
    return Node{ .value = value, .children = children };
}
