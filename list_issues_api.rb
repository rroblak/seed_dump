#!/usr/bin/env ruby


# ---
# Description: Fetches all open issues for a specific GitHub repository
#              using the official GitHub API via the Octokit gem.
#              Includes the first 500 characters of the issue body.
#
# Usage:
#   1. Install required gem: gem install octokit
#   2. Run the script: ruby your_script_name.rb
#   3. Optional: For higher rate limits, create a GitHub Personal Access Token (PAT)
#      with 'public_repo' or 'repo' scope at https://github.com/settings/tokens
#      and set it as an environment variable before running:
#      export GITHUB_PAT="your_token_here"
#      ruby your_script_name.rb
#
# Dependencies:
#   - octokit: Official GitHub API client library (https://github.com/octokit/octokit.rb)
# ---

require 'octokit'
require 'uri' # Used for potential URL parsing/validation if needed

# --- Configuration ---
REPO_NWO = 'rroblak/seed_dump' # Repository Name With Owner (owner/repo)
# Optional: Provide GitHub Personal Access Token via environment variable
# See Usage notes above for details.
ACCESS_TOKEN = ENV['GITHUB_PAT']
BODY_SNIPPET_LENGTH = 500 # Max characters of the body to display
# --- End Configuration ---

# Function to fetch issues using the GitHub API
def fetch_issues_via_api(repo_nwo, access_token)
  all_issues = []

  # Initialize Octokit client
  # auto_paginate: true tells Octokit to automatically fetch all pages
  client_options = { auto_paginate: true }
  if access_token && !access_token.empty?
    client_options[:access_token] = access_token
    puts "Using provided GitHub Personal Access Token."
  else
    puts "Accessing API anonymously (rate limits are lower)."
  end

  begin
    client = Octokit::Client.new(client_options)

    # Check rate limit before starting if authenticated
    if access_token
      rate_limit = client.rate_limit
      puts "API Rate Limit: #{rate_limit.remaining}/#{rate_limit.limit} requests remaining."
      if rate_limit.remaining == 0
         puts "Warning: Rate limit is 0. Request might fail. Limit resets at #{rate_limit.resets_at}."
      end
    end

    puts "Fetching open issues for #{repo_nwo}..."

    # Fetch all open issues. Octokit handles pagination automatically.
    # The issues endpoint returns both issues and pull requests, so we filter later.
    api_results = client.issues(repo_nwo, state: 'open')

    # Filter out pull requests, keeping only issues
    all_issues = api_results.reject { |item| item.pull_request }

    puts "Successfully fetched #{all_issues.count} open issues."

  rescue Octokit::Unauthorized => e
    puts "\nError: GitHub API authentication failed."
    puts "If using a token (GITHUB_PAT), ensure it's valid and has repo scope if needed."
    puts "Message: #{e.message}"
    return nil # Return nil on error
  rescue Octokit::NotFound => e
    puts "\nError: Repository '#{repo_nwo}' not found or not accessible."
    puts "Message: #{e.message}"
    return nil # Return nil on error
  rescue Octokit::TooManyRequests => e
    puts "\nError: GitHub API rate limit exceeded."
    puts "Wait before trying again or use an authenticated token (GITHUB_PAT)."
    begin
      rate_limit = client.rate_limit! # Fetch limit details after error
      puts "Current Limit: #{rate_limit.remaining}/#{rate_limit.limit}. Resets at #{rate_limit.resets_at}"
    rescue StandardError => limit_error
        puts "Could not retrieve rate limit details after error: #{limit_error.message}"
    end
    puts "Message: #{e.message}"
    return nil # Return nil on error
  rescue Faraday::ConnectionFailed => e
    puts "\nError: Network connection failed. Check your internet connection."
    puts "Message: #{e.message}"
    return nil # Return nil on error
  rescue StandardError => e
    puts "\nAn unexpected error occurred:"
    puts "Message: #{e.message}"
    puts "Backtrace:\n#{e.backtrace.join("\n")}"
    return nil # Return nil on error
  end

  all_issues
end

# --- Main Execution ---
if __FILE__ == $PROGRAM_NAME
  # Check if octokit gem is installed
  begin
    gem 'octokit'
  rescue Gem::LoadError
    puts "Error: The 'octokit' gem is required. Please install it by running:"
    puts "  gem install octokit"
    exit 1 # Exit the script if the gem is missing
  end

  issues_list = fetch_issues_via_api(REPO_NWO, ACCESS_TOKEN)

  # Check if issues_list is nil (indicating an error occurred) or empty
  if issues_list.nil?
    puts "\nFailed to retrieve issues due to errors listed above."
  elsif issues_list.empty?
    puts "\nNo open issues found for #{REPO_NWO}."
  else
    puts "\n--- Open Issues for #{REPO_NWO} ---"
    puts "--------------------------------------------------"
    # Print the details for each fetched issue
    issues_list.each do |issue|
      puts "Issue ##{issue.number}: #{issue.title}"
      puts "  URL: #{issue.html_url}"

      # Add issue body snippet
      if issue.body && !issue.body.empty?
        # Remove CR characters and excessive newlines for cleaner snippet
        cleaned_body = issue.body.gsub("\r", "").gsub(/\n{3,}/, "\n\n")
        body_snippet = cleaned_body[0...BODY_SNIPPET_LENGTH]
        truncated = cleaned_body.length > BODY_SNIPPET_LENGTH
        puts "  Body: #{body_snippet}#{truncated ? '...' : ''}"
      else
        puts "  Body: (No description provided)"
      end

      # Example: Print labels if needed
      # labels = issue.labels.map(&:name)
      # puts "  Labels: #{labels.empty? ? 'None' : labels.join(', ')}"
      puts "" # Add a blank line for readability
    end
  end

  puts "\n--- Notes ---"
  puts "- Fetched using the official GitHub API via the Octokit gem."
  puts "- To increase rate limits, set the GITHUB_PAT environment variable."
  puts "-------------"
end
