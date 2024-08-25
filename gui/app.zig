const std = @import("std");
const vaxis = @import("vaxis");

pub const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize };

pub const MyApp = struct {
    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    current_level: usize,
    test_max_level: usize,

    pub fn init(allocator: std.mem.Allocator) !MyApp {
        return .{
            .allocator = allocator,
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .current_level = 0,
            .test_max_level = 4,
        };
    }

    pub fn deinit(self: *MyApp) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    pub fn run(self: *MyApp) !void {
        var loop: vaxis.Loop(Event) = .{ .tty = &self.tty, .vaxis = &self.vx };
        try loop.init();

        try loop.start();
        defer loop.stop();

        const test_list = try createTestList(self.allocator);
        defer {
            for (test_list) |item| {
                item.deinit();
            }
        }

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

            try self.draw(event_alloc, test_list, &table_context);

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
                if (key.matches(vaxis.Key.enter, .{}) and self.current_level < self.test_max_level - 1)
                    self.current_level += 1;
                if (key.matches(vaxis.Key.escape, .{}))
                    self.current_level -|= 1;
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    pub fn draw(self: *MyApp, allocator: std.mem.Allocator, all_items: [4]std.ArrayList(File), context: *vaxis.widgets.Table.TableContext) !void {
        const win = self.vx.window();
        win.clear();

        const item_list = all_items[self.current_level];

        try vaxis.widgets.Table.drawTable(
            allocator,
            win,
            &.{"Name"},
            item_list,
            context,
        );
    }
};

pub const File = struct { name: []const u8 };

pub fn createTestList(allocator: std.mem.Allocator) ![4]std.ArrayList(File) {
    const first_file_structure = [_]File{
        .{ .name = "something.txt" },
    };
    const second_file_structure = [_]File{
        .{ .name = "some/thing.txt" },
        .{ .name = "some/thing" },
    };
    const third_file_structure = [_]File{
        .{ .name = "some/thing/funny.txt" },
        .{ .name = "some/thing/to" },
    };
    const fourth_file_structure = [_]File{ .{ .name = "some/thing/to/install.txt" }, .{ .name = "some/thing/to/do.txt" } };

    const first_buf = try allocator.dupe(File, first_file_structure[0..]);
    const first_list = std.ArrayList(File).fromOwnedSlice(allocator, first_buf);

    const second_buf = try allocator.dupe(File, second_file_structure[0..]);
    const second_list = std.ArrayList(File).fromOwnedSlice(allocator, second_buf);

    const third_buf = try allocator.dupe(File, third_file_structure[0..]);
    const third_list = std.ArrayList(File).fromOwnedSlice(allocator, third_buf);

    const fourth_buf = try allocator.dupe(File, fourth_file_structure[0..]);
    const fourth_list = std.ArrayList(File).fromOwnedSlice(allocator, fourth_buf);

    return .{ first_list, second_list, third_list, fourth_list };
}
