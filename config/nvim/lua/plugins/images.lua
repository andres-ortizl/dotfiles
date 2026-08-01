return {
  {
    "3rd/image.nvim",
    cond = function()
      return vim.fn.executable("luarocks") == 1 and vim.fn.executable("magick") == 1
    end,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = 50,
      max_width_window_percentage = 80,
      window_overlap_clear_enabled = true,
      editor_only_render_when_focused = false,
    },
  },
}
