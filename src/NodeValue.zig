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

    pub const DirStruct = struct {
        metadata: std.fs.File.Metadata,
    };
    pub const FileStruct = struct {
        metadata: std.fs.File.Metadata,
    };
};

pub fn init(name: []u8, file_type: FileType) NodeValue {
    return .{
        .name = name,
        .file_type = file_type,
    };
}
