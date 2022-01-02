const std = @import("std");
const testing = std.testing;

pub fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0b' or c == '\x0c';
}

pub fn isNewline(c: u8) bool {
    return c == '\n' or c == '\r';
}

pub fn isWhitespaceNonNewline(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\x0b' or c == '\x0c';
}

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn isFloatDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or c == '-' or c == '.';
}

pub fn isHexDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
}

pub fn isASCIIAlphabet(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

pub fn count(s: []const u8, filter: fn (u8) bool, match: bool) usize {
    var i: usize = 0;
    while (i < s.len and filter(s[i]) == match) : (i += 1) {}
    return i;
}

pub fn skip(s: []const u8, filter: fn (u8) bool, match: bool) []const u8 {
    const i = count(s, filter, match);
    if (i == s.len) {
        return &[0]u8{};
    }
    return s[i..];
}

pub fn getStart(s: []const u8, filter: fn (u8) bool, match: bool) []const u8 {
    const i = count(s, filter, match);
    return s[0..i];
}

pub fn nextToken(s: *[]const u8) ?[]const u8 {
    s.* = skip(s.*, isWhitespace, true);
    if (s.*.len == 0) {
        return null;
    }
    const t = getStart(s.*, isWhitespace, false);
    std.debug.assert(t.len > 0);

    if (t.len == s.len) {
        s.* = [_]u8{};
    } else {
        s.* = s[t.len..];
    }
    return t;
}

pub fn trimEnd(s: []const u8) []const u8 {
    if (s.len == 0) {
        return s;
    }

    if (s.len == 1 and isWhitespace(s[0])) {
        return &[0]u8{};
    }

    var i: usize = s.len - 1;
    while (i > 0 and isWhitespace(s[i])) : (i -= 1) {}
    return s[0 .. i + 1];
}

// e.g. ("abc\"d\"def", d) returns "def"
// Can parse
pub fn skipToCharacterNotInQuotes(s: []const u8, c: u8) []const u8 {
    std.debug.assert(c != '\\' and c != '"');

    var in_quotes = false;

    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (in_quotes and s[i] == '\\') {
            i += 1;
        } else if (s[i] == '"') {
            in_quotes = !in_quotes;
        } else if (s[i] == c and !in_quotes) {
            return s[i..];
        }
    }

    return &[_]u8{};
}

// Simple algorithm O(NM)
pub fn find(s: []const u8, x: []const u8) []const u8 {
    if (s.len >= x.len) {
        var i: usize = 0;
        while (i <= s.len - x.len) : (i += 1) {
            if (std.mem.eql(u8, s[i .. i + x.len], x)) {
                return s[i..];
            }
        }
    }

    return &[_]u8{};
}

pub fn findAndSkip(s: []const u8, x: []const u8) []const u8 {
    var s2 = find(s, x);
    if (s2.len > 0) {
        return s2[x.len..];
    }
    return s2;
}

pub fn startsWith(s: []const u8, prefix: []const u8) bool {
    return s.len >= prefix.len and std.mem.eql(u8, s[0..prefix.len], prefix);
}

test "count/skip/get" {
    {
        var s: []const u8 = "  \nabc ";
        try testing.expectEqual(count(s, isWhitespace, true), 3);
        s = skip(s, isWhitespace, true);
        try testing.expectEqualSlices(u8, s, "abc ");
    }

    {
        var s: []const u8 = "\n\n :)";
        try testing.expectEqual(count(s, isNewline, true), 2);
        s = skip(s, isNewline, true);
        try testing.expectEqualSlices(u8, s, " :)");
    }

    {
        var s: []const u8 = "\n\n :)";
        s = getStart(s, isNewline, true);
        try testing.expectEqualSlices(u8, s, "\n\n");
    }

    {
        var s: []const u8 = "123  456";
        try testing.expectEqual(count(s, isWhitespace, false), 3);
        s = skip(s, isWhitespace, false);
        try testing.expectEqual(count(s, isWhitespace, true), 2);
        s = skip(s, isWhitespace, true);
        try testing.expectEqualSlices(u8, s, "456");

        try testing.expectEqualSlices(u8, trimEnd("123  "), "123");
        try testing.expectEqualSlices(u8, trimEnd("  123  "), "  123");
        try testing.expectEqualSlices(u8, trimEnd("abc"), "abc");
        try testing.expectEqualSlices(u8, trimEnd("\tabc\n\n\t "), "\tabc");
    }

    try testing.expectEqualSlices(u8, skipToCharacterNotInQuotes("123  \"a\\\"bc\" 4bd", 'b'), "bd");
    try testing.expectEqualSlices(u8, skipToCharacterNotInQuotes("\"\\\\\"1", '1'), "1");
    try testing.expectEqualSlices(u8, find("abdecdefghi", "def"), "defghi");

    try testing.expect(startsWith("abcdef", "ab"));
    try testing.expect(!startsWith("abcdef", "abd"));
    try testing.expect(!startsWith("abcdef", "abcdefg"));
}
