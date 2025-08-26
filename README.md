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
_ = ezig.addEzigTemplatesImport(exe_mod, .{ .path = "src/views" });
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
  var stdout_buffer: [4096]u8 = undefined;
  var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
  const stdout = &stdout_writer.interface;

  const Props = struct { name: [:0]const u8 };
  const props: Props = .{ .name = "codebase" };
  ezig_templates.@"index.html"(stdout, props);

  try stdout.flush();
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
  const nested_template_props: NestedTemplateProps = .{ .name = props.name, .description = props.description };
  @"dog_details.html"(writer, nested_template_props);
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

Compose them by including behavior in the type of `props` passed into the layout:

```
const LayoutProps = struct {
  text: [:0]const u8,

  pub fn writeBodyContent(self: *@This(), writer: std.io.AnyWriter) !void {
    const ContentProps = struct { text: [:0]const u8 };
    const content_props: ContentProps = .{ .text = self.text };

    try ezig_templates.@"content.html"(writer, content_props);
  }
}

const layout_props: LayoutProps = .{ .text = "Body text" };

try ezig_templates.@"layout.html"(writer, layout_props);
```

### View helpers

To implement a view helper function which can be called from a template...

First, configure `build.zig` to have the generated templates import your app module:

```
const ezig_templates_mod = ezig.addEzigTemplatesImport(exe_mod, .{ .path = "src/app/views" });
ezig_templates_mod.addImport("view_helpers", exe_mod);
```

Then, add a view helper to your app:

```
// Note: this helper can only be called safely with parameters that have
// already been properly escaped for HTML rendering.
pub fn writeLinkTo(writer: *std.Io.Writer, body: []const u8, url: []const u8) std.Io.Writer.Error!void {
    try writer.print("<a href=\"{s}\">{s}</a>", .{ url, body });
}
```

Then you can consume your view helper from your template:

```
<%
  const view_helpers = @import("view_helpers");
  try view_helpers.writeLinkTo(writer, "https://www.ziglang.org", "Zig Lang");
%>
```

### No-prop templates

To render a template with no props, make sure to include the line `<% _ = props; %>` somewhere in your template.

## Future Work

- UTF-8 support and test coverage. Currently UTF-8 mostly works by accident, but the parsing and escaping code isn't aware of it, so there are likely bugs.
- Support for storing template data in separate files instead of compiling it into the binary, for a smaller binary size.
- More safety for template names. Currently a template's name is just its relative path, with no escaping.
