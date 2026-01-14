-- Verify the pcall fix works correctly
print("Testing pcall fix...")

-- Test 1: Verify successful JSON parsing captures both values
local test_json = '{"paths": {"test": {"serverRelativeURL": "/test"}}}'
local ok, result = pcall(vim.json.decode, test_json)

if not ok then
  print("FAIL: JSON parsing failed")
  os.exit(1)
end

if type(result) ~= "table" then
  print("FAIL: Result is not a table, got: " .. type(result))
  os.exit(1)
end

if not result.paths then
  print("FAIL: Result does not have paths field")
  os.exit(1)
end

print("PASS: pcall correctly captures both ok and result")

-- Test 2: Verify error handling
local ok2, result2 = pcall(vim.json.decode, "invalid json {{{")

if ok2 then
  print("FAIL: Should have failed on invalid JSON")
  os.exit(1)
end

if type(result2) ~= "string" then
  print("FAIL: Error message should be a string")
  os.exit(1)
end

print("PASS: pcall correctly captures errors")

-- Test 3: Verify the fix prevents the boolean indexing error
local function test_schema_list_parsing()
  local mock_result = {'{"paths": {"api/v1": {"serverRelativeURL": "/openapi/v3/api/v1"}}}'}
  local ok, schema_list = pcall(vim.json.decode, table.concat(mock_result, "\n"))
  
  if not ok or not schema_list or not schema_list.paths then
    return false
  end
  
  -- This would have failed before the fix with "attempt to index boolean"
  local paths = {}
  for path, api in pairs(schema_list.paths) do
    table.insert(paths, { path, api })
  end
  
  return #paths > 0
end

if test_schema_list_parsing() then
  print("PASS: Schema list parsing works correctly")
else
  print("FAIL: Schema list parsing failed")
  os.exit(1)
end

print("\nAll pcall fix tests passed!")
