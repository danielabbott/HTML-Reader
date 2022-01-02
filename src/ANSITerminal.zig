pub const ANSIEscCode = struct {
    fg_colour: u4 = 0,
    bold: bool = false,
    underline: bool = false,
    italics: bool = false,
    strikethrough: bool = false,

    pub fn eq(self: ANSIEscCode, x: ANSIEscCode) bool {
        return self.fg_colour == x.fg_colour and
            self.bold == x.bold and self.underline == x.underline and self.italics == x.italics and self.strikethrough == x.strikethrough;
    }

    pub fn get(self: ANSIEscCode, str: *[15]u8) []u8 {
        str.*[0] = '\x1b';
        str.*[1] = '[';
        str.*[2] = '0'; // reset

        var i: usize = 3;

        if (self.fg_colour != 0) {
            str.*[i] = ';';
            str.*[i + 1] = if (self.fg_colour > 7) '9' else '3';
            str.*[i + 2] = '0' + @intCast(u8, self.fg_colour & 7);
            i += 3;
        }

        if (self.bold) {
            str.*[i] = ';';
            str.*[i + 1] = '1';
            i += 2;
        }

        if (self.underline) {
            str.*[i] = ';';
            str.*[i + 1] = '4';
            i += 2;
        }

        if (self.italics) {
            str.*[i] = ';';
            str.*[i + 1] = '3';
            i += 2;
        }

        if (self.strikethrough) {
            str.*[i] = ';';
            str.*[i + 1] = '9';
            i += 2;
        }

        str.*[i] = 'm';

        return str.*[0 .. i + 1];
    }
};
