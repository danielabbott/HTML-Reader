const std = @import("std");
const string = @import("String.zig");
const Allocator = std.mem.Allocator;
const tags = @import("Tags.zig");
const ANSIEscCode = @import("ANSITerminal.zig").ANSIEscCode;

pub fn parseHTML(allocator: Allocator, html_: []const u8, output_ansi_codes: bool) ![]u8 {
    var html = html_;

    // 1 is added when a relevant tag is entered and subtracted when the tag is closed
    var in_link: i32 = 0;
    var in_bold: i32 = 0;
    var in_italics: i32 = 0;
    var in_underline: i32 = 0;
    var in_strikethrough: i32 = 0;
    var in_h1: i32 = 0;
    var in_h2_h3: i32 = 0;
    var in_list: i32 = 0;
    var in_code: i32 = 0;

    var tag_stack = std.ArrayList([]const u8).init(allocator);
    defer tag_stack.deinit();

    html = string.skip(html, string.isWhitespace, true);
    var output_string = std.ArrayList(u8).init(allocator);

    var ansi_state = ANSIEscCode{};
    var ansi_str: [15]u8 = undefined;

    // For merging whitespace together
    // Cannot check output_string directly as it might end in a ANSI control code
    var last_char_was_whitespace = false;
    var last_char_was_newline = false;

    while (html.len > 0) {
        if (html[0] == '<') {
            html = html[1..];
            if (html.len == 0) {
                break;
            }

            var is_closing_tag = false;

            if (html[0] == '!') {
                if (html.len < 3) {
                    break;
                }

                if (html[1] == '-' and html[2] == '-') {
                    // Comment
                    html = string.findAndSkip(html, "-->");
                    continue;
                } else {
                    html = html[1..];
                }
            } else if (html[0] == '/') {
                // Closing tag
                is_closing_tag = true;
                html = html[1..];
            }

            const tag_start = string.getStart(html, string.isASCIIAlphabet, true);
            const tag_number_suffix = string.getStart(html[tag_start.len..], string.isDigit, true);

            const tag = html[0 .. tag_start.len + tag_number_suffix.len];

            html = html[tag.len..];
            if (html.len == 0) {
                break;
            }

            var in_vars_add: i32 = if (is_closing_tag) -1 else 1;
            if (std.ascii.eqlIgnoreCase(tag, "ul") or std.ascii.eqlIgnoreCase(tag, "ol")) {
                in_list += in_vars_add;
            }

            // Update colours

            if (output_ansi_codes) {
                if (std.ascii.eqlIgnoreCase(tag, "a")) {
                    in_link += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "strong") or std.ascii.eqlIgnoreCase(tag, "b")) {
                    in_bold += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "h1")) {
                    in_h1 += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "h2") or std.ascii.eqlIgnoreCase(tag, "h3")) {
                    in_h2_h3 += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "em") or std.ascii.eqlIgnoreCase(tag, "i")) {
                    in_italics += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "u")) {
                    in_underline += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "strike") or std.ascii.eqlIgnoreCase(tag, "s") or
                    std.ascii.eqlIgnoreCase(tag, "del"))
                {
                    in_strikethrough += in_vars_add;
                } else if (std.ascii.eqlIgnoreCase(tag, "code")) {
                    in_code += in_vars_add;
                }

                var new_ansi_state = ANSIEscCode{
                    .bold = in_bold > 0 or in_h1 > 0,
                    .underline = in_underline > 0,
                    .italics = in_italics > 0,
                    .strikethrough = in_strikethrough > 0,
                };

                if (in_link > 0) {
                    new_ansi_state.fg_colour = 6; // bright blue
                } else if (in_h1 > 0 or in_h2_h3 > 0) {
                    new_ansi_state.fg_colour = 8 | 1; // bright red
                } else if (in_code > 0) {
                    new_ansi_state.fg_colour = 7; // grey
                } else {
                    new_ansi_state.fg_colour = 0; // default
                }

                if (!ansi_state.eq(new_ansi_state)) {
                    ansi_state = new_ansi_state;
                    try output_string.appendSlice(ansi_state.get(&ansi_str));
                }
            }

            // Tag stack

            if (!tags.singleton_tags.has(tag)) {
                if (is_closing_tag) {
                    // Find last occurence of this tag and move stack back to tag before that
                    var i: isize = @intCast(isize, tag_stack.items.len) - 1;
                    while (i >= 0) : (i -= 1) {
                        if (std.ascii.eqlIgnoreCase(tag_stack.items[@intCast(usize, i)], tag)) {
                            tag_stack.items.len = @intCast(usize, i);
                            break;
                        }
                    }
                } else {
                    try tag_stack.append(tag);
                }

                if (!tags.inline_tags.has(tag)) {
                    if (!last_char_was_newline) {
                        try output_string.appendNTimes('\n', 2);
                        last_char_was_whitespace = true;
                        last_char_was_newline = true;
                    }
                }

                // bullet point for lists
                // TODO ordered lists
                if (!is_closing_tag and std.ascii.eqlIgnoreCase(tag, "li")) {
                    if (in_list >= 0) {
                        try output_string.appendNTimes('\t', @intCast(usize, in_list));
                    }
                    try output_string.appendSlice("• ");
                    last_char_was_whitespace = true;
                    last_char_was_newline = true; // Next non-inline element won't start new line
                }
            } else if (std.ascii.eqlIgnoreCase(tag, "br")) {
                try output_string.append('\n');
            }

            // Skip to end of tag (attributes are ignored)

            html = string.skipToCharacterNotInQuotes(html, '>');
            if (html.len > 0) {
                html = html[1..];
            }

            if (tags.no_display_tags.has(tag)) {
                // Skip contents (find closing tag)

                while (html.len > 0) {
                    html = string.skipToCharacterNotInQuotes(html, '<');
                    if (html.len < 2 + tag.len + 1) {
                        html = &[_]u8{};
                        break;
                    }
                    html = html[1..];

                    if (html[0] != '/') {
                        continue;
                    }

                    if (!std.ascii.eqlIgnoreCase(tag, string.getStart(html[1..], string.isASCIIAlphabet, true))) {
                        continue;
                    }

                    html = string.skipToCharacterNotInQuotes(html, '>');

                    if (html.len >= 2) {
                        html = html[1..];
                    }
                    break;
                }
            }
        } else {
            // Output contents of tag

            // Combine whitespace at start

            if (string.isWhitespace(html[0]) and !last_char_was_whitespace) {
                try output_string.append(' ');
                last_char_was_whitespace = true;
                last_char_was_newline = false;
                html = html[1..];
            }

            while (html.len > 0 and html[0] != '<') {
                if (html[0] == '&' and html.len >= 3 and
                    (html[1] == '#' or string.isASCIIAlphabet(html[1])))
                {
                    // Character reference

                    const codepoint_maybe = try parse_char_ref(&html, &output_string);
                    if (codepoint_maybe) |codepoint| {
                        last_char_was_whitespace = codepoint <= 255 and
                            string.isWhitespace(@intCast(u8, codepoint));
                        last_char_was_newline = codepoint == '\n';
                    } else {
                        try output_string.append('&');
                        html = html[1..];
                    }
                } else if (string.isWhitespace(html[0])) {
                    if (!last_char_was_whitespace) {
                        try output_string.append(' ');
                        last_char_was_whitespace = true;
                        last_char_was_newline = false;
                    }
                    html = html[1..];
                } else if (html.len >= 2 and (string.startsWith(html, "¶") or string.startsWith(html, "§"))) {
                    // Skip over pilcrows and section signs
                    html = html[2..];
                } else if (html[0] < 32 or html[0] == 127) {
                    // Skip over control codes
                    html = html[1..];
                } else {
                    last_char_was_whitespace = false;
                    last_char_was_newline = false;
                    try output_string.append(html[0]);
                    html = html[1..];
                }
            }
        }
    }

    // Clear formatting
    if (!ansi_state.eq(.{})) {
        try output_string.appendSlice("\x1b[0m");
    }

    return output_string.items;
}

// If character reference is valid then unicode character is added to output_string
//  and html slice is updated
fn parse_char_ref(html: *[]const u8, output_string: *std.ArrayList(u8)) !?u21 {
    std.debug.assert(html.*.len >= 3 and html.*[0] == '&');

    const old_html_slice = html.*;
    html.* = html.*[1..];

    const codepoint_maybe = get_char_ref_codepoint(html) catch null;

    if (codepoint_maybe) |codepoint| {
        var utf8: [4]u8 = undefined;
        const utf8_bytes = std.unicode.utf8Encode(codepoint, utf8[0..]) catch unreachable;
        try output_string.*.appendSlice(utf8[0..utf8_bytes]);
    } else {
        html.* = old_html_slice;
    }
    return codepoint_maybe;
}

// Returns UTF8 codepoint and skips html slice past character reference
fn get_char_ref_codepoint(html: *[]const u8) !u21 {
    std.debug.assert(html.*.len >= 2);

    if (html.*[0] == '#') {
        // Codepoint

        html.* = html.*[1..];

        if (html.*[0] == 'x' or html.*[0] == 'X') {
            // Hex

            html.* = html.*[1..];
            if (html.*.len < 2) {
                return error.FormatError;
            }

            const s = string.getStart(html.*, string.isHexDigit, true);

            if (s.len == html.*.len or html.*[s.len] != ';') {
                return error.FormatError;
            }

            html.* = html.*[s.len + 1 ..];

            const u = try std.fmt.parseUnsigned(u21, s, 16);

            if (u >= 0x110000) {
                return error.TooLarge;
            }
            if (u < 32) { // ASCII control codes
                return 0xfffd; // replacement character
            }
            return u;
        } else if (string.isDigit(html.*[0])) {
            // Dec
            const s = string.getStart(html.*, string.isDigit, true);

            if (s.len == html.*.len or html.*[s.len] != ';') {
                return error.FormatError;
            }

            html.* = html.*[s.len + 1 ..];

            const u = try std.fmt.parseUnsigned(u21, s, 10);

            if (u >= 0x110000) {
                return error.TooLarge;
            }
            if (u < 32) { // ASCII control codes
                return 0xfffd; // replacement character
            }
            return u;
        }
    } else if (string.isASCIIAlphabet(html.*[0])) {
        // Name

        const s = string.getStart(html.*, string.isASCIIAlphabet, true);

        if (s.len == html.*.len or html.*[s.len] != ';') {
            return error.FormatError;
        }

        html.* = html.*[s.len + 1 ..];

        if (std.ascii.eqlIgnoreCase(s, "lt")) {
            return '<';
        } else if (std.ascii.eqlIgnoreCase(s, "gt")) {
            return '>';
        } else if (std.ascii.eqlIgnoreCase(s, "quot")) {
            return '"';
        } else if (std.ascii.eqlIgnoreCase(s, "amp")) {
            return '&';
        } else if (std.ascii.eqlIgnoreCase(s, "nbsp")) {
            return ' ';
        } else if (std.ascii.eqlIgnoreCase(s, "raquo")) {
            return '»';
        }

        // TODO There are hundreds of other unicode character names which are all valid in HTML.

    }
    return error.FormatError;
}

fn getFilePath(allocator: Allocator) ?[]const u8 {
    var args = std.process.args();
    defer args.deinit();

    // Skip application path
    const skipped = args.skip();
    if (!skipped) {
        return null;
    }

    // Get file path
    const path_maybe = args.next(allocator);
    if (path_maybe) |path| {
        return path catch null;
    } else {
        return null;
    }
}

fn loadHTML(allocator: Allocator, path_maybe: ?[]const u8) ![]const u8 {
    if (path_maybe) |path| {
        return try std.fs.cwd().readFileAlloc(allocator, path, 8 * 1024 * 1024);
    } else {
        // Read file from stdin

        const f = std.io.getStdIn();
        var a = std.ArrayList(u8).init(allocator);
        var offset: usize = 0;
        var size: usize = 0;

        while (true) {
            try a.resize(a.items.len + 64 * 1024);
            const n = try f.read(a.items[offset..]);

            if (n < 64 * 1024) {
                size += n;
                return a.items[0..size];
            } else {
                size += n;
                offset += n;
            }
        }

        return try f.readToEndAlloc(allocator, 8 * 1024 * 1024);
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const path_maybe = getFilePath(allocator);
    defer {
        if (path_maybe) |path| {
            allocator.free(path);
        }
    }

    const html = try loadHTML(allocator, path_maybe);
    defer allocator.free(html);

    const s = try parseHTML(allocator, html, true);
    defer allocator.free(s);

    try std.io.getStdOut().writer().print("{s}\n", .{s});
}

test "" {
    _ = @import("String.zig");
}

test "HTML" {
    const allocator = std.testing.allocator;

    const s = try parseHTML(allocator, "<b>hello <i>123</i></b>", true);
    defer allocator.free(s);

    std.debug.print("s [{s}]\n", .{s});

    try std.testing.expectEqualSlices(u8, s, "\x1b[0;1mhello \x1b[0;1;3m123\x1b[0;1m\x1b[0m");
}
