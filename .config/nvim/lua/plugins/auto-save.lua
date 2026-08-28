return {
  "okuuva/auto-save.nvim",
  version = "^1.0.0",
  cmd = "ASToggle",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    enabled = true,
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost" },
      defer_save = { "InsertLeave", "TextChanged" },
      cancel_deferred_save = { "InsertEnter" },
    },
    condition = function(buf)
      if vim.bo[buf].buftype ~= "" then
        return false
      end
      if not vim.bo[buf].modifiable then
        return false
      end
      return true
    end,
    write_all_buffers = false,
    debounce_delay = 1000,
    debug = false,
  },
}
