const std = @import("std");
const dom = @import("dom.zig");
const js_reflect = @import("js_reflect.zig");

fn testHandleClick() void {
    const counter = dom.querySelector("#counter");
    const count_str = dom.getInnerText(counter).toString();
    const count = std.fmt.parseInt(i32, count_str, 10) catch 0;
    const new_count = count + 1;

    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{new_count}) catch unreachable);

    if (new_count == 10) {
        _ = dom.alert("You reached 10 clicks!");
    }
}

fn testSetupListeners() void {
    const heading = dom.querySelector("h1");
    _ = dom.addEventListener(heading, dom.EventType.click.toString(), "handleClick");
}

fn testNestedIf() void {
    const x = dom.querySelector("#x");
    const y = dom.querySelector("#y");

    if (std.mem.eql(u8, dom.getInnerText(x).toString(), "1")) {
        _ = dom.setInnerText(y, "one");
        if (std.mem.eql(u8, dom.getInnerText(y).toString(), "one")) {
            _ = dom.alert("nested!");
        }
    }
}

fn testWhileLoop() void {
    const counter = dom.querySelector("#counter");
    var count = std.fmt.parseInt(i32, dom.getInnerText(counter).toString(), 10) catch 0;

    while (count < 10) {
        count += 1;
        _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{count}) catch unreachable);
    }
}

fn testMultipleElements() void {
    const items = [_][]const u8{ "one", "two", "three" };
    const list = dom.querySelector("#list");

    for (items) |item| {
        const li = dom.querySelector("li");
        _ = dom.setInnerText(li, item);
        _ = dom.addEventListener(list, "click", "handleListClick");
    }
}

fn testComplexDom() void {
    const form = dom.querySelector("#myForm");
    const input = dom.querySelector("#myInput");
    const output = dom.querySelector("#output");

    _ = dom.addEventListener(form, "submit", "handleSubmit");
    _ = dom.addEventListener(input, "input", "handleInput");

    if (std.mem.eql(u8, dom.getInnerText(input).toString(), "")) {
        _ = dom.setInnerText(output, "Please enter something");
    } else {
        _ = dom.setInnerText(output, "Input received: " ++ dom.getInnerText(input).toString());
    }
}

fn testErrorHandling() void {
    const result = dom.querySelector("#result");

    if (std.fmt.parseInt(i32, dom.getInnerText(result).toString(), 10)) |value| {
        if (value < 0) {
            _ = dom.setInnerText(result, "Error: negative number");
        } else {
            _ = dom.setInnerText(result, "Valid number");
        }
    } else |_| {
        _ = dom.setInnerText(result, "Error: not a number");
    }
}

test "handleClick function reflection" {
    const js_ast = js_reflect.toJs(testHandleClick, "handleClick");
    const js_code = js_ast.toString();
    const expected =
        \\function handleClick() {
        \\  const counter = document.querySelector("#counter");
        \\  const count = parseInt.call(undefined, counter.innerText, 10);
        \\  const new_count = count + 1;
        \\  counter.innerText = new_count.toString();
        \\  if (new_count === 10) {
        \\    window.alert("You reached 10 clicks!");
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "setupListeners function reflection" {
    const js_ast = js_reflect.toJs(testSetupListeners, "setupListeners");
    const js_code = js_ast.toString();
    const expected =
        \\function setupListeners() {
        \\  const heading = document.querySelector("h1");
        \\  heading.addEventListener("click", handleClick);
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "nested if statement reflection" {
    const js_ast = js_reflect.toJs(testNestedIf, "testNestedIf");
    const js_code = js_ast.toString();
    const expected =
        \\function testNestedIf() {
        \\  const x = document.querySelector("#x");
        \\  const y = document.querySelector("#y");
        \\  if (x.innerText === "1") {
        \\    y.innerText = "one";
        \\    if (y.innerText === "one") {
        \\      window.alert("nested!");
        \\    }
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "while loop reflection" {
    const js_ast = js_reflect.toJs(testWhileLoop, "testWhileLoop");
    const js_code = js_ast.toString();
    const expected =
        \\function testWhileLoop() {
        \\  const counter = document.querySelector("#counter");
        \\  let count = parseInt.call(undefined, counter.innerText, 10);
        \\  while (count < 10) {
        \\    count = count + 1;
        \\    counter.innerText = count.toString();
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "multiple elements reflection" {
    const js_ast = js_reflect.toJs(testMultipleElements, "testMultipleElements");
    const js_code = js_ast.toString();
    const expected =
        \\function testMultipleElements() {
        \\  const items = ["one", "two", "three"];
        \\  const list = document.querySelector("#list");
        \\  for (const item of items) {
        \\    const li = document.querySelector("li");
        \\    li.innerText = item;
        \\    list.addEventListener("click", handleListClick);
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "complex DOM manipulation reflection" {
    const js_ast = js_reflect.toJs(testComplexDom, "testComplexDom");
    const js_code = js_ast.toString();
    const expected =
        \\function testComplexDom() {
        \\  const form = document.querySelector("#myForm");
        \\  const input = document.querySelector("#myInput");
        \\  const output = document.querySelector("#output");
        \\  form.addEventListener("submit", handleSubmit);
        \\  input.addEventListener("input", handleInput);
        \\  if (input.innerText === "") {
        \\    output.innerText = "Please enter something";
        \\  } else {
        \\    output.innerText = "Input received: " + input.innerText;
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}

test "error handling reflection" {
    const js_ast = js_reflect.toJs(testErrorHandling, "testErrorHandling");
    const js_code = js_ast.toString();
    const expected =
        \\function testErrorHandling() {
        \\  const result = document.querySelector("#result");
        \\  try {
        \\    const value = parseInt.call(undefined, result.innerText, 10);
        \\    if (value < 0) {
        \\      result.innerText = "Error: negative number";
        \\    } else {
        \\      result.innerText = "Valid number";
        \\    }
        \\  } catch (error) {
        \\    result.innerText = "Error: not a number";
        \\  }
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, js_code);
}
