const std = @import("std");

const NodeValue = @This();

name: []u8,
file_type: FileType,

/// Supported types of file structure objects.
pub const FileType = union(enum) {
    dir: DirStruct,
    file: FileStruct,
    sym_link: SymLinkStruct,
    other: OtherStruct,

    pub const DirStruct = struct {
        metadata: std.fs.File.Metadata,
    };
    pub const FileStruct = struct {
        metadata: std.fs.File.Metadata,
    };
    pub const SymLinkStruct = struct {
        target: []u8,
    };
    pub const OtherStruct = struct {
        type: std.fs.File.Kind,

        /// Returns name for other custom types mapped from std.fs.File.Kind.
        pub fn getTypeName(self: *const OtherStruct) []const u8 {
            const other_types = [_][]const u8{
                "Block Device",
                "Characted Device",
                "Directory",
                "Named Pipe",
                "Symbolic Link",
                "File",
                "UNIX Socket",
                "Whiteout",
                "Door",
                "Event Port",
                "Unknown",
            };
            return other_types[@intFromEnum(self.type)];
        }
    };
};

pub fn init(name: []u8, file_type: FileType) NodeValue {
    return .{
        .name = name,
        .file_type = file_type,
    };
}

pub fn deinit(self: *const NodeValue, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
    switch (self.file_type) {
        .sym_link => |sym_link| {
            allocator.free(sym_link.target);
        },
        else => {},
    }
}
