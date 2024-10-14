const std = @import("std");

const NodeValue = @This();

/// name of the file structure object
name: []u8,
/// type of the file structure object
file_type: FileType,

/// supported types of file structure objects
pub const FileType = union(enum) {
    dir: DirStruct,
    file: FileStruct,
    sym_link: SymLinkStruct,

    pub const DirStruct = struct {
        metadata: std.fs.File.Metadata,
    };
    pub const FileStruct = struct {
        metadata: std.fs.File.Metadata,
    };
    pub const SymLinkStruct = struct {
        target: []u8,
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
