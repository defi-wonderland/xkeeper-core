#!/bin/bash

root_path="solidity/interfaces"
excluded_path="external"

# generate docs in a temporary directory
temp_folder="technical-docs"
FOUNDRY_PROFILE=docs forge doc --out "$temp_folder"

# Exclude the external folder from the generated docs
find "$temp_folder/src/$root_path" -type d -name "$excluded_path" -exec rm -rf {} \;

# Edit the SUMMARY after the Interfaces section
# https://stackoverflow.com/questions/67086574/no-such-file-or-directory-when-using-sed-in-combination-with-find
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -e '/Technical Documentation/q' docs/src/SUMMARY.md
else
  sed -i -e '/Technical Documentation/q' docs/src/SUMMARY.md
fi

# Copy the generated SUMMARY, from the tmp directory
tail -n +4 $temp_folder/src/SUMMARY.md >> docs/src/SUMMARY_TEMP.md

# Remove the external docs from the SUMMARY
(head -n 4 docs/src/SUMMARY_TEMP.md && tail -n +18 docs/src/SUMMARY_TEMP.md) >> docs/src/SUMMARY.md
rm docs/src/SUMMARY_TEMP.md

# Delete old generated interfaces docs
rm -rf "docs/src/$root_path"

# Creating the directory to circumvent differences in behavior between UNIX and macOS
mkdir -p "docs/src/$root_path"

# Move new generated interfaces docs from tmp to the original directory
cp -R "$temp_folder/src/$root_path" "docs/src/solidity/"

# Delete the tmp directory
rm -rf "$temp_folder"

# Function to replace text in all files (to fix the internal paths)
replace_text() {
    for file in "$1"/*; do
        if [ -f "$file" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
              sed -i '' "s|$temp_folder/src/||g" "$file"
            else
              sed -i "s|$temp_folder/src/||g" "$file"
            fi
        elif [ -d "$file" ]; then
            replace_text "$file"
        fi
    done
}

# Path to the base folder
base_folder="docs/src/$root_path"

# Call the function to fix the paths
replace_text "$base_folder"

# Remove the external docs from the README
perl -i -ne 'print if $. != 6' docs/src/solidity/interfaces/README.md
