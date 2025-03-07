#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: json-bito-translate.sh <input_file.json> <target_locale>"
    echo "Example: json-bito-translate.sh en.json de"
    exit 1
}

# Check if both parameters are provided
if [ $# -ne 2 ]; then
    echo "Error: Two parameters are required."
    show_usage
fi

# Assign parameters to variables
input_file=$1
target_locale=$2

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

# Validate JSON format
if ! jq empty "$input_file" 2>/dev/null; then
    echo "Error: Invalid JSON format in '$input_file'."
    exit 1
fi

# Create output filename based on the target locale
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename_without_ext="${filename%.*}"
output_file="${target_locale}.${extension}"
temp_output_file=$(mktemp)

# Create a temporary prompt file for translation
prompt_file=$(mktemp)
echo "Translate the following JSON content from the source language to ${target_locale}. Maintain the same JSON structure and only translate the values, not the keys. Return ONLY the translated JSON without any additional text or explanation." > "$prompt_file"

# Translate the JSON using bito-cli
echo "Translating $input_file to $target_locale..."
if ! cat "$input_file" | bito -p "$prompt_file" > "$temp_output_file"; then
    echo "Error: Translation failed. Check if bito-cli is properly installed and configured."
    rm "$prompt_file" "$temp_output_file"
    exit 1
fi

# Clean up temporary prompt file
rm "$prompt_file"

# Extract only valid JSON from the output
echo "Cleaning the output..."
# Try to extract JSON using grep and pattern matching
if grep -q "^\s*{" "$temp_output_file"; then
    # Find the first opening brace and last closing brace
    start_line=$(grep -n "^\s*{" "$temp_output_file" | head -1 | cut -d: -f1)
    end_line=$(grep -n "^\s*}" "$temp_output_file" | tail -1 | cut -d: -f1)
    
    if [ -n "$start_line" ] && [ -n "$end_line" ]; then
        sed -n "${start_line},${end_line}p" "$temp_output_file" > "$output_file"
    else
        # Fallback: try using jq to parse and pretty-print the JSON
        cat "$temp_output_file" | jq . > "$output_file" 2>/dev/null || cp "$temp_output_file" "$output_file"
    fi
else
    # Fallback: try using jq to parse and pretty-print the JSON
    cat "$temp_output_file" | jq . > "$output_file" 2>/dev/null || cp "$temp_output_file" "$output_file"
fi

# Clean up temporary output file
rm "$temp_output_file"

# Validate the final output JSON
if ! jq empty "$output_file" 2>/dev/null; then
    echo "Warning: The cleaned output may not be valid JSON. Please check '$output_file'."
    echo "You may need to manually extract the JSON portion from the raw output."
else
    echo "Translation successful! Created '$output_file' with clean JSON."
fi

exit 0