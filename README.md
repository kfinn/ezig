# ezig

Simple compiled Zig templates, inspired by [erb](https://github.com/ruby/erb).

## Usage

Add this as a dependency:

```
zig fetch --save git+https://github.com/kfinn/ezig
```

Update your `build.zig` to generate and import templates into your codebase:

```
const ezig = @import("ezig");
ezig.addEzigTemplatesImport(exe_mod, .{ .path = "src/views" });
```

Implement a view, e.g. `src/views/index.html.ezig`:

```
<div>All your <%= props.name %> are belong to us.</div>
```

Within your code, render a template:

```
const std = @import("std");
const ezig_templates = @import("ezig_templates");

pub fn main() !void {
  const stdout_file = std.io.getStdOut().writer();
  var bw = std.io.bufferedWriter(stdout_file);

  const Props = struct { name: [:0]const u8 };
  const props = Props{ .name = "codebase" };
  ezig_templates.@"index.html"(Props, bw.writer().any(), props);

  try bw.flush();
}
```

## Examples

Find test cases covering several examples in [examples/tests.zig](./examples/tests.zig).

## Features

- Capture and immediately render a string-valued expression using the syntax `<%= expression %>`. This is useful for rendering a string prop.
- Execute a code snippet without rendering it immediately using the syntax `<% snippet %>`. This is useful for formatting, control flow, and rendering a nested template.
- When rendering, the following identifiers are always defined:
  - `std`: the standard library.
  - `writer`: the `std.io.AnyWriter` instance where this template is being rendered.
  - `props`: the props provided by the caller.
  - `Props`: the `type` of `props` provided by the caller.

### Rendering a string prop

`<%= props.name %>`

### Rendering a non-string prop

`<% writer.print("{d}", .{ props.float_value }); %>`

### Iteration

```
<% for (props.dogs) |dog| { %>
  <tr>
    <td><%= dog.name %></td>
    <td><%= dog.description %></td>
  </tr>
<% } %>
```

### Nested templates

Given a template file named `dog_details.html.ezig`...

```
<%
  const NestedTemplateProps = struct { name: [:0]const u8, description: [:0]const u8 };
  const nestedTemplateProps = NestedTemplateProps{ .name = props.name, .description = props.description };
  @"dog_details.html"(NestedTemplateProps, writer, nestedTemplateProps);
%>
```

### Layouts

With a layout template `layout.html.ezig`:

```
<html>
  <body>
    <% try props.writeBodyContent(writer) %>
  </body>
</html>
```

And a content template `content.html.ezig`:

```
<div><%= props.text %></div>
```

Compose them by including behavior in the `Props` type passed into the layout:

```
const LayoutProps = struct {
  text: [:0]const u8,

  pub fn writeBodyContent(self: *@This(), writer: std.io.AnyWriter) !void {
    const ContentProps = struct { text: [:0]const u8 };
    const contentProps = ContentProps{ .text = self.text };

    try ezig_templates.@"content.html"(ContentProps, writer, contentProps);
  }
}

const layoutProps = LayoutProps{ .text = "Body text" };

try ezig_templates.@"layout.html"(LayoutProps, writer, layoutProps);
```

### No-prop templates

To render a template with no props, make sure to include the line `<% _ = props; %>` somewhere in your template.


## Future Work

- UTF-8 support and test coverage. Currently UTF-8 mostly works by accident, but the parsing and escaping code isn't aware of it, so there are likely bugs.
- Support for storing template data in separate files instead of compiling it into the binary, for a smaller binary size.
- More safety for template names. Currently a template's name is just its relative path, with no escaping.
