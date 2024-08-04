const std = @import("std");

const MAX_PATH = std.os.linux.PATH_MAX;

pub const FileStruct = struct {
    name: []u8,
    file_union: FileUnion,

    pub const FileUnion = union(enum) {
        dir: std.fs.Dir,
        file: std.fs.File,
    };

    pub fn init(name: []u8, file_union: FileUnion) FileStruct {
        return .{ .name = name, .file_union = file_union };
    }
};
