#!/bin/bash

# Exit on any error
set -e

echo "Starting Vivado Synthesis Automation..."

# Run Vivado in batch mode
echo "Running Vivado synthesis..."
/home/hash/Vivado/Vivado/2018.2/bin/vivado -mode batch -source build.tcl

echo "Synthesis script completed."

