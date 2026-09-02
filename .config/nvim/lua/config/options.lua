-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- SSH 越しでも + レジスタを端末側クリップボードへ (:h clipboard-osc52)
-- LazyVim は SSH 時に clipboard='' にするが、g:termfeatures.osc52 が立たない端末では
-- provider が選ばれないため明示的に opt-in する
vim.g.clipboard = "osc52"

-- LazyVim は SSH 時に 'clipboard' を空にして自動同期(unnamedplus)を切るため、
-- yy 等の無名ヤンクが + レジスタに同期されず、上記の osc52 provider が呼ばれない。
-- 明示的に unnamedplus に戻し、OSC52 経由で自動同期させる。
vim.opt.clipboard = "unnamedplus"
