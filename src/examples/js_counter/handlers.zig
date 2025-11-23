const dom = @import("../../modules/dom.zig");

// Handler functions that will be transpiled to JavaScript
// These use the dom.zig API which maps to DOM calls

pub fn handleClick() void {
    const counter = dom.querySelector("#counter");
    const count_str = dom.getInnerText(counter);
    const count = dom.parseInt(count_str, 10);
    const new_count = count + 1;
    dom.setInnerText(counter, "");
    if (new_count == 10) {
        dom.alert("You've clicked 10 times! Keep going!");
    }
}

pub fn setupListeners() void {
    const button = dom.querySelector("#clickButton");
    dom.addEventListener(button, "click", "handleClick");
}

pub fn initPage() void {
    setupListeners();
}
