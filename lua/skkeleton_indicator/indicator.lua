local api = require'skkeleton_indicator.util'.api
local fn = require'skkeleton_indicator.util'.fn
local Autocmd = require'skkeleton_indicator.autocmd'
local Modes = require'skkeleton_indicator.modes'

local M = {
  funcs = {},
  timer = nil,
  winid = 0,
}

function M.new(opts)
  local ns = api.create_namespace(opts.moduleName)
  local modes = Modes.new{
    ns = ns,
    module_name = opts.moduleName,
    eiji_hl_name = opts.eijiHlName,
    hira_hl_name = opts.hiraHlName,
    kata_hl_name = opts.kataHlName,
    hankata_hl_name = opts.hankataHlName,
    eiji_text = opts.eijiText,
    hira_text = opts.hiraText,
    kata_text = opts.kataText,
    hankata_text = opts.hankataText,
  }
  local self = setmetatable({
    ns = ns,
    modes = modes,
    fade_out_ms = opts.fadeOutMs,
    ignore_ft = opts.ignoreFt,
    buf_filter = opts.bufFilter,
  }, {__index = M})
  Autocmd.new(opts.moduleName):add{
    {'InsertEnter', '*', self:method'open'},
    {'InsertLeave', '*', self:method'close'},
    {'CursorMovedI', '*', self:method'move'},
    {'User', 'skkeleton-mode-changed', self:method'update'},
    {'User', 'skkeleton-disable-post', self:method'update'},
    {'User', 'skkeleton-enable-post', self:method'update'},
  }
end

function M:is_disabled()
  local buf = api.get_current_buf()
  local current_ft = api.buf_get_option(buf, 'filetype')
  for _, ft in ipairs(self.ignore_ft) do
    if current_ft == ft then return true end
  end
  return not self.buf_filter(buf)
end

function M:method(name) return function() self[name](self) end end

function M:set_text(buf)
  local mode = self.modes:detect()
  api.buf_set_lines(buf, 0, 0, false, {mode.text})
  api.buf_clear_namespace(buf, self.ns, 0, -1)
  print(mode.hl_name)
  api.buf_add_highlight(buf, self.ns, mode.hl_name, 0, 0, -1)
  if self.timer then fn.timer_stop(self.timer) end
  self.timer = fn.timer_start(self.fade_out_ms, self:method'close')
end

function M:open()
  if self.timer or self:is_disabled() then return end
  local buf = api.create_buf(false, true)
  self:set_text(buf)
  self.winid = api.open_win(buf, false, {
    style = 'minimal',
    relative = 'cursor',
    row = 1,
    col = 1,
    height = 1,
    width = 4,
    focusable = false,
    noautocmd = true,
  })
end

function M:update()
  local function update()
    -- update() will be called in InsertLeave because skkeleton invokes the
    -- skkeleton-mode-changed event. So here it should checks mode() to confirm
    -- here is the Insert mode.
    if not self.modes:is_insert() then return end

    if self.timer then
      local buf = api.win_get_buf(self.winid)
      self:set_text(buf)
    else
      self:open()
    end
  end
  if vim.in_fast_event() then
    update()
  else
    vim.schedule(update)
  end
end

function M:move()
  if not self.timer then return end
  api.win_set_config(self.winid, {
    relative = 'cursor',
    row = 1,
    col = 1,
  })
end

function M:close()
  if not self.timer then return end
  fn.timer_stop(self.timer)
  self.timer = nil

  if self.winid == 0 then return end
  local buf = api.win_get_buf(self.winid)
  api.win_close(self.winid, false)
  api.buf_clear_namespace(buf, self.ns, 0, -1)
  api.buf_delete(buf, {force = true})
  self.winid = 0
end

return M
