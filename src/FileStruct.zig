const std = @import("std");

const FileStruct = @This();

/// supported types of file structure objects
pub const FileUnion = union(enum) {
    dir: std.fs.Dir,
    file: std.fs.File,
};

/// name of the file structure object
name: []u8,
/// type of the file structure object
file_union: FileUnion,

pub fn init(name: []u8, file_union: FileUnion) FileStruct {
    return .{ .name = name, .file_union = file_union };
}
