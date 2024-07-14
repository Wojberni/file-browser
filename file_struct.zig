const std = @import("std");

pub const FileStruct = struct {
    name: []u8,
    file_union: FileUnion,
};

pub const FileUnion = union(enum) {
    dir: std.fs.Dir,
    file: std.fs.File,
};

pub fn newFileStruct(name: []u8, file_union: FileUnion) FileStruct {
    return FileStruct{ .name = name, .file_union = file_union };
}
