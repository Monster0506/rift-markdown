# rift-markdown

Live markdown rendering for [rift](https://github.com/Monster0506/rift/), via
annotations. Decorates a markdown buffer in place and conceals the syntax
markers without ever touching the buffer text.

riftpm loads it lazily when a markdown buffer opens (by file extension `ext` or
by filetype `ft`, whichever fires first) and re-fires that open into the plugin
so the first buffer renders immediately. The plugin keeps a filtered `BufOpen`
handler, so every later markdown buffer renders on open too.

## Features

- Headings (`#`..`######`) with per-level faces, the `#` prefix concealed.
- Bold (`**`), italic (`_`), strikethrough (`~~`), inline code (`` ` ``) with
  the surrounding markers concealed and revealed on the cursor's line.
- Links `[text](path)`: styled, the syntax concealed, and activatable to open
  the linked file. Only file paths are opened; web URLs do nothing.
- Block quotes, list bullets, task checkboxes (`- [ ]` / `- [x]`, toggle to
  flip in place), and horizontal rules drawn as a centered bar.
- Fenced code blocks left to tree-sitter (including injected languages).

## Requirements

- A rift build with the Lua plugin host and the annotations API.
- [riftpm](https://github.com/Monster0506/riftpm), which distributes and loads
  this plugin.

## Installation

rift-markdown installs through riftpm. First install riftpm itself from
[Monster0506/riftpm](https://github.com/Monster0506/riftpm) (follow its README),
then add rift-markdown to your `plugins.lua` spec:

```lua
{
    "Monster0506/rift-markdown",
    ext  = { "md", "markdown" },
    ft   = "markdown",
    opts = {
        -- conceal        = true,   default: markers start hidden
        -- render_on_open = true,   default: render the buffer when the plugin loads
        -- rule_fraction  = 0.8,    horizontal-rule bar width, fraction of window
        -- faces = {                override per-kind styling (merged over defaults)
        --     h1   = { bold = true, fg = "cyan" },
        --     link = { fg = "blue", underline = true },
        -- },
    },
},
```

Run `:PluginSync` to clone it. riftpm installs git plugins under
`%LOCALAPPDATA%\rift\plugins\` (Windows) or `~/.local/share/rift/plugins/`
(Linux/Mac).

## Options

| Option           | Default                | Description                                             |
| ---------------- | ---------------------- | ------------------------------------------------------- |
| `conceal`        | `true`                 | Whether syntax markers start hidden.                    |
| `render_on_open` | `true`                 | Render the current buffer when the plugin loads.        |
| `rule_fraction`  | `0.8`                  | Horizontal-rule bar width as a fraction of the window.  |
| `faces`          | built-in               | Per-kind style overrides, merged over the defaults.     |

Face keys: `h1`..`h6`, `quote`, `bold`, `italic`, `strike`, `code`, `link`,
`fence`, `rule`. Each value is a style table (`bold`, `italic`, `underline`,
`strike`, `fg`, `bg`).