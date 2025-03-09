const std = @import("std");
const vaxis = @import("vaxis");
const Tree = @import("file-browser").Tree;
const Node = @import("file-browser").Node;
const NodeValue = @import("file-browser").NodeValue;

const MyGui = @This();

/// Necessary for search functionality ArrayList
const FindName = struct {
    name: []const u8,
};

allocator: std.mem.Allocator,
should_quit: bool,
/// Vaxis library TTY
tty: vaxis.Tty,
/// Vaxis library main struct
vx: vaxis.Vaxis,
/// Tree structure loaded from root directory.
tree: Tree,
/// Current location in a tree structure.
current_node: *Node,
/// Used for browsing files. When active, no dialogs will be seen on screen.
main_context: vaxis.widgets.Table.TableContext,
/// Used for moving around found items Table.
find_context: vaxis.widgets.Table.TableContext,
/// Type of dialog with action when main_context is not active.
dialog: TypeDialog = undefined,
/// Input used for search functionality.
text_input: vaxis.widgets.TextInput = undefined,
/// ArrayList of items found in search functionality
find_arraylist: std.ArrayList(FindName),

/// Events handled in event loop.
const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const TypeDialog = enum {
    delete,
    create,
    find,
};

pub fn init(allocator: std.mem.Allocator) !MyGui {
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
        .main_context = .{
            .active_bg = .{ .rgb = .{ 71, 123, 250 } },
            .selected_bg = .{
                .rgb = .{ 64, 128, 255 },
            },
            .header_names = .{
                .custom = &.{ "Name", "Type" },
            },
        },
        .find_context = .{
            .active_bg = .{ .rgb = .{ 71, 123, 250 } },
            .selected_bg = .{
                .rgb = .{ 64, 128, 255 },
            },
            .header_names = .{
                .custom = &.{"Name"},
            },
        },
        .find_arraylist = std.ArrayList(FindName).init(allocator),
    };
}

pub fn deinit(self: *MyGui) void {
    self.vx.deinit(self.allocator, self.tty.anyWriter());
    self.tty.deinit();
    self.tree.deinit();
    self.find_arraylist.deinit();
}

/// Start the GUI applicaton
pub fn run(self: *MyGui) !void {
    var loop: vaxis.Loop(Event) = .{ .tty = &self.tty, .vaxis = &self.vx };
    try loop.init();

    try loop.start();
    defer loop.stop();

    try self.vx.enterAltScreen(self.tty.anyWriter());
    try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

    self.text_input = vaxis.widgets.TextInput.init(self.allocator, &self.vx.unicode);
    defer self.text_input.deinit();
    self.main_context.active = true;

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

        //FIXME: FIND BETTER SOLUTION FOR THIS ISSUE WITH ARRAYLIST
        for (self.find_arraylist.items) |item| {
            self.allocator.free(item.name);
        }
        self.find_arraylist.clearAndFree();
    }
}

/// Handles event caught in the event loop.
fn update(self: *MyGui, event: Event, curr_dir: []const u8) !void {
    if (self.main_context.active) {
        try self.updateTable(event);
    } else {
        switch (self.dialog) {
            .delete => {
                try self.updateDeleteDialog(event, curr_dir);
            },
            .create => {
                try self.updateCreateDialog(event, curr_dir);
            },
            .find => {
                try self.updateFindTable(event);
            },
        }
    }
}

/// Updates main table containing browsed files and directories based on event.
fn updateTable(self: *MyGui, event: Event) !void {
    switch (event) {
        .key_press => |key| {
            if (key.matches('c', .{ .ctrl = true }))
                self.should_quit = true;
            if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{}) and !self.current_node.isChildless())
                self.main_context.row -|= 1;
            if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{}) and !self.current_node.isChildless())
                self.main_context.row +|= 1;
            if (key.matches(vaxis.Key.enter, .{}) and !self.current_node.isChildless()) {
                const selected_item_type = self.current_node.children.items[self.main_context.row].value.file_type;
                const selected_dir = switch (selected_item_type) {
                    .dir => true,
                    else => false,
                };
                if (selected_dir) {
                    self.current_node = self.current_node.children.items[self.main_context.row];
                    self.main_context.row = 0;
                }
            }
            if (key.matches(vaxis.Key.escape, .{}) and self.current_node.parent != null) {
                self.current_node = self.current_node.parent.?;
                self.main_context.row = 0;
            }
            if (key.matches('d', .{ .ctrl = true })) {
                self.main_context.active = false;
                self.dialog = .delete;
            }
            if (key.matches('c', .{})) {
                self.main_context.active = false;
                self.dialog = .create;
            }
            if (key.matches('f', .{})) {
                self.main_context.active = false;
                self.dialog = .find;
                self.main_context.row = 0;
            }
        },
        .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
    }
}

/// Updates delete dialog based on event.
fn updateDeleteDialog(self: *MyGui, event: Event, curr_dir: []const u8) !void {
    switch (event) {
        .key_press => |key| {
            if (key.matches('c', .{ .ctrl = true }))
                self.should_quit = true;
            if (key.matches('y', .{}) and !self.current_node.isChildless()) {
                self.main_context.active = true;
                self.dialog = undefined;
                const selected = self.current_node.children.items[self.main_context.row].value.name;
                const end_delimit = "/";
                const curr_dir_end_index = std.mem.indexOf(u8, curr_dir, end_delimit);
                if (curr_dir_end_index) |end_index| {
                    const path_begin_index = end_index + end_delimit.len;
                    const deleted = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{
                        curr_dir[path_begin_index..],
                        end_delimit,
                        selected,
                    });
                    defer self.allocator.free(deleted);
                    const deleted_node = try self.tree.deleteNodeWithPath(deleted);
                    defer deleted_node.deinit();
                } else {
                    const deleted_node = try self.tree.deleteNodeWithPath(selected);
                    defer deleted_node.deinit();
                }
            }
            if (key.matches('n', .{})) {
                self.main_context.active = true;
                self.dialog = undefined;
            }
        },
        .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
    }
}

/// Updates create dialog based on event.
fn updateCreateDialog(self: *MyGui, event: Event, curr_dir: []const u8) !void {
    switch (event) {
        .key_press => |key| {
            if (key.matches('c', .{ .ctrl = true })) {
                self.should_quit = true;
            } else if (key.matches('l', .{ .ctrl = true })) {
                self.text_input.clearRetainingCapacity();
            } else if (key.matches(vaxis.Key.enter, .{})) {
                self.main_context.active = true;
                self.dialog = undefined;
                const new_file_name = try self.text_input.toOwnedSlice();
                defer self.allocator.free(new_file_name);
                const end_delimit = "/";
                const curr_dir_end_index = std.mem.indexOf(u8, curr_dir, end_delimit);
                if (curr_dir_end_index) |end_index| {
                    const path_begin_index = end_index + end_delimit.len;
                    const inserted = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{
                        curr_dir[path_begin_index..],
                        end_delimit,
                        new_file_name,
                    });
                    defer self.allocator.free(inserted);
                    try self.tree.insertNodeWithPath(inserted);
                } else {
                    try self.tree.insertNodeWithPath(new_file_name);
                }
                self.text_input.clearAndFree();
            } else if (key.matches(vaxis.Key.escape, .{})) {
                self.main_context.active = true;
                self.dialog = undefined;
                self.text_input.clearAndFree();
            } else {
                try self.text_input.update(.{ .key_press = key });
            }
        },
        .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
    }
}

/// Updates table with found items based on event.
fn updateFindTable(self: *MyGui, event: Event) !void {
    switch (event) {
        .key_press => |key| {
            if (key.matches('c', .{ .ctrl = true })) {
                self.should_quit = true;
            } else if (self.find_context.active) {
                if (key.matches(vaxis.Key.escape, .{})) {
                    self.find_context.active = false;
                    self.find_context.row = 0;
                } else if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{})) {
                    self.find_context.row -|= 1;
                } else if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{})) {
                    self.find_context.row +|= 1;
                }
            } else if (!self.find_context.active) {
                if (key.matches('l', .{ .ctrl = true })) {
                    self.text_input.clearRetainingCapacity();
                } else if (key.matches(vaxis.Key.enter, .{})) {
                    self.find_context.active = true;
                } else if (key.matches(vaxis.Key.escape, .{})) {
                    self.main_context.active = true;
                    self.dialog = undefined;
                    self.text_input.clearAndFree();
                } else {
                    try self.text_input.update(.{ .key_press = key });
                }
            }
        },
        .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
    }
}

/// Draws current app state to the terminal screen.
///
/// IMPORTANT: App will crash if less than 90 width and 30 height.
fn draw(self: *MyGui, curr_dir: []const u8) !void {
    var win = self.vx.window();
    win.clear();
    win.hideCursor();

    const top_bar_height: usize = 15;

    if (win.width < 90)
        return error.NotEnoughTerminalWidth;
    if (win.height < 2 * top_bar_height)
        return error.NotEnoughTerminalHeight;

    try drawTopBar(&win, curr_dir, top_bar_height);

    if (self.main_context.active) {
        try self.drawMiddleTable(&win, top_bar_height);
    } else {
        switch (self.dialog) {
            .delete => try drawDeleteDialog(&win, top_bar_height),
            .create => try self.drawCreateDialog(&win, top_bar_height),
            .find => try self.drawFindTable(&win, top_bar_height),
        }
    }
}

/// Draws top bar containing key bindings info.
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
        \\---------------------------------------------------------------------------------------
        \\  Move up      -> Arrow up / k         Move into directory / Accept       -> Enter
        \\  Move down    -> Arrow down / j       Move to parent directory / Go back -> Esc
        \\  Find         -> f                    Delete file / directory            -> Ctrl + d
        \\  Quit program -> Ctrl + c             Create file                        -> c
        \\---------------------------------------------------------------------------------------
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

    var segment_array = [_]vaxis.Cell.Segment{
        logo_segment,
        tutor_segment,
        curr_dir_text_segment,
        curr_dir_segment,
    };

    const top_bar = win.child(.{
        .height = .{ .limit = top_bar_height },
        .border = .{
            .where = .all,
            .glyphs = .{
                .custom = .{ "#", "#", "#", "#", "#", "#" },
            },
            .style = .{
                .fg = .{
                    .rgb = .{ 64, 128, 255 },
                },
            },
        },
    });
    _ = try top_bar.print(segment_array[0..], .{});
}

/// Draws Table containing all browsed files and directories.
fn drawMiddleTable(self: *MyGui, win: *vaxis.Window, top_bar_height: usize) !void {
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

    var list = std.ArrayList(struct { name: []const u8, type: []const u8 }).init(event_alloc);
    defer list.deinit();
    for (self.current_node.children.items) |child| {
        var file_type: []const u8 = undefined;
        switch (child.value.file_type) {
            NodeValue.FileType.file => file_type = "File",
            NodeValue.FileType.dir => file_type = "Directory",
            NodeValue.FileType.sym_link => file_type = "Symbolic Link",
            NodeValue.FileType.other => |other_type| file_type = other_type.getTypeName(),
        }
        try list.append(.{
            .name = child.value.name,
            .type = file_type,
        });
    }

    try vaxis.widgets.Table.drawTable(
        event_alloc,
        middle_bar,
        list,
        &self.main_context,
    );
}

/// Draws delete dialog.
fn drawDeleteDialog(win: *vaxis.Window, top_bar_height: usize) !void {
    const dialog_text = "Are you sure you want to delete this file/folder?\nPress y/n to confirm/decline";
    const borders = 2;
    const max_width = "Are you sure you want to delete this file/folder?\n".len + borders;

    const dialog_bar = win.child(.{
        .x_off = (win.width - max_width) / 2,
        .y_off = top_bar_height,
        .width = .{ .limit = max_width },
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

/// Draws create dialog.
fn drawCreateDialog(self: *MyGui, win: *vaxis.Window, top_bar_height: usize) !void {
    const dialog_text = "(Optionally enter a path with subdirectories to be created for a file)\nEnter a file name to create:";
    const borders = 2;
    const max_width = "(Optionally enter a path with subdirectories to be created for a file)\n".len + borders;
    const max_height = 3;

    const dialog_bar = win.child(.{
        .x_off = (win.width - max_width) / 2,
        .y_off = top_bar_height,
        .width = .{ .limit = max_width },
        .height = .{ .limit = max_height + borders },
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

    const input_height = 1;
    const child = win.child(.{
        .x_off = (win.width - max_width) / 2 + borders / 2,
        .y_off = top_bar_height + max_height,
        .width = .{ .limit = max_width },
        .height = .{ .limit = input_height },
    });
    self.text_input.draw(child);
}

/// Draws Table with found elements from on input text field
fn drawFindTable(self: *MyGui, win: *vaxis.Window, top_bar_height: usize) !void {
    const input_height = 1;
    const borders = 2;
    const child = win.child(.{
        .x_off = 0,
        .y_off = top_bar_height,
        .height = .{ .limit = input_height + borders },
        .border = .{
            .where = .all,
            .glyphs = .single_rounded,
        },
    });
    self.text_input.draw(child);

    var event_arena = std.heap.ArenaAllocator.init(self.allocator);
    defer event_arena.deinit();
    const event_alloc = event_arena.allocator();

    const middle_bar = win.child(.{
        .y_off = top_bar_height + input_height + borders,
        .border = .{
            .where = .all,
            .glyphs = .single_rounded,
        },
    });

    const searched_item = self.text_input.buf.buffer[0..self.text_input.buf.realLength()];
    const search_result = try self.tree.findAllContainingName(searched_item);
    defer search_result.deinit();
    for (search_result.items) |item| {
        try self.find_arraylist.append(.{ .name = item });
    }

    try vaxis.widgets.Table.drawTable(
        event_alloc,
        middle_bar,
        self.find_arraylist,
        &self.find_context,
    );
}
