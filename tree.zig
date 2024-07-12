const Node = @import("node.zig").Node;

pub const Tree = struct { root: Node };

pub fn newTree(root: Node) Tree {
    return Tree{ .root = root };
}
