const std = @import("std");

// Tags without closing tag
pub const singleton_tags = std.ComptimeStringMap(void, .{
    .{"doctype"},
    .{"area"},
    .{"base"},
    .{"br"},
    .{"col"},
    .{"command"},
    .{"embed"},
    .{"hr"},
    .{"img"},
    .{"input"},
    .{"keygen"},
    .{"link"},
    .{"meta"},
    .{"param"},
    .{"source"},
    .{"track"},
    .{"wbr"},
});

// The text between these tags is ignored
pub const no_display_tags = std.ComptimeStringMap(void, .{
    .{"script"},
    .{"style"},
    .{"svg"},
    .{"head"},
});

pub const inline_tags = std.ComptimeStringMap(void, .{
    .{"a"},
    .{"abbr"},
    .{"acronym"},
    .{"audio"},
    .{"b"},
    .{"bdi"},
    .{"bdo"},
    .{"big"},
    .{"br"},
    .{"button"},
    .{"canvas"},
    .{"cite"},
    .{"code"},
    .{"data"},
    .{"datalist"},
    .{"del"},
    .{"dfn"},
    .{"em"},
    .{"embed"},
    .{"i"},
    .{"iframe"},
    .{"img"},
    .{"input"},
    .{"ins"},
    .{"kbd"},
    .{"label"},
    .{"map"},
    .{"mark"},
    .{"meter"},
    .{"noscript"},
    .{"object"},
    .{"output"},
    .{"picture"},
    .{"progress"},
    .{"q"},
    .{"ruby"},
    .{"s"},
    .{"samp"},
    .{"script"},
    .{"select"},
    .{"slot"},
    .{"small"},
    .{"span"},
    .{"strong"},
    .{"sub"},
    .{"sup"},
    .{"svg"},
    .{"template"},
    .{"textarea"},
    .{"time"},
    .{"u"},
    .{"tt"},
    .{"var"},
    .{"video"},
    .{"wbr"},

    // Not inline but added here to improve table formatting
    .{"th"},
    .{"td"},
});
