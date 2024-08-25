const std = @import("std");
const vaxis = @import("vaxis");
const Tree = @import("file-browser").Tree;
const Node = @import("file-browser").Node;

pub const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize };

pub const MyApp = struct {
    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    tree: Tree,
    current_node: *Node,

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
            .current_node = &tree.root,
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

            try self.draw(event_alloc, &table_context);

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
                if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{}))
                    table_context.row -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{}))
                    table_context.row +|= 1;
                if (key.matchesAny(&.{ vaxis.Key.left, 'h' }, .{}))
                    table_context.col -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.right, 'l' }, .{}))
                    table_context.col +|= 1;
                if (key.matches(vaxis.Key.enter, .{}))
                    self.current_node = &self.current_node.children.items[0];
                if (key.matches(vaxis.Key.escape, .{}))
                    self.current_node = self.current_node.parent.?;
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    pub fn draw(self: *MyApp, allocator: std.mem.Allocator, context: *vaxis.widgets.Table.TableContext) !void {
        const win = self.vx.window();
        win.clear();

        var list = std.ArrayList(File).init(allocator);
        defer list.deinit();
        for (self.current_node.children.items) |child| {
            try list.append(File{ .name = child.value.name });
        }

        try vaxis.widgets.Table.drawTable(
            allocator,
            win,
            &.{"Name"},
            list,
            context,
        );
    }
};

pub const File = struct { name: []const u8 };
