const std = @import("std");

/// Add two numbers
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Calculate fibonacci number
pub fn fibonacci(n: i32) i32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}
