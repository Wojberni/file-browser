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
        var table_context: vaxis.widgets.Table.TableContext = .{ .selected_bg = selected_bg };
        table_context.active = true;

        while (!self.should_quit) {
            var event_arena = std.heap.ArenaAllocator.init(self.allocator);
            defer event_arena.deinit();
            const event_alloc = event_arena.allocator();

            const event = loop.nextEvent();
            try self.update(&table_context, event);
            const current_dir_name = try self.current_node.getPathFromRoot();
            defer self.allocator.free(current_dir_name);
            try self.draw(event_alloc, &table_context, current_dir_name);

            var buffered = self.tty.bufferedWriter();

            try self.vx.render(buffered.writer().any());
            try buffered.flush();
        }
    }

    pub fn update(self: *MyApp, table_context: *vaxis.widgets.Table.TableContext, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
                if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{}) and self.current_node.children.items.len > 0)
                    table_context.row -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{}) and self.current_node.children.items.len > 0)
                    table_context.row +|= 1;
                if (key.matches(vaxis.Key.enter, .{}) and self.current_node.children.items.len > 0) {
                    const selected_item_type = self.current_node.children.items[table_context.row].value.file_union;
                    const selected_dir = switch (selected_item_type) {
                        .dir => true,
                        .file => false,
                    };
                    if (selected_dir) {
                        self.current_node = self.current_node.children.items[table_context.row];
                        table_context.row = 0;
                    }
                }
                if (key.matches(vaxis.Key.escape, .{}) and self.current_node.parent != null) {
                    self.current_node = self.current_node.parent.?;
                    table_context.row = 0;
                }
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    pub fn draw(self: *MyApp, allocator: std.mem.Allocator, context: *vaxis.widgets.Table.TableContext, current_dir_name: []const u8) !void {
        const win = self.vx.window();
        win.clear();

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
            \\----------------------------------------------------------------------------------------------------------
            \\
        ;

        const logo = vaxis.Cell.Segment{
            .text = logo_text,
            .style = .{ .fg = .{ .rgb = .{ 64, 128, 255 } } },
        };
        const tutorial = vaxis.Cell.Segment{
            .text = tutorial_text,
            .style = .{ .fg = .{ .rgb = .{ 64, 128, 255 } } },
        };
        const current_dir_description = vaxis.Cell.Segment{
            .text = "\n      Current Dir -> ",
            .style = .{ .bold = true, .fg = .{ .rgb = .{ 200, 50, 50 } } },
        };
        const current_dir = vaxis.Cell.Segment{
            .text = current_dir_name,
            .style = .{ .bold = true, .italic = true, .fg = .{ .rgb = .{ 200, 50, 50 } } },
        };

        var title_segment = [_]vaxis.Cell.Segment{ logo, tutorial, current_dir_description, current_dir };

        // - Top
        const top_div_height = 12;
        const top_bar = win.initChild(
            0,
            0,
            .{ .limit = win.width },
            .{ .limit = top_div_height },
        );
        _ = try top_bar.print(title_segment[0..], .{});

        // - Middle
        const middle_bar = win.initChild(
            0,
            top_div_height,
            .{ .limit = win.width },
            .{ .limit = win.height - top_bar.height },
        );

        var list = std.ArrayList(TableEntry).init(allocator);
        defer list.deinit();
        for (self.current_node.children.items) |child| {
            var file_type: []const u8 = undefined;
            switch (child.value.file_union) {
                FileStruct.FileUnion.file => file_type = "File",
                FileStruct.FileUnion.dir => file_type = "Directory",
            }
            try list.append(TableEntry{ .name = child.value.name, .type = file_type });
        }

        try vaxis.widgets.Table.drawTable(
            allocator,
            middle_bar,
            &.{ "Name", "Type" },
            list,
            context,
        );
    }
};
