const std = @import("std");
const vaxis = @import("vaxis");
const Tree = @import("file-browser").Tree;
const Node = @import("file-browser").Node;
const FileStruct = @import("file-browser").FileStruct;

pub const MyApp = struct {
    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    tree: Tree,
    current_node: *Node,
    table_context: vaxis.widgets.Table.TableContext = undefined,
    dialog: TypeDialog = undefined,
    file_input: vaxis.widgets.TextInput = undefined,

    const TableEntry = struct { name: []const u8, type: []const u8 };

    const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize };
    const TypeDialog = enum { delete, create, find };

    pub fn init(allocator: std.mem.Allocator) !MyApp {
        var tree = try Tree.init(allocator, ".");
        errdefer tree.deinit();
        try tree.loadTreeFromDir();
        return .{
            .allocator = allocator,
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .tree = tree,
            .current_node = tree.root,
        };
    }

    pub fn deinit(self: *MyApp) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
        self.tree.deinit();
    }

    pub fn run(self: *MyApp) !void {
        var loop: vaxis.Loop(Event) = .{ .tty = &self.tty, .vaxis = &self.vx };
        try loop.init();

        try loop.start();
        defer loop.stop();

        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

        const selected_bg: vaxis.Cell.Color = .{ .rgb = .{ 64, 128, 255 } };
        self.table_context = .{ .selected_bg = selected_bg };
        self.table_context.active = true;

        self.file_input = vaxis.widgets.TextInput.init(self.allocator, &self.vx.unicode);
        defer self.file_input.deinit();

        while (!self.should_quit) {
            const event = loop.nextEvent();

            const current_dir_name = try self.current_node.getPathFromRoot();
            defer self.allocator.free(current_dir_name);

            try self.update(event, current_dir_name);

            const updated_dir_name = try self.current_node.getPathFromRoot();
            defer self.allocator.free(updated_dir_name);

            try self.draw(updated_dir_name);

            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
        }
    }

    fn update(self: *MyApp, event: Event, curr_dir: []const u8) !void {
        if (self.table_context.active) {
            try self.updateTable(event);
        } else {
            switch (self.dialog) {
                .delete => {
                    try self.updateDeleteDialog(event, curr_dir);
                },
                .create => {
                    try self.updateCreateDialog(event, curr_dir);
                },
                else => unreachable,
            }
        }
    }

    fn updateTable(self: *MyApp, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
                if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{}) and !self.current_node.isChildless())
                    self.table_context.row -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{}) and !self.current_node.isChildless())
                    self.table_context.row +|= 1;
                if (key.matches(vaxis.Key.enter, .{}) and !self.current_node.isChildless()) {
                    const selected_item_type = self.current_node.children.items[self.table_context.row].value.file_union;
                    const selected_dir = switch (selected_item_type) {
                        .dir => true,
                        .file => false,
                    };
                    if (selected_dir) {
                        self.current_node = self.current_node.children.items[self.table_context.row];
                        self.table_context.row = 0;
                    }
                }
                if (key.matches(vaxis.Key.escape, .{}) and self.current_node.parent != null) {
                    self.current_node = self.current_node.parent.?;
                    self.table_context.row = 0;
                }
                if (key.matches('d', .{ .ctrl = true })) {
                    self.table_context.active = false;
                    self.dialog = .delete;
                }
                if (key.matches('c', .{})) {
                    self.table_context.active = false;
                    self.dialog = .create;
                }
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    fn updateDeleteDialog(self: *MyApp, event: Event, curr_dir: []const u8) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
                if (key.matches('y', .{}) and !self.current_node.isChildless()) {
                    self.table_context.active = true;
                    self.dialog = undefined;
                    const selected = self.current_node.children.items[self.table_context.row].value.name;
                    const end_delimit = "/";
                    const curr_dir_end_index = std.mem.indexOf(u8, curr_dir, end_delimit);
                    if (curr_dir_end_index) |end_index| {
                        const path_begin_index = end_index + end_delimit.len;
                        const deleted = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ curr_dir[path_begin_index..], end_delimit, selected });
                        defer self.allocator.free(deleted);
                        const deleted_node = try self.tree.deleteNodeWithPath(deleted);
                        defer deleted_node.deinit();
                    } else {
                        const deleted_node = try self.tree.deleteNodeWithPath(selected);
                        defer deleted_node.deinit();
                    }
                }
                if (key.matches('n', .{})) {
                    self.table_context.active = true;
                    self.dialog = undefined;
                }
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    fn updateCreateDialog(self: *MyApp, event: Event, curr_dir: []const u8) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    self.should_quit = true;
                } else if (key.matches('l', .{ .ctrl = true })) {
                    self.file_input.clearRetainingCapacity();
                } else if (key.matches(vaxis.Key.enter, .{})) {
                    self.table_context.active = true;
                    self.dialog = undefined;
                    const new_file_name = try self.file_input.toOwnedSlice();
                    defer self.allocator.free(new_file_name);
                    const end_delimit = "/";
                    const curr_dir_end_index = std.mem.indexOf(u8, curr_dir, end_delimit);
                    if (curr_dir_end_index) |end_index| {
                        const path_begin_index = end_index + end_delimit.len;
                        const inserted = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ curr_dir[path_begin_index..], end_delimit, new_file_name });
                        defer self.allocator.free(inserted);
                        try self.tree.insertNodeWithPath(inserted);
                    } else {
                        try self.tree.insertNodeWithPath(new_file_name);
                    }
                    self.file_input.clearAndFree();
                } else {
                    try self.file_input.update(.{ .key_press = key });
                }
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    fn draw(self: *MyApp, curr_dir: []const u8) !void {
        var win = self.vx.window();
        win.clear();
        win.hideCursor();

        const top_bar_height: usize = 15;

        try drawTopBar(&win, curr_dir, top_bar_height);

        if (self.table_context.active) {
            try self.drawMiddleTable(&win, top_bar_height);
        } else {
            switch (self.dialog) {
                .delete => try drawDeleteDialog(&win, top_bar_height),
                .create => try self.drawCreateDialog(&win, top_bar_height),
                else => unreachable,
            }
        }
    }

    fn drawTopBar(win: *vaxis.Window, curr_dir: []const u8, top_bar_height: usize) !void {
        const logo_text =
            \\      _______ __           __
            \\     / ____(_/ ___        / /_  _________ _      __________  _____
            \\    / /_  / / / _ \______/ __ \/ ___/ __ | | /| / / ___/ _ \/ ___/
            \\   / __/ / / /  __/_____/ /_/ / /  / /_/ | |/ |/ (__  /  __/ /
            \\  /_/   /_/_/\___/     /_.___/_/   \____/|__/|__/____/\___/_/
            \\
        ;
        const tutorial_text =
            \\------------------------------------------------------------------------------------------------------------
            \\  Move up     -> Arrow up / k         Move into directory      -> Enter           Quit program -> Ctrl + c
            \\  Move down   -> Arrow down / j       Move to parent directory -> Esc
            \\  Find        -> f                    Delete file / directory  -> Ctrl + d
            \\                                      Create file              -> c
            \\------------------------------------------------------------------------------------------------------------
            \\
        ;
        const current_dir_text = "\n      Current Dir -> ";

        const logo_segment = vaxis.Cell.Segment{
            .text = logo_text,
            .style = .{ .fg = .{ .rgb = .{ 64, 128, 255 } } },
        };
        const tutor_segment = vaxis.Cell.Segment{
            .text = tutorial_text,
            .style = .{ .fg = .{ .rgb = .{ 64, 128, 255 } } },
        };
        const curr_dir_text_segment = vaxis.Cell.Segment{
            .text = current_dir_text,
            .style = .{ .bold = true, .fg = .{ .rgb = .{ 200, 50, 50 } } },
        };
        const curr_dir_segment = vaxis.Cell.Segment{
            .text = curr_dir,
            .style = .{ .bold = true, .italic = true, .fg = .{ .rgb = .{ 200, 50, 50 } } },
        };

        var segment_array = [_]vaxis.Cell.Segment{ logo_segment, tutor_segment, curr_dir_text_segment, curr_dir_segment };

        const top_bar = win.child(.{
            .height = .{ .limit = top_bar_height },
            .border = .{
                .where = .all,
                .glyphs = .{ .custom = .{ "#", "#", "#", "#", "#", "#" } },
                .style = .{ .fg = .{ .rgb = .{ 64, 128, 255 } } },
            },
        });
        _ = try top_bar.print(segment_array[0..], .{});
    }

    fn drawMiddleTable(self: *MyApp, win: *vaxis.Window, top_bar_height: usize) !void {
        var event_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer event_arena.deinit();
        const event_alloc = event_arena.allocator();

        const middle_bar = win.child(.{
            .x_off = 0,
            .y_off = top_bar_height,
            .height = .{ .limit = win.height - top_bar_height },
            .border = .{
                .where = .all,
                .glyphs = .single_rounded,
            },
        });

        var list = std.ArrayList(TableEntry).init(event_alloc);
        defer list.deinit();
        for (self.current_node.children.items) |child| {
            var file_type: []const u8 = undefined;
            switch (child.value.file_union) {
                FileStruct.FileUnion.file => file_type = "File",
                FileStruct.FileUnion.dir => file_type = "Directory",
            }
            try list.append(.{ .name = child.value.name, .type = file_type });
        }

        try vaxis.widgets.Table.drawTable(
            event_alloc,
            middle_bar,
            &.{ "Name", "Type" },
            list,
            &self.table_context,
        );
    }

    fn drawDeleteDialog(win: *vaxis.Window, top_bar_height: usize) !void {
        const dialog_text = "Are you sure you want to delete this file/folder?\nPress y/n to confirm/decline";

        const dialog_bar = win.child(.{
            .x_off = (win.width - dialog_text.len) / 2,
            .y_off = top_bar_height,
            .width = .{ .limit = dialog_text.len }, //FIXME: length fix, this is wrong
            .height = .{ .limit = 4 },
            .border = .{
                .where = .all,
                .glyphs = .single_rounded,
            },
        });
        const dialog_segment = vaxis.Cell.Segment{
            .text = dialog_text,
            .style = .{},
        };
        var segment_array = [_]vaxis.Cell.Segment{dialog_segment};

        _ = try dialog_bar.print(segment_array[0..], .{});
    }

    fn drawCreateDialog(self: *MyApp, win: *vaxis.Window, top_bar_height: usize) !void {
        const dialog_text = "Enter a file name to create\nOptionally enter a path with subdirectories to be created";

        const dialog_bar = win.child(.{
            .x_off = (win.width - dialog_text.len) / 2,
            .y_off = top_bar_height,
            .width = .{ .limit = dialog_text.len }, //FIXME: length fix, this is wrong
            .height = .{ .limit = 6 },
            .border = .{
                .where = .all,
                .glyphs = .single_rounded,
            },
        });
        const dialog_segment = vaxis.Cell.Segment{
            .text = dialog_text,
            .style = .{},
        };
        var segment_array = [_]vaxis.Cell.Segment{dialog_segment};

        _ = try dialog_bar.print(segment_array[0..], .{});

        // FIXME: use dialog_bar instead of parent win?
        const child = win.child(.{
            .x_off = (win.width - dialog_text.len) / 2 + 1,
            .y_off = top_bar_height + 4,
            .width = .{ .limit = dialog_text.len }, //FIXME: length fix, this is wrong
            .height = .{ .limit = 1 },
        });
        self.file_input.draw(child);
    }
};
