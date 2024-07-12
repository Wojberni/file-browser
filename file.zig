const std = @import("std");
const Permissons = std.fs.File.Permissions;
const Kind = std.fs.File.Kind;
const Metadata = std.fs.File.Metadata;

pub const File = struct {
    fd: i32,
    size: u64,
    permissions: Permissons,
    kind: Kind,
    accessed: i128,
    modified: i128,
    created: ?i128,
};

pub fn newFile(fd: i32, metadata: Metadata) File {
    return File{
        .fd = fd,
        .size = metadata.size(),
        .permissions = metadata.permissions(),
        .kind = metadata.kind(),
        .accessed = metadata.accessed(),
        .modified = metadata.modified(),
        .created = metadata.created(),
    };
}
