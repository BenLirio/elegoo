#!/bin/bash

# Load environment variables from the .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Check if sudo is required and available
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "sudo is required but not installed. Please install sudo or run this script as root."
        exit 1
    fi
fi

# Check for necessary environment variables
if [ -z "$BOARD_TYPE" ]; then
    echo "Error: BOARD_TYPE environment variable is not set."
    exit 1
fi

if [ -z "$DEV_PORT" ]; then
    echo "Error: DEV_PORT environment variable is not set."
    exit 1
fi

# Check if any process is using the device
if sudo lsof "$DEV_PORT" > /dev/null; then
    echo "The device $DEV_PORT is currently in use. Exiting."
    exit 1
else
    echo "The device $DEV_PORT is not in use. Continuing."
fi

if [ -z "$SKETCH_PATH" ]; then
    echo "Error: SKETCH_PATH environment variable is not set."
    exit 1
fi

# Set output directory for the compiled files
OUTPUT_DIR="/tmp/arduino_build"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Compile the sketch
echo "Compiling sketch..."
arduino-cli compile --fqbn "$BOARD_TYPE" "$SKETCH_PATH" --output-dir "$OUTPUT_DIR"
if [ $? -ne 0 ]; then
    echo "Error during compilation."
    exit 1
fi

# Find the .hex file in the output directory
HEX_FILE=$(find "$OUTPUT_DIR" -name "*.hex" | head -n 1)
if [ -z "$HEX_FILE" ]; then
    echo "Error: Compiled .hex file not found."
    exit 1
fi

# Upload the compiled sketch
echo "Uploading sketch to $DEV_PORT..."
if [ "$EUID" -ne 0 ]; then
    sudo arduino-cli upload -p "$DEV_PORT" --fqbn "$BOARD_TYPE" --input-file "$HEX_FILE"
else
    arduino-cli upload -p "$DEV_PORT" --fqbn "$BOARD_TYPE" --input-file "$HEX_FILE"
fi

if [ $? -ne 0 ]; then
    echo "Error during upload."
    exit 1
fi

echo "Sketch successfully uploaded to $DEV_PORT."

# Cleanup
rm -rf "$OUTPUT_DIR"

