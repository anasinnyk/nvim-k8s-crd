local Job = require("plenary.job")
local Path = require("plenary.path")
local Log = require("plenary.log")

local M = {}

-- Configuration
M.config = {
  cache_dir = vim.fn.expand("~/.cache/k8s-schemas/"),
  cache_ttl = 3600 * 24, -- Time to live for cache in seconds (1 day)
  k8s = {
    file_mask = "/*.yaml",
  },
}

function get_current_context()
  return vim.fn.system("kubectl config current-context"):gsub("%s+", "")
end

-- Set user configuration
function M.setup(user_config)
  M.config = vim.tbl_extend("force", M.config, user_config or {})
  local current_context = get_current_context()
  local all_json_path = Path:new(M.config.cache_dir, current_context, "/all.json")

  Log.debug("Current json path: " .. tostring(all_json_path))

  if not all_json_path:exists() then
    M.generate_schemas()
  end

  if M.config.k8s.file_mask ~= nil then
    if vim.lsp.start then -- NeoVIM >= 0.11
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "yaml",
        callback = function(args)
          local clients = vim.lsp.get_active_clients({ bufnr = args.buf })

          for _, client in ipairs(clients) do
            if client.name == "yamlls" then
              local new_settings = vim.deepcopy(client.config.settings or {})
              new_settings.yaml = new_settings.yaml or {}
              new_settings.yaml.schemas = vim.tbl_extend("force", new_settings.yaml.schemas or {}, {
                [tostring(all_json_path)] = M.config.k8s.file_mask,
              })

              local new_config = vim.tbl_extend("force", client.config, {
                settings = new_settings,
              })

              Log.debug("Config yamlls: " .. tostring(client.config))

              client.stop()

              vim.defer_fn(function()
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                  local ft = vim.bo[bufnr].filetype
                  if ft == "yaml" or ft == "json" then
                    local existing = vim.lsp.get_active_clients({ bufnr = bufnr })
                    local already_has_yamlls = vim.iter(existing):any(function(c)
                      return c.name == "yamlls"
                    end)

                    if not already_has_yamlls then
                      vim.lsp.start(vim.tbl_extend("force", new_config, { bufnr = bufnr }))
                    end
                  end
                end
              end, 500)
            end
          end
        end
      })
    else
      local lspconfig = require("lspconfig") -- NeoVIM < O.11
      lspconfig.yamlls.setup(vim.tbl_extend("force", lspconfig.yamlls.document_config.default_config, {
        settings = {
          yaml = {
            schemas = {
              [tostring(all_json_path)] = M.config.k8s.file_mask,
            },
          },
        },
      }))
    end
  end

  vim.api.nvim_create_user_command("K8SSchemasGenerate", function()
    M.generate_schemas()
  end, { nargs = 0 })
end

function M.generate_schemas()
  local current_context = get_current_context()
  local schema_dir = Path:new(M.config.cache_dir, current_context)
  local all_file = schema_dir:joinpath("/all.json")

  Path:new(schema_dir):mkdir({ parents = true })

  local fetch_openapi_job = Job:new({
    command = "kubectl",
    args = { "get", "--raw", "/openapi/v3" },
  })

  local all_types = {}
  local current_job = 0
  local total_jobs = 0

  local function fetch_schema(path, api, callback)
    path = path:gsub("/", "-")
    Job:new({
      command = "kubectl",
      args = { "get", "--raw", api.serverRelativeURL },
      on_exit = function(j, result_val)
        if result_val ~= 0 then
          Log.error("Error fetching OpenAPI: " .. api.serverRelativeURL, j:result())
          callback(false)
          return
        end

        local schema = vim.json.decode(table.concat(j:result(), "\n"))
        if schema.components and schema.components.schemas then
          local updated_schemas = { ["components"] = { ["schemas"] = schema.components.schemas } }

          for k, crd in pairs(schema.components.schemas) do
            if
                crd.type == "object"
                and crd.properties
                and crd.properties.apiVersion
                and crd.properties.kind
                and crd["x-kubernetes-group-version-kind"]
            then
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
              table.insert(all_types, { ["$ref"] = path .. ".json#/components/schemas/" .. k })
            end
            updated_schemas.components.schemas[k] = crd
          end

          local schema_path = schema_dir:joinpath(path .. ".json")
          schema_path:write(vim.json.encode(updated_schemas), "w")
          Log.debug("Generated (" .. current_job .. "/" .. total_jobs .. "): " .. tostring(schema_path))
        end

        callback(true)
      end,
    }):start()
  end

  fetch_openapi_job:after(function()
    local result = fetch_openapi_job:result()
    local schema_list = vim.json.decode(table.concat(result, "\n"))

    local paths = {}
    for path, api in pairs(schema_list.paths) do
      table.insert(paths, { path, api })
    end
    total_jobs = #paths

    local function run_next_schema(i)
      current_job = i

      if i > total_jobs then
        Path:new(all_file):write(vim.json.encode({ ["oneOf"] = all_types }), "w")
        Log.debug("Generated: " .. tostring(all_file))
        return
      end

      local path_api = paths[i]
      fetch_schema(path_api[1], path_api[2], function(res)
        if res then
          run_next_schema(i + 1)
        else
          Log.debug("Retrying schema: " .. path_api[1])
          local timer = vim.loop.new_timer()
          timer:start(
            100,
            0,
            vim.schedule_wrap(function()
              run_next_schema(i)
            end)
          )
        end
      end)
    end

    run_next_schema(1)
  end)

  fetch_openapi_job:start()
end

return M
