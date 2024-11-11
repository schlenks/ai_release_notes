require "openai"
require "dotenv/load"

class AISummary
  OPENAI_API_KEY = ENV["OPENAI_API_KEY"] || ""
  OPENAI_MODEL = "gpt-4o"
  OPENAI_URL = "https://api.openai.com/v1/chat/completions"
  LMSTUDIO_URL = "http://localhost:1234"

  # use whatever model you want - this is the latest llama model for Apple Silicon
  LMSTUDIO_MODEL = "mlx-community/llama-3.2-3b-instruct"

  def initialize
    if OPENAI_API_KEY.empty?
      @client = OpenAI::Client.new(uri_base: LMSTUDIO_URL)
    end
  end

  def generate_friendly_text(title, description)

    # adjust the prompt as you see fit
    prompt = "You are a product manager skilled at taking release notes and translating them into easy
    to understand language for less technical people to read and understand. The original note may be
    long and technical, it's your job to make it concise and easy to understand what was fixed, added,
    improved or changed. In many cases the description will contain text that details what the expected
    fix or solution should be, you can leverage that as helpful context in your output. Your output
    should take everything and encapsulate it in a single sentence. Skip all niceties and only
    respond back with the improved text for the user. Answer with only the final answer, without any
    introductory phrases like 'Here is a concise version', 'Here's a concise and easy-to-understand version of the release notes:'
    'Here's a single sentence explaining the changes:', 'Here is the corrected edit request in a single sentence:' or similar."

    messages = [
      {role: "system", content: prompt},
      {role: "user", content: "Title: #{title}\nDescription: #{description}"}
    ]

    response = @client.chat(
      parameters: {
        model: OPENAI_API_KEY.empty? ? LMSTUDIO_MODEL : OPENAI_MODEL,
        messages: messages,
        # temperature is a range from 0.0 to 1.0, the higher the number, the more creative the output.
        # 0.2 is a good starting point for this prompt so it takes less creative liberties.
        temperature: 0.2
      }
    )
    response.dig("choices", 0, "message", "content")
  end
end
