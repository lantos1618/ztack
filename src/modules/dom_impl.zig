// Real DOM implementation that can be transpiled to JavaScript
// This is actual Zig code that the transpiler will convert to JS

pub const Element = opaque {};

/// querySelector(selector) -> element
/// Transpiles to: const result = document.querySelector(selector);
pub fn querySelector(selector: []const u8) Element {
    _ = selector;
    return undefined;
}

/// getElementById(id) -> element
/// Transpiles to: const result = document.getElementById(id);
pub fn getElementById(id: []const u8) Element {
    _ = id;
    return undefined;
}

/// getInnerText(element) -> text
/// Transpiles to: const result = element.innerText;
pub fn getInnerText(element: Element) []const u8 {
    _ = element;
    return "";
}

/// setInnerText(element, text) -> void
/// Transpiles to: element.innerText = text;
pub fn setInnerText(element: Element, text: []const u8) void {
    _ = element;
    _ = text;
}

/// addEventListener(element, event, handler) -> void
/// Transpiles to: element.addEventListener(event, handler);
pub fn addEventListener(element: Element, event: []const u8, handler: []const u8) void {
    _ = element;
    _ = event;
    _ = handler;
}

/// alert(message) -> void
/// Transpiles to: window.alert(message);
pub fn alert(message: []const u8) void {
    _ = message;
}

pub const EventType = enum {
    click,
    DOMContentLoaded,
    submit,
    input,
    change,
};
