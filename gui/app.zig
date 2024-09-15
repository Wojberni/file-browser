const std = @import("std");
const vaxis = @import("vaxis");
const Tree = @import("file-browser").Tree;
const Node = @import("file-browser").Node;
const FileStruct = @import("file-browser").FileStruct;

const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize };

pub const MyApp = struct {
    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    tree: Tree,
    current_node: *Node,
    table_context: vaxis.widgets.Table.TableContext = undefined,
    dialog_context: vaxis.widgets.Table.TableContext = undefined,

    const TableEntry = struct { name: []const u8, type: []const u8 };

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
        self.dialog_context = .{ .selected_bg = selected_bg };
        self.dialog_context.active = false;

        while (!self.should_quit) {
            var event_arena = std.heap.ArenaAllocator.init(self.allocator);
            defer event_arena.deinit();
            const event_alloc = event_arena.allocator();

            const event = loop.nextEvent();
            try self.update(event);
            const current_dir_name = try self.current_node.getPathFromRoot();
            defer self.allocator.free(current_dir_name);
            try self.draw(event_alloc, current_dir_name);

            var buffered = self.tty.bufferedWriter();

            try self.vx.render(buffered.writer().any());
            try buffered.flush();
        }
    }

    fn update(self: *MyApp, event: Event) !void {
        if (self.table_context.active) {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true }))
                        self.should_quit = true;
                    if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{}) and self.current_node.children.items.len > 0)
                        self.table_context.row -|= 1;
                    if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{}) and self.current_node.children.items.len > 0)
                        self.table_context.row +|= 1;
                    if (key.matches(vaxis.Key.enter, .{}) and self.current_node.children.items.len > 0) {
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
                        self.dialog_context.active = true;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        } else if (self.dialog_context.active) {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true }))
                        self.should_quit = true;
                    if (key.matchesAny(&.{ vaxis.Key.left, 'h' }, .{}))
                        self.dialog_context.col -|= 1;
                    if (key.matchesAny(&.{ vaxis.Key.right, 'l' }, .{}))
                        self.dialog_context.col +|= 1;
                    if (key.matches('y', .{})) {
                        self.dialog_context.active = false;
                        self.table_context.active = true;
                    }
                    if (key.matches('n', .{})) {
                        self.dialog_context.active = false;
                        self.table_context.active = true;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    fn draw(self: *MyApp, allocator: std.mem.Allocator, current_dir_name: []const u8) !void {
        var win = self.vx.window();
        win.clear();

        const top_bar_height = 14;

        try drawTopBar(&win, current_dir_name, top_bar_height);

        // - Middle
        if (self.table_context.active) {
            const middle_bar = win.child(.{
                .x_off = 0,
                .y_off = top_bar_height,
                .height = .{ .limit = win.height - top_bar_height },
                .border = .{
                    .where = .all,
                    .glyphs = .single_rounded,
                },
            });

            var list = std.ArrayList(TableEntry).init(allocator);
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
                allocator,
                middle_bar,
                &.{ "Name", "Type" },
                list,
                &self.table_context,
            );
        }

        // Dialog box
        if (self.dialog_context.active) {
            const dialog_text = "Are you sure you want to delete this file?\nPress y/n to confirm/decline";

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
    }

    fn drawTopBar(win: *vaxis.Window, curr_dir: []const u8, top_bar_height: comptime_int) !void {
        const logo_text =
            \\      _______ __           __
            \\     / ____(_/ ___        / /_  _________ _      __________  _____
            \\    / /_  / / / _ \______/ __ \/ ___/ __ | | /| / / ___/ _ \/ ___/
            \\   / __/ / / /  __/_____/ /_/ / /  / /_/ | |/ |/ (__  /  __/ /
            \\  /_/   /_/_/\___/     /_.___/_/   \____/|__/|__/____/\___/_/
            \\
        ;
        const tutorial_text =
            \\----------------------------------------------------------------------------------------------------------
            \\  Move up   -> Arrow up / k         Move into directory      -> Enter           Quit program -> Ctrl + c
            \\  Move down -> Arrow down / j       Move to parent directory -> Esc
            \\                                    Delete file / directory  -> Ctrl + d
            \\----------------------------------------------------------------------------------------------------------
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

        // FIXME: change glyphs to custom
        // const single_rounded: [6][]const u8 = .{ "#", "#", "#", "#", "#", "#" };
        const top_bar = win.child(.{
            .height = .{ .limit = top_bar_height },
            .border = .{
                .where = .all,
                .glyphs = .single_rounded,
            },
        });
        _ = try top_bar.print(segment_array[0..], .{});
    }
};
