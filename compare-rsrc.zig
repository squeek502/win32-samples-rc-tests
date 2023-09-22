const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        return error.MissingPathArguments;
    }

    const a_path = args[1];
    const b_path = args[2];

    const a_range = try getResourcesSectionRange(allocator, a_path);
    const b_range = try getResourcesSectionRange(allocator, b_path);

    const a_slice = try getRangeSlice(allocator, std.fs.cwd(), a_path, a_range);
    defer allocator.free(a_slice);
    const b_slice = try getRangeSlice(allocator, std.fs.cwd(), b_path, b_range);
    defer allocator.free(b_slice);

    if (!std.mem.eql(u8, a_slice, b_slice)) {
        return error.ResourceSectionsNotIdentical;
    }
}

const Range = struct {
    start: usize,
    end: usize,

    pub fn len(self: Range) usize {
        return self.end - self.start;
    }
};

fn getResourcesSectionRange(allocator: std.mem.Allocator, path: []const u8) !Range {
    var result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "dumpbin", "/nologo", "/SECTION:.rsrc", path },
        .max_output_bytes = std.math.maxInt(u16),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| if (code != 0) return error.NonZeroExitCode,
        .Signal, .Stopped, .Unknown => return error.UnexpectedStop,
    }

    var line_it = std.mem.splitScalar(u8, result.stdout, '\n');
    while (line_it.next()) |line| {
        if (std.mem.indexOf(u8, line, "file pointer to raw data") != null) {
            const x_to_y_str = line[std.mem.indexOfScalar(u8, line, '(').? + 1 .. std.mem.indexOfScalar(u8, line, ')').?];
            const start_str = x_to_y_str[0..std.mem.indexOfScalar(u8, x_to_y_str, ' ').?];
            const end_str = x_to_y_str[std.mem.lastIndexOfScalar(u8, x_to_y_str, ' ').? + 1 ..];
            return .{
                .start = try std.fmt.parseUnsigned(usize, start_str, 16),
                .end = try std.fmt.parseUnsigned(usize, end_str, 16),
            };
        }
    }
    return error.NoResourceDataFound;
}

fn getRangeSlice(allocator: std.mem.Allocator, dir: std.fs.Dir, path: []const u8, range: Range) ![]const u8 {
    var file = try dir.openFile(path, .{});
    defer file.close();

    var buf = try allocator.alloc(u8, range.len());
    errdefer allocator.free(buf);

    const bytes_read = try file.pread(buf, range.start);
    std.debug.assert(bytes_read == range.len());

    return buf;
}
