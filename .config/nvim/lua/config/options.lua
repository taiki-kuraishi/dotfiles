-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- SSH 越しでも + レジスタを端末側クリップボードへ (:h clipboard-osc52)
-- LazyVim は SSH 時に clipboard='' にするが、g:termfeatures.osc52 が立たない端末では
-- provider が選ばれないため明示的に opt-in する
vim.g.clipboard = "osc52"
