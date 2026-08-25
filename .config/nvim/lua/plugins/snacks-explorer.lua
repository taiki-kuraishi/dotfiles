-- Snacks Explorer で隠しファイル・gitignore/exclude対象ファイルも常に表示する
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
        },
      },
    },
  },
}
