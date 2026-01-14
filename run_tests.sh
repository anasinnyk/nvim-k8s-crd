#!/bin/bash
set -e

echo "Running nvim-k8s-crd tests..."

# Run tests using plenary
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

echo "Tests completed!"
