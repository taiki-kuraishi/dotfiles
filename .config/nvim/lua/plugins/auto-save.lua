-- 自動保存プラグイン (okuuva/auto-save.nvim — メンテされているフォーク版)
return {
  "okuuva/auto-save.nvim",
  version = "^1.0.0",
  cmd = "ASToggle", -- :ASToggle で自動保存の ON/OFF を切り替え
  event = { "InsertLeave", "TextChanged" },
  opts = {
    enabled = true,
    trigger_events = {
      -- バッファを離れる/フォーカスを失ったら即保存
      immediate_save = { "BufLeave", "FocusLost" },
      -- インサートを抜ける/テキスト変更後は debounce_delay 後に保存
      defer_save = { "InsertLeave", "TextChanged" },
      -- 保存の予約中に入力を再開したらキャンセル
      cancel_deferred_save = { "InsertEnter" },
    },
    -- 保存対象を絞る条件（実ファイルを持つ普通のバッファのみ保存）
    condition = function(buf)
      if vim.bo[buf].buftype ~= "" then
        return false -- terminal など特殊バッファは除外
      end
      if not vim.bo[buf].modifiable then
        return false
      end
      return true
    end,
    write_all_buffers = false, -- 現在のバッファのみ保存
    debounce_delay = 1000, -- 変更が止まってから 1 秒後に保存
    debug = false,
  },
}
