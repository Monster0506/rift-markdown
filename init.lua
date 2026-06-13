local M = {}

local KIND = "md."
local DEFAULT_FACES = {
  h1 = { bold = true, fg = "cyan" },
  h2 = { bold = true, fg = "blue" },
  h3 = { bold = true, fg = "magenta" },
  h4 = { bold = true, fg = "yellow" },
  h5 = { bold = true, fg = "green" },
  h6 = { bold = true, fg = "white" },
  quote = { italic = true, fg = "grey" },
  bold = { bold = true },
  italic = { italic = true },
  strike = { strike = true },
  code = { fg = "green", bg = "#222222" },
  link = { fg = "blue", underline = true },
  fence = { fg = "grey" },
}

local cfg = {
  conceal = true,
  render_on_open = true,
  rule_fraction = 0.8,
}

local concealed = true

local rendered = {}

local function is_md(ev)
  if ev.filetype == "markdown" then return true end
  local ext = ev.path and ev.path:match("%.([%w]+)$")
  if not ext then return false end
  ext = ext:lower()
  return ext == "md" or ext == "markdown"
end

local function mark(sub, s, e)
  rift.annotations.add { kind = KIND .. sub, range = { s, e } }
end

local function conceal(s, e)
  rift.annotations.add {
    kind = KIND .. "conceal",
    range = { s, e },
    visible = concealed,
    adornment = { placement = "conceal" },
  }
end

local function render_inline(line, lstart)
  local consumed = {}
  local function covered(s)
    for _, r in ipairs(consumed) do
      if s >= r[1] and s < r[2] then return true end
    end
    return false
  end
  local function scan(pat, fn)
    local init = 1
    while true do
      local s, e, a, b = line:find(pat, init)
      if not s then break end
      if not covered(s) then
        fn(s, e, a, b)
        consumed[#consumed + 1] = { s, e }
      end
      init = e + 1
    end
  end

  scan("`(.-)`", function(s, e)
    local ms, me = lstart + s - 1, lstart + e
    mark("code", ms, me)
    conceal(ms, ms + 1)
    conceal(me - 1, me)
  end)

  scan("%[(.-)%]%((.-)%)", function(s, e, txt, url)
    local ms = lstart + s - 1
    local tstart = ms + 1
    local tend = tstart + #txt
    rift.annotations.add {
      kind = KIND .. "link",
      range = { tstart, tend },
      payload = { href = url, tooltip = "link -> " .. url },
      actions = { { verb = "activate", default = true } },
    }
    conceal(ms, tstart)
    conceal(tend, lstart + e)
  end)

  scan("%*%*(.-)%*%*", function(s, e)
    local ms, me = lstart + s - 1, lstart + e
    mark("bold", ms + 2, me - 2)
    conceal(ms, ms + 2)
    conceal(me - 2, me)
  end)

  scan("~~(.-)~~", function(s, e)
    local ms, me = lstart + s - 1, lstart + e
    mark("strike", ms + 2, me - 2)
    conceal(ms, ms + 2)
    conceal(me - 2, me)
  end)

  scan("_(.-)_", function(s, e)
    local ms, me = lstart + s - 1, lstart + e
    mark("italic", ms + 1, me - 1)
    conceal(ms, ms + 1)
    conceal(me - 1, me)
  end)
end

local function render_line(line, lstart, lend, in_fence)
  if line:match("^%s*```") then
    mark("fence", lstart, lend)
    return not in_fence
  end
  if in_fence then
    return in_fence
  end

  local hashes = line:match("^(#+)%s")
  if hashes then
    conceal(lstart, lstart + #line:match("^#+%s+"))
    mark("h" .. math.min(#hashes, 6), lstart, lend)
  elseif line:match("^%s*>%s?") then
    mark("quote", lstart, lend)
  elseif line:match("^%s*[-*_]%s*[-*_]%s*[-*_][-*_%s]*$") then
    local _, cols = rift.get_window_size()
    cols = (cols and cols > 0) and cols or 80
    local bar = math.floor(cols * cfg.rule_fraction)
    local left = math.floor((cols - bar) / 2)
    conceal(lstart, lend)
    rift.annotations.add {
      kind = KIND .. "rule",
      point = lstart,
      adornment = {
        text = string.rep(" ", math.max(0, left - #line)) .. string.rep("-", bar),
        placement = "trailing",
        face = "diag.hint",
      },
    }
    return in_fence
  else
    local indent, marker = line:match("^(%s*)([-*+])%s")
    if marker then
      local box = line:match("^%s*[-*+]%s+%[([ xX])%]%s")
      if box then
        local bpos = lstart + line:find("%[") - 1
        rift.annotations.add {
          kind = "ui.checkbox",
          range = { bpos, bpos + 3 },
          payload = { checked = box ~= " " },
          actions = { { verb = "toggle", default = true } },
        }
      else
        local mpos = lstart + #indent
        rift.annotations.add {
          kind = KIND .. "bullet",
          range = { mpos, mpos + 1 },
          adornment = { text = "-", placement = "overlay", face = "link" },
        }
      end
    end
  end

  render_inline(line, lstart)
  return in_fence
end

local function render()
  rift.annotations.clear(KIND)
  rift.annotations.clear("ui.checkbox")
  local offset = 0
  local in_fence = false
  for _, line in ipairs(rift.get_lines(1, -1)) do
    in_fence = render_line(line, offset, offset + #line, in_fence)
    offset = offset + #line + 1
  end
end

function M.setup(opts)
  opts = opts or {}
  if opts.conceal ~= nil then cfg.conceal = opts.conceal end
  if opts.render_on_open ~= nil then cfg.render_on_open = opts.render_on_open end
  if opts.rule_fraction ~= nil then cfg.rule_fraction = opts.rule_fraction end
  concealed = cfg.conceal

  local faces = {}
  for sub, style in pairs(DEFAULT_FACES) do faces[sub] = style end
  if opts.faces then
    for sub, style in pairs(opts.faces) do faces[sub] = style end
  end
  for sub, style in pairs(faces) do
    rift.annotations.register_kind(KIND .. sub, { style = style })
  end

  rift.annotations.on_action("md.link", "activate", function(ctx)
    if ctx.payload and ctx.payload.href then
      rift.open_file(ctx.payload.href)
    end
  end)

  if cfg.render_on_open then
    rift.on("BufOpen", function(ev)
      if is_md(ev) then
        rendered[rift.current_buf()] = true
        render()
      end
    end)
  end

  rift.on("TextChangedCoarse", function(ev)
    if rendered[ev.buf] and ev.buf == rift.current_buf() then
      render()
    end
  end)

end

return M
