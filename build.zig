const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_source_file = std.Build.FileSource.relative(SRC_DIR ++ "spin.zig");

    // Module
    const spin_mod = b.addModule("spin", .{ .source_file = root_source_file });

    // WIT bindings
    const wit_step = b.step("wit", "Generate WIT bindings for C guest modules");

    inline for (WIT_NAMES, 0..) |WIT_NAME, i| {
        const wit_run = b.addSystemCommand(&.{ "wit-bindgen", "c", if (WIT_IS_IMPORTS[i]) "-i" else "-e", WIT_DIR ++ WIT_NAME ++ ".wit", "--out-dir", SRC_DIR });

        wit_step.dependOn(&wit_run.step);
    }

    b.default_step.dependOn(wit_step);

    // Examples
    const examples_step = b.step("example", "Install examples");

    const spin_up = b.option(bool, "up", "Run examples.") orelse false;

    if (spin_up) {
        var port = [_]u8{ '3', '0', '0', '0' };
        inline for (EXAMPLE_NAMES) |EXAMPLE_NAME| {
            const example_run = b.addSystemCommand(&.{ "spin", "build", "--up", "--listen", "localhost:" ++ port });
            example_run.cwd = EXAMPLES_DIR ++ EXAMPLE_NAME;
            port[3] += 1;

            example_run.step.dependOn(wit_step);
            examples_step.dependOn(&example_run.step);
        }
    } else {
        inline for (EXAMPLE_NAMES) |EXAMPLE_NAME| {
            const example = b.addExecutable(.{
                .name = EXAMPLE_NAME,
                .root_source_file = std.Build.FileSource.relative(EXAMPLES_DIR ++ EXAMPLE_NAME ++ "/main.zig"),
                .target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
                .optimize = .ReleaseSmall,
            });
            example.addCSourceFiles(WIT_C_FILES, WIT_C_FLAGS);
            example.addIncludePath(.{ .path = SRC_DIR });
            example.addModule("spin", spin_mod);
            example.linkLibC();

            const example_install = b.addInstallArtifact(example, .{});

            example_install.step.dependOn(wit_step);
            examples_step.dependOn(&example_install.step);
        }
    }

    b.default_step.dependOn(examples_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ EXAMPLES_DIR, SRC_DIR, "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}

const SRC_DIR = "src/";

const WIT_DIR = "spin/wit/ephemeral/";

const WIT_NAMES = &.{
    "spin-config",
    "spin-http",
    "wasi-outbound-http",
    // "outbound-redis",
    // "spin-redis",
    // "key-value",
};

const WIT_IS_IMPORTS = &[WIT_NAMES.len]bool{
    true,
    false,
    true,
    // true,
    // false,
    // true,
};

const EXAMPLES_DIR = "examples/";

const EXAMPLE_NAMES = &.{
    // "config",
    "http-in",
    "http-out",
};

const WIT_C_FILES = &[WIT_NAMES.len][]const u8{
    SRC_DIR ++ WIT_NAMES[0] ++ ".c",
    SRC_DIR ++ WIT_NAMES[1] ++ ".c",
    SRC_DIR ++ WIT_NAMES[2] ++ ".c",
    // SRC_DIR ++ WIT_NAMES[3] ++ ".c",
    // SRC_DIR ++ WIT_NAMES[4] ++ ".c",
    // SRC_DIR ++ WIT_NAMES[5] ++ ".c",
};

const WIT_C_FLAGS = &.{
    "-Wno-unused-parameter",
    "-Wno-switch-bool",
};