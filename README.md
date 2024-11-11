# Shortcut.com AI Release Notes

This repository contains a Ruby script `release.rb` that generates release notes from Shortcut stories. The script fetches stories, processes them, and outputs a formatted list of release notes.

## Prerequisites

- Ruby (version 2.5 or higher)
- Bundler
- A Shortcut API token (you can get one [here](https://app.shortcut.com/toursbylocals/settings/account/api-tokens))
- An OpenAI API key OR a running local [LM Studio](https://lmstudio.ai) instance

## Installation

1. Clone the repository:

   ```sh
   git clone https://github.com/yourusername/ai_release_notes.git
   cd ai_release_notes
   ```

2. Install the required gems:

   ```sh
   bundle install
   ```

3. Create a `.env` file in the root directory and add your Shortcut API token:

   ```sh
   SHORTCUT_TOKEN=your_shortcut_api_token
   OPENAI_API_KEY=your_openai_api_key
   ```

   If you don't have an OpenAI API key, you can run a local LM Studio instance and leave the `OPENAI_API_KEY` blank.

## Usage

The `release.rb` script provides several command line options to interact with the Shortcut API and generate release notes.

Pre-Requisites before running the script:

1. This script is designed to use shortcut.com "groups" (aka teams) to determine which stories to include in the release notes. By default though, it will include all stories in the release notes. If you would like to have group/team filtering, set the constant `USE_TEAMS` at the top of `release.rb` to `TRUE`, then run `ruby release.rb -t` to list all teams and their IDs. Then add the group IDs to the `valid_groups` hash.
2. The script uses the shortcut.com custom field "priority" to add the value into the release note. Run the script with the `-cf` or `--custom-fields` flag to list all custom fields and their IDs. Then add the custom field `Priority` name, ID and the true/false value to the `priority_map` hash in the `check_priority`. Set the `true` value to `true` if you want the priority to be included in the release notes, and `false` if you don't.

## Running the script

`ruby release.rb`
