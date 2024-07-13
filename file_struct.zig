const std = @import("std");
const Dir = std.fs.Dir;
const File = std.fs.File;

pub const FileStruct = struct {
    name: []u8,
    file_union: FileUnion,
};

pub const FileUnion = union(enum) {
    dir: Dir,
    file: File,
};

pub fn newFileStruct(name: []u8, file_union: FileUnion) FileStruct {
    return FileStruct{ .name = name, .file_union = file_union };
}
