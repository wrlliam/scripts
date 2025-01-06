#!/bin/bash

# Function to print messages in green
print_success() {
  echo -e "\033[0;32m$1\033[0m"
}

# Function to print messages in red
print_error() {
  echo -e "\033[0;31m$1\033[0m"
}

# Variables
DELETE=false
TARGET_FOLDER="/home/will/nas/Movies"

# Parse arguments
for arg in "$@"; do
  case $arg in
    -d|--delete)
      DELETE=true
      ;;
    -f|--folder)
      shift
      TARGET_FOLDER="$1"
      ;;
  esac
  shift
done

# Ensure ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  print_error "ffmpeg is not installed. Please install it and try again."
  exit 1
fi

# Verify the target folder exists
if [[ ! -d "$TARGET_FOLDER" ]]; then
  print_error "The specified folder does not exist: $TARGET_FOLDER"
  exit 1
fi

# Process all MKV files in the target folder and its subdirectories
sudo find "$TARGET_FOLDER" -type f -name "*.mkv" | while read -r file; do
  # Get the file name without extension and directory
  base_name="${file%.*}"

  # Convert MKV to MP4
  ffmpeg_output=$(ffmpeg -i "$file" -c:v copy -c:a copy "$base_name.mp4" 2>&1)

  if [[ $? -eq 0 ]]; then
    print_success "Successfully converted: $file"

    if $DELETE; then
      sudo rm "$file"
    else
      sudo mv "$file" "$file.bak"
    fi
  else
    print_error "Failed to convert: $file"
    print_error "Reason: $ffmpeg_output"
  fi

done

print_success "All files processed. Exiting."
