-- Add plenary to runtime path
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.opt.rtp:append(".")

-- Test the plugin setup
local ok, plugin = pcall(require, "nvim-k8s-crd")

if not ok then
  print("FAIL: Could not load plugin: " .. tostring(plugin))
  os.exit(1)
end

print("SUCCESS: Plugin loaded")

-- Test setup with config
local setup_ok, err = pcall(function()
  plugin.setup({
    cache_dir = "/tmp/test-k8s-schemas/",
    k8s = {
      file_mask = "*.yaml",
    },
  })
end)

if not setup_ok then
  print("FAIL: Setup failed: " .. tostring(err))
  os.exit(1)
end

print("SUCCESS: Plugin setup completed")
print("Cache dir: " .. plugin.config.cache_dir)
print("File mask: " .. plugin.config.k8s.file_mask)

-- Test setup with nil (should not error)
local nil_ok, nil_err = pcall(function()
  plugin.setup(nil)
end)

if not nil_ok then
  print("FAIL: Setup with nil failed: " .. tostring(nil_err))
  os.exit(1)
end

print("SUCCESS: Setup with nil handled correctly")

print("\nAll plugin tests passed!")
