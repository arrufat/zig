const std = @import("../std.zig");
const builtin = @import("builtin");
const unicode = std.unicode;
const mem = std.mem;
const fs = std.fs;
const native_os = builtin.os.tag;
const posix = std.posix;

pub const GetAppDataDirError = error{
    OutOfMemory,
    AppDataDirUnavailable,
};

/// Caller owns returned memory.
/// TODO determine if we can remove the allocator requirement
pub fn getAppDataDir(allocator: mem.Allocator, appname: []const u8) GetAppDataDirError![]u8 {
    switch (native_os) {
        .windows => {
            const local_app_data_dir = std.process.getEnvVarOwned(allocator, "LOCALAPPDATA") catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => return error.AppDataDirUnavailable,
            };
            defer allocator.free(local_app_data_dir);
            return fs.path.join(allocator, &[_][]const u8{ local_app_data_dir, appname });
        },
        .macos => {
            const home_dir = posix.getenv("HOME") orelse {
                // TODO look in /etc/passwd
                return error.AppDataDirUnavailable;
            };
            return fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Application Support", appname });
        },
        .linux, .freebsd, .netbsd, .dragonfly, .openbsd, .solaris, .illumos => {
            if (posix.getenv("XDG_DATA_HOME")) |xdg| {
                return fs.path.join(allocator, &[_][]const u8{ xdg, appname });
            }

            const home_dir = posix.getenv("HOME") orelse {
                // TODO look in /etc/passwd
                return error.AppDataDirUnavailable;
            };
            return fs.path.join(allocator, &[_][]const u8{ home_dir, ".local", "share", appname });
        },
        .haiku => {
            var dir_path_ptr: [*:0]u8 = undefined;
            if (true) {
                _ = &dir_path_ptr;
                @compileError("TODO: init dir_path_ptr");
            }
            // TODO look into directory_which
            const be_user_settings = 0xbbe;
            const rc = std.c.find_directory(be_user_settings, -1, true, dir_path_ptr, 1);
            const settings_dir = try allocator.dupeZ(u8, mem.sliceTo(dir_path_ptr, 0));
            defer allocator.free(settings_dir);
            switch (rc) {
                0 => return fs.path.join(allocator, &[_][]const u8{ settings_dir, appname }),
                else => return error.AppDataDirUnavailable,
            }
        },
        else => @compileError("Unsupported OS"),
    }
}

test getAppDataDir {
    if (native_os == .wasi) return error.SkipZigTest;

    // We can't actually validate the result
    const dir = getAppDataDir(std.testing.allocator, "zig") catch return;
    defer std.testing.allocator.free(dir);
}
