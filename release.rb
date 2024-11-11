#!/usr/bin/env ruby

require "net/http"
require "json"
require "uri"
require "csv"
require "dotenv/load"
require "optparse"
require_relative "ai_summary"
require_relative "release_note"

# API URL and endpoint references.
SHORTCUT_TOKEN = ENV["SHORTCUT_TOKEN"] || ""
API_URL_BASE = "https://api.app.shortcut.com/api/v3"
SEARCH_ENDPOINT = "/search/stories"
STORIES_ENDPOINT = "/stories"
EPICS_ENDPOINT = "/epics"

# Set to false if you want to include all stories in the release notes
USE_TEAMS = true

# Get your token from the local environment variable and prep it for use in the URL
SHORTCUT_API_TOKEN = "?token=#{SHORTCUT_TOKEN}"

def get_custom_fields
  url = "#{API_URL_BASE}/custom-fields"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri)
  request["Content-Type"] = "application/json"
  request["Shortcut-Token"] = SHORTCUT_TOKEN
  response = http.request(request)
  parsed_response = JSON.parse(response.body)

  # Extract only the id and value from each object's values
  custom_fields = parsed_response.map do |field|
    {
      id: field["id"],
      name: field["name"],
      values: field["values"].map { |value| {id: value["id"], value: value["value"]} }
    }
  end

  puts "\nFiltered custom fields:"
  custom_fields.each do |field|
    puts "Field Name: #{field[:name]} - Field ID: #{field[:id]}"
    field[:values].each do |value|
      puts "  Value: #{value[:value]} - Value ID: #{value[:id]}"
    end
    puts "-" * 40
  end
  custom_fields
rescue => e
  puts e
  exit(1)
end

def get_teams
  url = "#{API_URL_BASE}/groups"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri)
  request["Content-Type"] = "application/json"
  request["Shortcut-Token"] = SHORTCUT_TOKEN
  response = http.request(request)
  parsed_response = JSON.parse(response.body)

  # Use a hash to map epic ids to names for fast lookup
  teams = {}
  parsed_response.each do |team|
    teams[team["id"]] = team["name"]
  end

  puts teams
rescue => e
  puts e
  exit(1)
end

def is_valid_group?(group_id)
  # if you are not using team filtering, always return true (so all stories are included)
  return true unless USE_TEAMS

  # update this with your team ids and names
  valid_groups = {
    "66345678-1234-1234-1234-123456789012" => "team name"
  }
  valid_groups.key?(group_id)
end

def get_all_epics
  url = "#{API_URL_BASE}#{EPICS_ENDPOINT}"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri)
  request["Content-Type"] = "application/json"
  request["Shortcut-Token"] = SHORTCUT_TOKEN
  response = http.request(request)
  parsed_response = JSON.parse(response.body)

  # Use a hash to map epic ids to names for fast lookup
  epics = {}
  parsed_response.each do |epic|
    epics[epic["id"]] = epic["name"]
  end

  epics
rescue => e
  puts e
  exit(1)
end

def search_stories
  require "date"

  # Calculate the previous Friday
  today = Date.today
  previous_friday = today - ((today.wday + 1) % 7 + 2)

  # Update the query to search for stories done since the previous Friday
  query = {
    query: "state:done completed:#{previous_friday}..#{today}"
  }

  stories = []
  next_token = nil
  next_url = nil
  counter = 0

  loop do
    # Use next_url if it exists, otherwise start with the initial URL
    if next_url
      uri = URI(next_url)
    else
      url = "#{API_URL_BASE}#{SEARCH_ENDPOINT}"
      uri = URI(url)
      query_params = query.dup
      uri.query = URI.encode_www_form(query_params)
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Content-Type"] = "application/json"
    request["Shortcut-Token"] = SHORTCUT_TOKEN

    response = http.request(request)

    parsed_response = JSON.parse(response.body)

    # Ensure 'data' is an array before concatenating
    stories.concat(parsed_response["data"] || [])

    # Extract the 'next' parameter value from the URL
    next_token = parsed_response["next"]&.gsub("/api/v3", "")

    if next_token
      next_url = "#{API_URL_BASE}#{next_token}"
      counter += 1
    else
      break
    end
  end

  stories
rescue => e
  puts e
  exit(1)
end

def check_priority(object)
  # This is the mapping of the priority custom field values to the priority level and whether we'll show it in the release notes
  priority_map = {
    "66b9f58d-5129-4d3e-b8c4-12c01193a81a" => ["P0", true]
  }

  # Find the custom field for priority with the specific field_id
  custom_field = object["custom_fields"].find { |field| field["field_id"] == "66a8f58d-cc9a-4416-8e0d-0aaf813696a5" }

  # Extract the value_id from the custom field
  value_id = custom_field ? custom_field["value_id"] : nil

  if priority_map.key?(value_id)
    priority_map[value_id]
  else
    ["N/A", false]
  end
end

def generate_release_notes
  stories = search_stories
  release_notes = []

  # Get all epics for easy mapping
  epics = get_all_epics

  if stories.any?
    puts "Number of stories (pre-filter): #{stories.count}"

  else
    puts "No stories found."
    return
  end

  # Initialize the AI summary class
  ai_summary = AISummary.new

  total_stories = stories.count
  bar_length = 50  # Length of the progress bar

  stories.each_with_index do |story, index|
    # Extract the relevant fields from the story
    completed_at = story["completed_at"]&.split("T")&.first
    story_points = story["estimate"] || "N/A"
    iteration_id = story["iteration_id"]
    epic_id = story["epic_id"] || ""
    group_id = story["group_id"] || ""
    priority = check_priority(story)
    story_id = story["id"]

    # Only add the story to the release notes if the priority is P0, P0.5, P1
    if priority[1] && !iteration_id.nil? && is_valid_group?(group_id)
      # Generate the friendly text for the story only if we want to include it in the release notes
      note = ai_summary.generate_friendly_text(story["name"], story["description"])

      # Add the story to the release notes
      release_notes << ReleaseNote.new(note, priority[0], completed_at, story_points, epics[epic_id], story_id)
    end

    # progress calculation
    progress = (index + 1).to_f / total_stories
    filled_length = (bar_length * progress).round
    bar = "=" * filled_length + "-" * (bar_length - filled_length)

    # progress bar
    print "\rProgress: [#{bar}] #{(progress * 100).round(2)}% (#{index + 1}/#{total_stories})"
    $stdout.flush
  end

  puts # <br> :P

  # Sort the release notes by completed date
  sorted_notes = ReleaseNote.sort_by_epic_name(release_notes)

  # print a slack formatted intro portion
  puts ":green_alert: :green_alert: Please find below the weekly release notes :green_alert: :green_alert:"
  epic_header = ""
  sorted_notes.each do |note|
    if epic_header != note.epic_name
      epic_header = note.epic_name

      # print the epic header
      if epic_header.nil? || epic_header.empty?
        puts "*Other*:"
      else
        puts "*#{epic_header}*:"
      end
    end

    # print the slack formatted release note
    puts "- *#{note.completed_date}*: [*#{note.priority}*] - [#{note.story_id}](https://app.shortcut.com/toursbylocals/story/#{note.story_id}) - #{note.note}"
  end
end

def main
  if SHORTCUT_TOKEN.empty?
    puts "Please get your Shortcut API key and add it to the .env file."
  else
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: release.rb [options]"

      opts.on("-cf", "--custom-fields", "List all Custom Fields") do
        options[:custom_fields] = true
      end

      opts.on("-t", "--teams", "List shortcut teams") do
        options[:teams] = true
      end
    end.parse!

    if options[:custom_fields]
      get_custom_fields
    elsif options[:teams]
      get_teams
    else
      generate_release_notes
    end
  end
end

main if __FILE__ == $PROGRAM_NAME
