#!/usr/bin/env bash
# Export passwords to CSV files grouped by top-level folder

set -euo pipefail

shopt -s nullglob globstar
prefix=${PASSWORD_STORE_DIR:-$HOME/.password-store}

output_dir="/tmp/pass_export"
mkdir -p "$output_dir"

echo "Exporting passwords from: $prefix"
echo "Exporting passwords to: $output_dir"

is_url() {
    local name="$1"
    if [[ $name =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$ ]]; then
        echo "$name"
    else
        echo ""
    fi
}

process_password() {
    local file="$1"
    local folder="$2"
    local full_name="${file#$prefix/}"
    full_name="${full_name%.gpg}"
    
    # Remove the extra leading slash and folder name
    local name="${full_name#/}"
    name="${name#*/}"
    
    echo "Processing: $full_name"
    
    local content
    if ! content=$(pass show "$full_name" 2>&1); then
        echo "Failed to decrypt: $full_name - Error: $content" >&2
        return 1
    fi
    
    local password
    local otp
    local notes
    
    # Extract password (first line)
    password=$(echo "$content" | head -n1)
    
    # Extract OTP if exists
    otp=$(echo "$content" | grep -o 'otpauth://[^[:space:]]*' | head -n1)
    
    # Extract notes (everything after the first line) and remove OTP
    notes=$(echo "$content" | tail -n +2 | grep -v 'otpauth://' | tr '\n' ' ' | sed 's/[,"\]/\\&/g' | sed 's/^ *//; s/ *$//')
    
    # Check if name is a URL
    local url=$(is_url "$name")
    
    # Escape double quotes in all fields
    name=$(echo "$name" | sed 's/"/""/g')
    password=$(echo "$password" | sed 's/"/""/g')
    otp=$(echo "$otp" | sed 's/"/""/g')
    notes=$(echo "$notes" | sed 's/"/""/g')
    url=$(echo "$url" | sed 's/"/""/g')
    
    echo "\"$name\",\"$password\",\"$otp\",\"$notes\",\"$url\"" >> "$output_dir/$folder.csv"
    echo "Exported: $full_name to $folder.csv"
}

echo "Searching for password files..."
password_files=("$prefix"/**/*.gpg)
echo "Found ${#password_files[@]} password files."

if [ ${#password_files[@]} -eq 0 ]; then
    echo "No password files found. Exiting."
    exit 1
fi

for file in "${password_files[@]}"; do
    folder=$(basename "$(dirname "${file#$prefix/}")")
    if ! process_password "$file" "$folder"; then
        echo "Error processing $file. Continuing with next file."
    fi
done

echo "Export complete. Check $output_dir for results."
ls -l "$output_dir"

# Print contents of one CSV file for verification
first_csv=$(ls -1 "$output_dir"/*.csv | head -n1)
if [ -n "$first_csv" ]; then
    echo "Contents of $first_csv (first 5 lines):"
    head -n5 "$first_csv"
fi
