-- Minimal init for testing
local plenary_dir = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

-- Required for testing
vim.cmd("runtime! plugin/plenary.vim")

-- Set up test environment
require("plenary.busted")
