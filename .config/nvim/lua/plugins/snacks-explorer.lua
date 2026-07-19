-- Snacks Explorer で dotfile (隠しファイル) をデフォルトで表示する
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
        },
      },
    },
  },
}
