# Bug Fixes Summary

## Issues Fixed

### 1. Incorrect `pcall` Usage (Lines 127 & 163)
**Problem:** `pcall` returns two values `(success, result)` but code only captured one
```lua
local schema_list = pcall(vim.json.decode, table.concat(result, "\n"))
```
This captured only the boolean success value, causing `attempt to index local 'schema_list' (a boolean value)`

**Fix:**
```lua
local ok, schema_list = pcall(vim.json.decode, table.concat(result, "\n"))
if not ok or not schema_list or not schema_list.paths then
  Log.error("Failed to parse OpenAPI schema list")
  return
end
```

### 2. M.config Initialization Error
**Problem:** `vim.fn.expand()` called at module load time returned nil
```lua
M.config = {
  cache_dir = vim.fn.expand("~/.cache/k8s-schemas/"),  -- nil at module load
  ...
}
```

**Fix:** Defer expansion to setup() and use default_config pattern
```lua
local default_config = {
  cache_dir = "~/.cache/k8s-schemas/",  -- unexpanded
  ...
}

function M.setup(user_config)
  M.config = vim.tbl_extend("force", vim.deepcopy(default_config), user_config or {})
  M.config.cache_dir = vim.fn.expand(M.config.cache_dir)  -- expand in setup
end
```

### 3. Nested LSP Config Table Errors
**Problem:** Using `tbl_extend` on potentially nil nested tables
```lua
vim.lsp.config.yamlls.settings.yaml.schemas = vim.tbl_extend(
  "force",
  vim.lsp.config.yamlls.settings.yaml.schemas,  -- could be nil
  { ... }
)
```

**Fix:** Use direct assignment with safe navigation
```lua
local yamlls_config = vim.lsp.config.yamlls
yamlls_config.settings = yamlls_config.settings or {}
yamlls_config.settings.yaml = yamlls_config.settings.yaml or {}
yamlls_config.settings.yaml.schemas = yamlls_config.settings.yaml.schemas or {}
yamlls_config.settings.yaml.schemas[tostring(all_json_path)] = M.config.k8s.file_mask
```

## Tests Added

1. **Unit tests** (`tests/init_spec.lua`) - Config handling tests
2. **pcall verification** (`tests/verify_pcall_fix.lua`) - Validates fix works
3. **Plugin setup tests** (`test_plugin_setup.lua`) - Integration testing
4. **Test runner** (`run_tests.sh`) - Automated test execution

## Verification

All tests pass:
- ✅ pcall correctly captures both return values
- ✅ Config initialization works with nil user_config  
- ✅ Setup merges user config with defaults correctly
- ✅ LSP config updates without tbl_extend errors
- ✅ Plugin loads and configures successfully with YAML files

## PR Status

- Repository: https://github.com/anasinnyk/nvim-k8s-crd
- PR #7: https://github.com/anasinnyk/nvim-k8s-crd/pull/7
- Status: Draft (tests added, fixes verified)
- Branch: mrlunchbox777/nvim-k8s-crd:fix-pcall-and-config-nil
