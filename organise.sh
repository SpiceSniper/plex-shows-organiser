#!/bin/bash

# List of video file extensions to process
VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "m4v" "mpg" "mpeg" "webm")

# List of image file extensions to process
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "webp")

# List of folder names to treat as Specials
SPECIALS_FOLDERS=("Specials" "Extras" "Bonus" "Featurettes")

# Function to clean up consecutive spaces in a string
clean_multiple_spaces() {
    local str="$1"
    # Replace multiple consecutive spaces with a single space
    echo "$str" | sed -e 's/[[:space:]]\{2,\}/ /g'
}

# Function to capitalize the first letter of a string
capitalize_first() {
    local str="$1"
    if [[ -z "$str" ]]; then
        echo ""
        return
    fi
    
    # Capitalize first letter, keep the rest as is
    local first_char=$(echo "${str:0:1}" | tr '[:lower:]' '[:upper:]')
    local rest="${str:1}"
    echo "${first_char}${rest}"
}

# Function to check if file is a video based on extension
is_video_file() {
    local filename="$1"
    local ext="${filename##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    for valid_ext in "${VIDEO_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$valid_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if file is an image based on extension
is_image_file() {
    local filename="$1"
    local ext="${filename##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    for valid_ext in "${IMAGE_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$valid_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if file is in a Specials folder
is_in_specials_folder() {
    local filepath="$1"
    local current_dir="$filepath"
    
    # Walk up the directory tree to check for any folder in SPECIALS_FOLDERS
    while [[ "$current_dir" != "." && "$current_dir" != "/" ]]; do
        local dir_name=$(basename "$current_dir")
        for special_folder in "${SPECIALS_FOLDERS[@]}"; do
            if [[ "$dir_name" == "$special_folder" ]]; then
                return 0 # Yes, it's in a Specials folder
            fi
        done
        current_dir=$(dirname "$current_dir")
    done
    
    return 1 # Not in a Specials folder
}

# Function to extract year from folder name if available
extract_year_from_folder() {
    local folder_name="$1"
    
    # Check if folder name contains year in parentheses
    if [[ "$folder_name" =~ \(([0-9]{4})\) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    # Check if folder name ends with a year
    elif [[ "$folder_name" =~ [._\ -]+([0-9]{4})$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    return 1
}

# Function to get show name from folder (for image processing)
get_show_name_from_folder() {
    local folder_path="$1"
    local show_name=$(basename "$folder_path")
    local year=""
    
    # Extract year from folder name if present
    if [[ "$show_name" =~ (.*)\(([0-9]{4})\) ]]; then
        show_name="${BASH_REMATCH[1]}"
        year="${BASH_REMATCH[2]}"
        # Trim whitespace
        show_name="$(echo "$show_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    elif [[ "$show_name" =~ (.*)[._\ -]+([0-9]{4})$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        year="${BASH_REMATCH[2]}"
    fi
    
    # Clean up show name
    show_name="${show_name//./\ }"
    show_name="${show_name//-/}"  # Remove hyphens completely
    show_name="${show_name//_/\ }"
    show_name="$(echo "$show_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    
    # Remove multiple consecutive spaces
    show_name="$(clean_multiple_spaces "$show_name")"
    
    # Capitalize first letter
    show_name=$(capitalize_first "$show_name")
    
    echo "$show_name|$year"
}

# Function to check if filename is only season/episode marker
is_only_season_episode() {
    local filename="$1"
    local basename="${filename%.*}"  # Remove extension
    
    # Check if the filename is just a season/episode marker with no show name
    if [[ "$basename" =~ ^[Ss][0-9]{1,2}[Ee][0-9]{1,2}$ ]] || 
       [[ "$basename" =~ ^[Ss][0-9][Ee][0-9]$ ]] ||
       [[ "$basename" =~ ^[0-9]{3}$ ]]; then
        return 0
    fi
    
    return 1
}

# Function to find matching image file for a season/episode in a directory
find_matching_image() {
    local dirname="$1"
    local season_num="$2"
    local episode_num="$3"
    
    # Pad season and episode numbers with zeros for matching
    local padded_season=$(printf "%02d" "$season_num")
    local padded_episode=$(printf "%02d" "$episode_num")
    
    # Look for any image file with the same season/episode
    for img_file in "$dirname"/*; do
        if is_image_file "$img_file"; then
            local img_basename=$(basename "$img_file")
            
            # Check for season/episode patterns
            if [[ "$img_basename" =~ [Ss]${padded_season}[Ee]${padded_episode} ]] || 
               [[ "$img_basename" =~ [Ss]${season_num}[Ee]${episode_num} ]]; then
                echo "$img_file"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to find episode number from images in the directory
find_episode_from_images() {
    local filepath="$1"
    local season_num="$2"
    local dirname=$(dirname "$filepath")
    
    # Look for image files in the same directory
    for img_file in "$dirname"/*; do
        if is_image_file "$img_file"; then
            local img_basename=$(basename "$img_file")
            
            # Skip images that are just S##E## markers, they don't help us
            if is_only_season_episode "${img_basename%.*}"; then
                continue
            fi
            
            # Check if this image has a parseable season and episode
            if [[ "$img_basename" =~ [Ss]${season_num}[Ee]([0-9]{1,2}) ]]; then
                # Found a matching image with the same season and a parseable episode
                echo "${BASH_REMATCH[1]}"
                return 0
            elif [[ "$img_basename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
                # Check if seasons match
                if [[ "${BASH_REMATCH[1]}" == "$season_num" ]]; then
                    echo "${BASH_REMATCH[2]}"
                    return 0
                fi
            fi
        fi
    done
    
    return 1
}

# Function to extract year from filename
extract_year_from_filename() {
    local filename="$1"
    
    if [[ "$filename" =~ \(([0-9]{4})\) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    return 1
}

# Function to extract show name, season, and episode info
extract_show_info() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local dirname=$(dirname "$filepath")
    
    # Try to extract year if present in parentheses
    if [[ "$filename" =~ (.*)\(([0-9]{4})\)(.*) ]]; then
        show_name="${BASH_REMATCH[1]}"
        year="${BASH_REMATCH[2]}"
        rest_of_filename="${BASH_REMATCH[3]}"
        
        # Clean up show name
        show_name="$(echo "$show_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        
        # Try to extract season/episode from the rest of the filename
        if [[ "$rest_of_filename" =~ -[[:space:]]*[Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
            season_num="${BASH_REMATCH[1]}"
            episode_num="${BASH_REMATCH[2]}"
            # Already in correct format, just extract info
        else
            # Try normal patterns on the rest of filename
            if [[ "$rest_of_filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
                season_num="${BASH_REMATCH[1]}"
                episode_num="${BASH_REMATCH[2]}"
            elif [[ "$rest_of_filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
                season_num="${BASH_REMATCH[1]}"
                episode_num="${BASH_REMATCH[2]}"
            else
                # Try to find episode number from image files
                if [[ "$rest_of_filename" =~ [Ss]([0-9]{1,2}) ]]; then
                    # We at least have a season number, try to find episode from images
                    season_num="${BASH_REMATCH[1]}"
                    img_episode=$(find_episode_from_images "$filepath" "$season_num")
                    if [[ -n "$img_episode" ]]; then
                        echo "  Using episode number $img_episode from matching image" >&2
                        episode_num="$img_episode"
                    else
                        echo "ERROR: Cannot determine episode number for $filepath"
                        return 1
                    fi
                else
                    echo "ERROR: Cannot determine season/episode for $filepath"
                    return 1
                fi
            fi
        fi
    else
        # No year in parentheses, try standard patterns
        year=""
        
        # Pattern: Show.Name.S01E01 - capture all text until season/episode pattern
        if [[ "$filename" =~ (.*)[._\ -]+[Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
            show_name="${BASH_REMATCH[1]}"
            season_num="${BASH_REMATCH[2]}"
            episode_num="${BASH_REMATCH[3]}"
            
            # Check if show name contains a year pattern (e.g., "Archer 2009")
            if [[ "$show_name" =~ (.*)[._\ -]+([0-9]{4})$ ]]; then
                show_name="${BASH_REMATCH[1]}"
                year="${BASH_REMATCH[2]}"
            fi
        # Pattern: Show.Name.1x01 - capture all text until season/episode pattern
        elif [[ "$filename" =~ (.*)[._\ -]+([0-9]{1,2})x([0-9]{1,2}) ]]; then
            show_name="${BASH_REMATCH[1]}"
            season_num="${BASH_REMATCH[2]}"
            episode_num="${BASH_REMATCH[3]}"
            
            # Check if show name contains a year pattern
            if [[ "$show_name" =~ (.*)[._\ -]+([0-9]{4})$ ]]; then
                show_name="${BASH_REMATCH[1]}"
                year="${BASH_REMATCH[2]}"
            fi
        # Pattern: Show.Name.S01 or similar - season only, try to find episode from images
        elif [[ "$filename" =~ (.*)[._\ -]+[Ss]([0-9]{1,2}) ]]; then
            show_name="${BASH_REMATCH[1]}"
            season_num="${BASH_REMATCH[2]}"
            
            # Check if show name contains a year pattern
            if [[ "$show_name" =~ (.*)[._\ -]+([0-9]{4})$ ]]; then
                show_name="${BASH_REMATCH[1]}"
                year="${BASH_REMATCH[2]}"
            fi
            
            # Try to find episode number from images
            img_episode=$(find_episode_from_images "$filepath" "$season_num")
            if [[ -n "$img_episode" ]]; then
                echo "  Using episode number $img_episode from matching image" >&2
                episode_num="$img_episode"
            else
                echo "ERROR: Cannot determine episode number for $filepath"
                return 1
            fi
        # Check if in Season folder already
        elif [[ "$(basename "$dirname")" =~ ^[Ss]eason[[:space:]]*([0-9]+)$ ]]; then
            season_num="${BASH_REMATCH[1]}"
            # Try to find episode number
            if [[ "$filename" =~ [Ee]([0-9]{1,2}) ]]; then
                episode_num="${BASH_REMATCH[1]}"
                # Show name might be the parent directory
                show_folder=$(dirname "$dirname")
                IFS='|' read -r show_name year <<< "$(get_show_name_from_folder "$show_folder")"
                
            elif [[ "$filename" =~ [^0-9]([0-9]{1,2})[^0-9] ]]; then
                episode_num="${BASH_REMATCH[1]}"
                # Show name might be the parent directory
                show_folder=$(dirname "$dirname")
                IFS='|' read -r show_name year <<< "$(get_show_name_from_folder "$show_folder")"
                
            else
                # Try to find episode number from images
                img_episode=$(find_episode_from_images "$filepath" "$season_num")
                if [[ -n "$img_episode" ]]; then
                    echo "  Using episode number $img_episode from matching image" >&2
                    episode_num="$img_episode"
                    # Show name might be the parent directory
                    show_folder=$(dirname "$dirname")
                    IFS='|' read -r show_name year <<< "$(get_show_name_from_folder "$show_folder")"
                else
                    echo "ERROR: Cannot determine episode number for $filepath"
                    return 1
                fi
            fi
        else
            echo "ERROR: Cannot determine season/episode for $filepath"
            return 1
        fi
    fi
    
    # Clean up show name
    show_name="${show_name//./\ }"
    show_name="${show_name//-/}"  # Remove hyphens completely
    show_name="${show_name//_/\ }"
    show_name="$(echo "$show_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    
    # Remove multiple consecutive spaces
    show_name="$(clean_multiple_spaces "$show_name")"
    
    # Capitalize first letter
    show_name=$(capitalize_first "$show_name")
    
    # Convert season and episode numbers to integers to handle leading zeros properly
    season_num=$((10#$season_num))
    episode_num=$((10#$episode_num))
    
    echo "$show_name|$year|$season_num|$episode_num"
    return 0
}

# Function to extract image info (for images in season folders)
extract_image_info() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local dirname=$(dirname "$filepath")
    local parent_dir=$(basename "$dirname")
    
    # First check if we're in a Season folder
    if [[ "$parent_dir" =~ ^[Ss]eason[[:space:]]*([0-9]+)$ ]]; then
        local season_num="${BASH_REMATCH[1]}"
        local show_folder=$(dirname "$dirname")
        local show_name=""
        local year=""
        local episode_num=""
        
        # Extract episode number from filename if possible
        if [[ "$filename" =~ [Ee]([0-9]{1,2}) ]]; then
            episode_num="${BASH_REMATCH[1]}"
        elif [[ "$filename" =~ ^[0-9]{3}(\.[^.]+)?$ ]]; then
            # Format like "704.jpg" - first digit is season, last two are episode
            local basename="${filename%.*}"
            season_num="${basename:0:1}"
            episode_num="${basename:1:2}"
            # Remove leading zeros from episode number
            episode_num=$((10#$episode_num))
        elif [[ "$filename" =~ ([0-9]{1,2}) ]]; then
            episode_num="${BASH_REMATCH[1]}"
        else
            # Default to episode 1 if cannot determine
            episode_num="1"
        fi
        
        # Check if the filename is only a season/episode marker
        if is_only_season_episode "${filename%.*}"; then
            # Get show name from folder
            IFS='|' read -r show_name year <<< "$(get_show_name_from_folder "$show_folder")"
            # Mark this image as name source to use for videos
            echo "Using show folder name for image: $show_name" >&2
            
            # Create a marker file to signal that we should use this show name for videos
            local show_info="${show_name}|${year}"
            
            # We'll just create a small dummy file in the Season directory to store this information
            echo "$show_info" > "${dirname}/.show_info_${season_num}_${episode_num}"
        else
            # Extract show name from image name
            local base_name="${filename%.*}"  # Remove extension
            
            # Try to extract show name and year from image name
            if [[ "$base_name" =~ (.*)[._\ -]+[Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
                show_name="${BASH_REMATCH[1]}"
                # Check if show name contains a year pattern
                if [[ "$show_name" =~ (.*)[._\ -]+([0-9]{4})$ ]]; then
                    show_name="${BASH_REMATCH[1]}"
                    year="${BASH_REMATCH[2]}"
                fi
            else
                # If we can't extract from image name, use folder
                IFS='|' read -r show_name year <<< "$(get_show_name_from_folder "$show_folder")"
            fi
            
            # Clean up show name
            show_name="${show_name//./\ }"
            show_name="${show_name//-/}"  # Remove hyphens completely
            show_name="${show_name//_/\ }"
            show_name="$(echo "$show_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            
            # Remove multiple consecutive spaces
            show_name="$(clean_multiple_spaces "$show_name")"
        fi
        
        # Capitalize first letter
        show_name=$(capitalize_first "$show_name")
        
        # Convert season and episode numbers to integers to handle leading zeros properly
        season_num=$((10#$season_num))
        episode_num=$((10#$episode_num))
        
        echo "$show_name|$year|$season_num|$episode_num"
        return 0
    else
        echo "ERROR: Image not in a Season folder: $filepath"
        return 1
    fi
}

# Check if file is in a Season folder
in_season_folder() {
    local filepath="$1"
    local dirname=$(dirname "$filepath")
    local parent_dir=$(basename "$dirname")
    
    # Ignore "Specials" folders
    if [[ "$parent_dir" == "Specials" ]]; then
        return 1
    fi
    
    if [[ "$parent_dir" =~ ^[Ss]eason[[:space:]]*([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        return 1
    fi
}

# Function to check if we should use show info from folder
check_for_show_info_marker() {
    local dirname="$1"
    local season_num="$2"
    local episode_num="$3"
    
    # Pad season and episode numbers with zeros for matching
    local padded_season=$(printf "%02d" "$season_num")
    local padded_episode=$(printf "%02d" "$episode_num")
    
    # Check if marker file exists
    local marker_file="${dirname}/.show_info_${padded_season}_${padded_episode}"
    if [[ -f "$marker_file" ]]; then
        cat "$marker_file"
        return 0
    fi
    
    # Try without padding
    marker_file="${dirname}/.show_info_${season_num}_${episode_num}"
    if [[ -f "$marker_file" ]]; then
        cat "$marker_file"
        return 0
    fi
    
    return 1
}

# Process a video file
process_file() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local dirname=$(dirname "$filepath")
    local ext="${filename##*.}"
    
    # Skip files in Specials folders
    if is_in_specials_folder "$filepath"; then
        echo "Skipping file in Specials folder: $filepath"
        return
    fi
    
    echo "Processing: $filepath"
    
    # Extract show info
    local info
    if ! info=$(extract_show_info "$filepath"); then
        echo "  $info"
        return
    fi
    
    # Parse the extracted information
    IFS='|' read -r show_name year season_num episode_num <<< "$info"
    
    # Reset year - we'll only use it if we find a matching image with a year
    year=""
    
    # Check if we should use show info from folder (from previously processed image)
    local current_season
    if current_season=$(in_season_folder "$filepath"); then
        local folder_info
        if folder_info=$(check_for_show_info_marker "$dirname" "$season_num" "$episode_num"); then
            # Use the show name and year from the marker file
            IFS='|' read -r folder_show_name folder_year <<< "$folder_info"
            echo "  Using show name from folder: $folder_show_name"
            show_name="$folder_show_name"
            
            # Only set year if it exists in the folder info
            if [[ -n "$folder_year" ]]; then
                year="$folder_year"
                echo "  Using year from folder: $year"
            fi
        fi
    fi
    
    # Try to find a matching image file and use its year if available
    local matching_image
    if matching_image=$(find_matching_image "$dirname" "$season_num" "$episode_num"); then
        echo "  Found matching image: $(basename "$matching_image")"
        
        # Check if the image has a year in its filename
        local image_year
        if image_year=$(extract_year_from_filename "$(basename "$matching_image")"); then
            echo "  Using year from matching image: $image_year"
            year="$image_year"
        else
            echo "  Matching image has no year, omitting year from filename"
        fi
    else
        echo "  No matching image found, omitting year from filename"
    fi
    
    # Pad season and episode numbers with zeros
    season_num=$(printf "%02d" "$season_num")
    episode_num=$(printf "%02d" "$episode_num")
    
    # Prepare year string
    if [[ -n "$year" ]]; then
        year_str=" (${year})"
    else
        year_str=""
    fi
    
    # Create new filename with hyphen between year and season info
    new_filename="${show_name}${year_str} - S${season_num}E${episode_num}.${ext}"
    
    # Remove multiple consecutive spaces in the filename
    new_filename="$(clean_multiple_spaces "$new_filename")"
    
    # Check if already in Season folder
    local current_season
    if current_season=$(in_season_folder "$filepath"); then
        # Convert to numbers to compare properly
        current_season_num=$((10#$current_season))
        actual_season_num=$((10#$season_num))
        
        if [[ $current_season_num -eq $actual_season_num ]]; then
            # Already in correct Season folder, just rename
            local new_filepath="${dirname}/${new_filename}"
            
            if [[ "$filename" == "$new_filename" ]]; then
                echo "  File already correctly named. Skipping."
            else
                echo "  Renaming to: $new_filename"
                mv -n "$filepath" "$new_filepath"
            fi
        else
            # In wrong Season folder, move to correct one
            local base_dir=$(dirname "$dirname")
            local season_folder="${base_dir}/Season ${season_num}"
            local new_filepath="${season_folder}/${new_filename}"
            
            echo "  Moving to correct Season folder: Season ${season_num}"
            mkdir -p "$season_folder"
            mv -n "$filepath" "$new_filepath"
        fi
    else
        # Not in a Season folder, move to one
        local season_folder="${dirname}/Season ${season_num}"
        local new_filepath="${season_folder}/${new_filename}"
        
        echo "  Creating Season folder: Season ${season_num}"
        mkdir -p "$season_folder"
        echo "  Moving and renaming to: $new_filename"
        mv -n "$filepath" "$new_filepath"
    fi
}

# Process an image file in a season folder
process_image() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local dirname=$(dirname "$filepath")
    local ext="${filename##*.}"
    
    # Skip files in Specials folders
    if is_in_specials_folder "$filepath"; then
        echo "Skipping image in Specials folder: $filepath"
        return
    fi
    
    echo "Processing image: $filepath"
    
    # Extract image info
    local info
    if ! info=$(extract_image_info "$filepath"); then
        echo "  $info"
        return
    fi
    
    # Parse the extracted information
    IFS='|' read -r show_name year season_num episode_num <<< "$info"
    
    # Pad season and episode numbers with zeros
    season_num=$(printf "%02d" "$season_num")
    episode_num=$(printf "%02d" "$episode_num")
    
    # Prepare year string
    if [[ -n "$year" ]]; then
        year_str=" (${year})"
    else
        year_str=""
    fi
    
    # Create new filename with hyphen between year and season info
    new_filename="${show_name}${year_str} - S${season_num}E${episode_num}.${ext}"
    
    # Remove multiple consecutive spaces in the filename
    new_filename="$(clean_multiple_spaces "$new_filename")"
    
    # Rename the image
    local new_filepath="${dirname}/${new_filename}"
    
    if [[ "$filename" == "$new_filename" ]]; then
        echo "  Image already correctly named. Skipping."
    else
        echo "  Renaming to: $new_filename"
        mv -n "$filepath" "$new_filepath"
    fi
}

# Remove any old marker files before starting
find . -name ".show_info_*" -type f -delete

# Main function
echo "Starting to organize files..."

# First, find and process all image files in Season folders
echo "Processing image files first..."
find . -type f | while read -r file; do
    if is_image_file "$file"; then
        # Skip files in Specials folders
        if ! is_in_specials_folder "$file"; then
            if in_season_folder "$file" > /dev/null; then
                process_image "$file"
            fi
        else
            echo "Skipping image in Specials folder: $file"
        fi
    fi
done

# Then, find and process all video files
echo "Processing video files next..."
find . -type f | while read -r file; do
    if is_video_file "$file"; then
        # Skip files in Specials folders
        if ! is_in_specials_folder "$file"; then
            process_file "$file"
        else
            echo "Skipping video in Specials folder: $file"
        fi
    fi
done

# Clean up marker files
find . -name ".show_info_*" -type f -delete

echo "Done organizing files!"