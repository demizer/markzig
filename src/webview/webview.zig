const std = @import("std");

pub usingnamespace @cImport({
    @cDefine("WEBVIEW_HEADER", ""); // tells webview.h to be header only
    @cInclude("webview.h");
});
