local Job = require('plenary.job')
local Path = require('plenary.path')
local Log = require('plenary.log')
local lspconfig = require('lspconfig')

local M = {}

-- Configuration
M.config = {
  cache_dir = vim.fn.expand("~/.cache/k8s-schemas/"),
  cache_ttl = 3600 * 24, -- Time to live for cache in seconds (1 day)
  k8s = {
    file_mask = "/*.yaml",
  }
}

function get_current_context()
  return vim.fn.system("kubectl config current-context"):gsub("%s+", "")
end

-- Set user configuration
function M.setup(user_config)
  M.config = vim.tbl_extend('force', M.config, user_config or {})
  local current_context = get_current_context()
  local all_json_path = M.config.cache_dir .. current_context .. "/all.json"

  if not Path:new(all_json_path):exists() then
    M.generate_schemas()
  end

  lspconfig.yamlls.setup(vim.tbl_extend('force', lspconfig.yamlls.document_config.default_config, {
    settings = {
      yaml = {
        schemas = {
          [all_json_path] = M.config.k8s.file_mask,
        },
      },
    },
  }))

  vim.api.nvim_create_user_command('K8SSchemasGenerate', function() M.generate_schemas() end, { nargs = 0 })
end

function M.generate_schemas(version)
  local current_context = get_current_context()
  local schema_dir = M.config.cache_dir .. current_context
  local all_file = schema_dir .. '/all.json'

  Path:new(schema_dir):mkdir({ parents = true })

  Job:new({
    command = "kubectl",
    args = { "get", "--raw", "/openapi/v3" },
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        Log.error("Error fetching OpenAPI: /openapi/v3")
        return
      end

      local schema_list = vim.json.decode(table.concat(j:result(), '\n'))
      local all_types = {}
      local completed_jobs = 0
      local total_jobs = 0

      for path, api in pairs(schema_list.paths) do
        path = path:gsub("/", "-")
        total_jobs = total_jobs + 1
        Job:new({
          command = "kubectl",
          args = { "get", "--raw", api.serverRelativeURL },
          on_exit = function(j, result)
            if result ~= 0 then
              Log.error("Error fetching OpenAPI: " .. api.serverRelativeURL, j:result())
              completed_jobs = completed_jobs + 1
              return
            end

            local schema = vim.json.decode(table.concat(j:result(), '\n'))
            if schema.components and schema.components.schemas then
              local updated_schemas = { ['components'] = { ['schemas'] = schema.components.schemas } }
              for k, crd in pairs(schema.components.schemas) do
                if crd.type == "object" and crd.properties and crd.properties.apiVersion and crd.properties.kind and crd["x-kubernetes-group-version-kind"] then
                  local kind_enum = {}
                  local api_version_enum = {}
                  for _, gvk in ipairs(crd["x-kubernetes-group-version-kind"]) do
                    table.insert(kind_enum, gvk.kind)
                    if gvk.group == "" then
                      table.insert(api_version_enum, gvk.version)
                    else
                      table.insert(api_version_enum, gvk.group .. "/" .. gvk.version)
                    end
                  end
                  crd.properties.kind.enum = kind_enum
                  crd.properties.apiVersion.enum = api_version_enum
                  table.insert(all_types, { ['$ref'] = path .. '.json#/components/schemas/' .. k })
                end
                updated_schemas.components.schemas[k] = crd
              end

              Path:new(schema_dir .. "/" .. path .. '.json'):write(
                vim.json.encode(updated_schemas),
                'w')
              Log.info("Generated: " .. schema_dir .. "/" .. path .. '.json')
            end

            completed_jobs = completed_jobs + 1
            Log.info("Completed: " .. completed_jobs .. "/" .. total_jobs)
            if completed_jobs == total_jobs then
              Path:new(all_file):write(vim.json.encode({ ["oneOf"] = all_types }), 'w')
              Log.info("Generated: " .. all_file)
            end
          end,
        }):start()
      end
    end
  }):start()
end

return M

