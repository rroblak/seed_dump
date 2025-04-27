#!/bin/bash

# Script to find the oldest supported MRI Ruby version using asdf and appraisal.
# Iterates from the latest available MRI Ruby version downwards.

set -uo pipefail # Exit on unset variables, error on pipeline failure

# --- Configuration ---
# Regex to match stable MRI Ruby versions (e.g., 3.3.0, 3.2.4, 2.7.8)
# Excludes pre-releases, RCs, dev versions. Adjust if needed.
MRI_VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+$'

# --- Functions ---
cleanup() {
  echo "Cleaning up..."
  # Remove .tool-versions if it exists
  if [[ -f ".tool-versions" ]]; then
    echo "Removing temporary .tool-versions file."
    rm -f ".tool-versions"
  fi
  echo "Cleanup finished."
}

# --- Main Script ---

# Ensure asdf is available
if ! command -v asdf &> /dev/null; then
    echo "Error: asdf command not found. Please install asdf."
    exit 1
fi

# Ensure appraisal is available (at least check the command)
if ! command -v appraisal &> /dev/null; then
    echo "Warning: appraisal command not found. Ensure it's in the Gemfile and run 'bundle install' first."
    # Attempt bundle install once initially
    if ! bundle check &> /dev/null; then
        echo "Running initial 'bundle install'..."
        if ! bundle install; then
            echo "Error: Initial bundle install failed. Cannot proceed."
            exit 1
        fi
    fi
fi


# Set trap for cleanup on exit (normal or error)
trap cleanup EXIT

echo "Starting Ruby compatibility check..."

# 1. Get currently installed Ruby versions to avoid uninstalling them
echo "Detecting pre-installed Ruby versions..."
pre_installed_rubies=$(asdf list ruby 2>/dev/null | xargs)
echo "Found pre-installed: ${pre_installed_rubies:-None}"

# 2. Get all available MRI Ruby versions and sort them latest first
echo "Fetching available MRI Ruby versions from asdf..."
# Use process substitution and handle potential errors reading the list
available_versions_output=$(asdf list all ruby)
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to list all ruby versions from asdf."
    exit 1
fi

sorted_mri_versions=$(echo "$available_versions_output" | grep -E "$MRI_VERSION_REGEX" | sort -V -r)
if [[ -z "$sorted_mri_versions" ]]; then
    echo "Error: Could not find any stable MRI Ruby versions matching regex '$MRI_VERSION_REGEX'."
    exit 1
fi

# 3. Initialize state variables
last_successful_version=""
first_failing_version=""
tested_a_version=false # Flag to check if any version was actually tested

# 4. Loop through sorted versions
while IFS= read -r version; do
  echo ""
  echo "--------------------------------------------------"
  echo "Attempting tests with Ruby $version"
  echo "--------------------------------------------------"
  tested_a_version=true
  was_installed_by_script=false

  # Check if this version was already installed
  is_pre_installed=false
  for installed_version in $pre_installed_rubies; do
    if [[ "$installed_version" == "$version" ]]; then
      is_pre_installed=true
      break
    fi
  done

  # Install if not pre-installed
  if [[ "$is_pre_installed" == "false" ]]; then
    echo "Ruby $version is not pre-installed. Attempting installation..."
    if ! asdf install ruby "$version"; then
      echo "ERROR: Failed to install Ruby $version. Skipping."
      # Clean up potentially partially installed version
      asdf uninstall ruby "$version" || true
      continue
    fi
    was_installed_by_script=true
  else
    echo "Ruby $version is pre-installed."
  fi

  # Set local version (creates .tool-versions) using the correct syntax
  echo "Setting local Ruby version to $version using 'asdf set local'..."
  if ! asdf set local ruby "$version"; then
    echo "ERROR: Failed to set local Ruby version to $version. Skipping."
    if [[ "$was_installed_by_script" == "true" ]]; then
        echo "Uninstalling Ruby $version as it was installed by script."
        asdf uninstall ruby "$version" || true
    fi
    # Ensure .tool-versions is removed if setting failed
    rm -f ".tool-versions"
    continue
  fi

  # *** Explicitly reshim after setting local version ***
  echo "Reshimming Ruby $version executables..."
  if ! asdf reshim ruby "$version"; then
      # This might happen if the install was corrupted, but often it's okay.
      echo "WARNING: Failed to reshim Ruby $version. Proceeding, but executables might not be found."
  fi

  # Ensure bundler is available and install dependencies
  echo "Ensuring Bundler and installing gems for Ruby $version..."
  # Try installing bundler conservatively, update RubyGems if needed. Ignore errors somewhat.
  # Use 'asdf exec' to ensure we use the shimmed gem command
  if ! asdf exec gem install bundler --conservative; then
      echo "Conservative bundler install failed, trying RubyGems update..."
      if ! asdf exec gem update --system; then
          echo "WARNING: RubyGems update failed."
      fi
      echo "Retrying bundler install..."
      if ! asdf exec gem install bundler; then
          echo "ERROR: Failed to install bundler for Ruby $version even after attempts. Skipping."
          # Reset local ruby, cleanup, and continue
          rm -f ".tool-versions"
          if [[ "$was_installed_by_script" == "true" ]]; then
              echo "Uninstalling Ruby $version as it was installed by script."
              asdf uninstall ruby "$version" || true
          fi
          continue
      fi
  fi

  # Use 'asdf exec' to ensure we use the shimmed bundle command
  if ! asdf exec bundle install; then
    echo "ERROR: 'bundle install' failed for Ruby $version. Skipping."
    # Reset local ruby, cleanup, and continue
    rm -f ".tool-versions"
    if [[ "$was_installed_by_script" == "true" ]]; then
        echo "Uninstalling Ruby $version as it was installed by script."
        asdf uninstall ruby "$version" || true
    fi
    continue
  fi

  # Install gems via appraisal
  echo "Running 'bundle exec appraisal install' for Ruby $version..."
  # Use 'asdf exec' to ensure we use the shimmed bundle command
   if ! asdf exec bundle exec appraisal install; then
    echo "ERROR: 'bundle exec appraisal install' failed for Ruby $version. Skipping."
    rm -f ".tool-versions"
    if [[ "$was_installed_by_script" == "true" ]]; then
        echo "Uninstalling Ruby $version as it was installed by script."
        asdf uninstall ruby "$version" || true
    fi
    continue
  fi

  # Run the tests via appraisal
  echo "Running tests ('bundle exec appraisal rake spec') for Ruby $version..."
  test_passed=false
  # Use 'asdf exec' to ensure we use the shimmed bundle command
  if asdf exec bundle exec appraisal rake spec; then
    test_passed=true
  fi

  # Handle test results
  if [[ "$test_passed" == "true" ]]; then
    echo "SUCCESS: Tests PASSED for Ruby $version."
    last_successful_version="$version"
    # Uninstall if we installed it
    if [[ "$was_installed_by_script" == "true" ]]; then
        echo "Uninstalling Ruby $version as it passed and was installed by script."
        asdf uninstall ruby "$version" || true
    fi
  else
    echo "FAILURE: Tests FAILED for Ruby $version."
    first_failing_version="$version"
    # Uninstall if we installed it
    if [[ "$was_installed_by_script" == "true" ]]; then
        echo "Uninstalling Ruby $version as it failed and was installed by script."
        asdf uninstall ruby "$version" || true
    fi
    # Reset local ruby version immediately after failure detection
    rm -f ".tool-versions"
    # Stop searching further
    break
  fi

  # Reset local ruby version before next iteration or script end
  rm -f ".tool-versions"

done <<< "$sorted_mri_versions" # Feed the sorted list into the loop

# 5. Report results
echo ""
echo "--------------------------------------------------"
echo "Compatibility Check Summary"
echo "--------------------------------------------------"

if [[ -n "$first_failing_version" ]]; then
  echo "The first version that FAILED tests was: $first_failing_version"
  if [[ -n "$last_successful_version" ]]; then
    echo "The oldest tested version that PASSED tests is likely: $last_successful_version"
    echo "(Suggest setting minimum required Ruby version >= $last_successful_version)"
  else
    echo "No tested Ruby version passed the tests."
  fi
elif [[ "$tested_a_version" == "false" ]]; then
    echo "No matching Ruby versions were found or could be tested."
elif [[ -n "$last_successful_version" ]]; then
    echo "All tested Ruby versions passed!"
    echo "The oldest tested version (which passed) was: $last_successful_version"
else
    echo "No versions were successfully tested."
fi
echo "--------------------------------------------------"

# Cleanup is handled by the trap EXIT

exit 0
