# nvim-k8s-crd

`nvim-k8s-crd` is a Neovim plugin designed to synchronize Kubernetes Custom Resource Definitions (CRDs) with your Neovim setup, providing autosuggestions and schema validation for Kubernetes manifests based on the current context.

## Features

- Sync Kubernetes CRDs based on the current Kubernetes context.
- Store CRD schemas locally.
- Provide autosuggestions and schema validation for Kubernetes manifests.
- Commands to sync schemas. 

## Installation

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'anasinnyk/nvim-k8s-crd',
  requires = { 'neovim/nvim-lspconfig' },
  config = function()
    require('k8s-crd').setup({
      cache_dir = "~/.cache/k8s-schemas/",  -- Local directory relative to the current working directory
      k8s = {
        file_mask = "*.yaml",
      },
    })
  end
}

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
use {
  'anasinnyk/nvim-k8s-crd',
  event = { 'BufEnter *.yaml' },
  dependencies = { 'neovim/nvim-lspconfig' },
  config = function()
    require('k8s-crd').setup({
      cache_dir = "~/.cache/k8s-schemas/",  -- Local directory relative to the current working directory
      k8s = {
        file_mask = "*.yaml",
      },
    })
  end
}
```

## Configuration

```lua
require('k8s_crd').setup({
  cache_dir = "./.k8s-schemas/",  -- Local directory relative to the current working directory
  k8s = {
    file_mask = "*.yaml",  -- File mask to match Kubernetes manifests
  },
})
```

## Commands

- `:K8SSchemasGenerate` - Sync CRDs based on the current Kubernetes context.

## License

MIT License
