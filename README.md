# Zig Web App Example

This project demonstrates a basic web application built using Zig, showcasing server-side rendering of HTML with dynamic content and client-side interactivity using JavaScript. It leverages Zig's comptime features for code generation and includes a simple build system.

## Project Structure

-   `build.zig`: The Zig build script that defines how the project is compiled and executed.
-   `src/`: Contains the source code for the project.
    -   `html.zig`: Defines data structures and functions for creating HTML elements and documents.
    -   `dom.zig`: Provides a high-level API for interacting with the browser's DOM using JavaScript.
    -   `js.zig`: Defines data structures for representing JavaScript code as an AST (Abstract Syntax Tree) and generating JavaScript code from it.
    -   `js_reflect.zig`: (WIP) Attempts to reflect Zig functions to JavaScript AST.
    -   `js_gen.zig`: Defines data structures for representing JavaScript code as an AST (Abstract Syntax Tree) and generating JavaScript code from it.
    -   `js_reflect_test.zig`: Tests for the js_reflect.zig functionality.
    -   `js_gen_test.zig`: Tests for the js_gen.zig functionality.
    -   `root.zig`: Contains a simple Zig function and tests.
    -   `main.zig`: The main application logic, including the HTTP server and HTML generation.
    -   `main_test.zig`: Tests for the main.zig functionality.
-   `.gitignore`: Specifies intentionally untracked files that Git should ignore.

## Key Features

-   **Server-Side HTML Rendering:** The application generates HTML on the server using Zig, providing a structured approach to building web pages.
-   **Dynamic Content:** The HTML includes dynamic content that is updated using JavaScript.
-   **JavaScript Generation:** Zig generates JavaScript code at compile time, allowing for type-safe and efficient client-side logic.
-   **DOM Manipulation:** A custom DOM API is provided for interacting with HTML elements using JavaScript.
-   **Event Handling:** The application demonstrates how to attach event listeners to HTML elements and handle user interactions.
-   **Tailwind CSS:** The HTML uses Tailwind CSS for styling.
-   **Zap Web Framework:** The project uses the Zap web framework for the HTTP server.
-   **Unit Testing:**  The project includes unit tests for both Zig and JavaScript code.

## How to Build and Run

1.  **Install Zig:** Make sure you have Zig installed on your system. You can download it from the official Zig website: [https://ziglang.org/download/](https://ziglang.org/download/)
2.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```
3.  **Build the project:**
    ```bash
    zig build
    ```
    This will compile the Zig code and create an executable.
4.  **Run the application:**
    ```bash
    zig build run
    ```
    This will start the HTTP server.
5.  **Open in browser:** Open your web browser and navigate to `http://127.0.0.1:8080`.

## Key Concepts

-   **Comptime:** Zig's comptime feature allows code to be executed during compilation, enabling code generation and other compile-time tasks.
-   **Abstract Syntax Tree (AST):** The project uses ASTs to represent JavaScript code, allowing for programmatic manipulation and generation.
-   **DOM API:** The custom DOM API provides a Zig-friendly way to interact with the browser's DOM.
-   **Zap Web Framework:** Zap is used for handling HTTP requests and responses.

## Code Overview

-   `html.zig`: Defines the `Element` union, which represents different HTML elements, and provides functions for creating these elements. The `HtmlDocument` struct is used to build an entire HTML document from head and body elements.
-   `dom.zig`: Provides functions for interacting with the DOM, such as `querySelector`, `setInnerText`, and `addEventListener`. It also defines the `EventType` enum for specifying event types.
-   `js.zig`: Defines the `Value`, `Statement`, and `Condition` unions to represent JavaScript code. It includes functions for generating JavaScript code from these data structures.
-   `js_reflect.zig`: (WIP) Attempts to reflect Zig functions to JavaScript AST.
-   `js_gen.zig`: Defines the `JsValue`, `JsExpression`, and `JsStatement` unions to represent JavaScript code. It includes functions for generating JavaScript code from these data structures.
-   `root.zig`: Contains a simple `add` function and a unit test for it.
-   `main.zig`: Contains the main application logic, including the `generateHtml` function that builds the HTML document, the `on_request` function that handles HTTP requests, and the `main` function that starts the HTTP server.

## Further Development

-   **Complete `js_reflect.zig`:** Fully implement the function reflection to generate JavaScript code from Zig functions.
-   **Add more DOM API functions:** Expand the DOM API to support more DOM manipulation tasks.
-   **Implement more complex JavaScript logic:** Add more sophisticated client-side logic to the application.
-   **Improve error handling:** Enhance error handling in the application.
-   **Add routing:** Implement a more robust routing system for handling different paths.
-   **Add more tests:** Write more unit tests to ensure the correctness of the code.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.