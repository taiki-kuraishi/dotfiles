-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.api.nvim_create_user_command("CopyRelPath", function()
  local result = vim.fn.expand("%:.") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", result)
  vim.notify("Copied: " .. result)
end, { desc = "Copy relative path:line to clipboard" })

vim.api.nvim_create_user_command("CopyAbsPath", function()
  local result = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", result)
  vim.notify("Copied: " .. result)
end, { desc = "Copy absolute path:line to clipboard" })

vim.cmd([[
  anoremenu 1.100 PopUp.Copy\ Relative\ Path  <Cmd>CopyRelPath<CR>
  anoremenu 1.110 PopUp.Copy\ Absolute\ Path  <Cmd>CopyAbsPath<CR>
  anoremenu 1.120 PopUp.-copypath-            <Nop>
]])
