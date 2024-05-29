vim.api.nvim_create_user_command('K8SSchemasGenerate', function() require('k8s-crd').generate_schemas() end, {})
