// Handler functions that will be transpiled to JavaScript

pub fn handleClick() void {
    const counter = querySelector("#counter");
    const count_str = getInnerText(counter);
    const count = parseInt(count_str, 10);
    const new_count = count + 1;
    setInnerText(counter, "");
    if (new_count == 10) {
        alert("You've clicked 10 times! Keep going!");
    }
}

pub fn setupListeners() void {
    const button = querySelector("#clickButton");
    addEventListener(button, "click", "handleClick");
}

pub fn initPage() void {
    setupListeners();
}

// Stub functions for transpilation (will become JS DOM calls)
fn querySelector(selector: []const u8) u32 {
    _ = selector;
    return 0;
}

fn getInnerText(element: u32) []const u8 {
    _ = element;
    return "";
}

fn setInnerText(element: u32, text: []const u8) void {
    _ = element;
    _ = text;
}

fn addEventListener(element: u32, event: []const u8, handler: []const u8) void {
    _ = element;
    _ = event;
    _ = handler;
}

fn alert(message: []const u8) void {
    _ = message;
}

fn parseInt(str: []const u8, radix: u32) i32 {
    _ = str;
    _ = radix;
    return 0;
}
