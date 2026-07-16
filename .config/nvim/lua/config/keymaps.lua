-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- :CopyRelPath -- 現在のファイルの CWDからの 相対path:line をクリップボードにコピー
vim.api.nvim_create_user_command("CopyRelPath", function()
  -- `:.` を付けると、絶対パスで開かれたバッファでも CWD 基準の相対パスに変換される
  local result = vim.fn.expand("%:.") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", result)
  vim.notify("Copied: " .. result)
end, { desc = "Copy relative path:line to clipboard" })

-- :CopyAbsPath -- 現在のファイルの 絶対path:line をクリップボードにコピー
vim.api.nvim_create_user_command("CopyAbsPath", function()
  local result = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", result)
  vim.notify("Copied: " .. result)
end, { desc = "Copy absolute path:line to clipboard" })
