require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'anki2'
  gem 'anki'
  gem 'faraday'
  gem 'webvtt-ruby'
  gem 'ruby-openai'
  gem 'dotenv'
end

require 'dotenv'; Dotenv.load
require 'anki2'
require 'anki'
require "faraday"
require "json"
require "webvtt"
require 'openai'

def create_anki_cards_by_subs(show:, season:, episode: )
  anki_subtitles = Anki2.new(name: "#{show}: Season #{season} Episode #{episode}", output_path: "./#{show}_#{season}_#{episode}.apkg")

  prf_id = get_prf_id(show, season, episode)

  p "filtering subs..."
  remove_easy_subs(nrk_subs(prf_id)).each do |sub_text|
    translation = translate(sub_text)

    p "text: #{sub_text}"
    p "translation: #{translation}"
    p "------------------"

    anki_subtitles.add_card(sub_text, translation)
  end

  anki_subtitles.save
end

def create_anki_cards_by_words(show:, season:, episode: )
  prf_id = get_prf_id(show, season, episode)

  p 'fetching words...'
  # cleanup: gets rid of easy words, duplicates, etc
  words = nrk_subs(prf_id)
    .map(&:text)
    .map { _1.gsub(/[^a-zA-Z]/, " ") }
    .map(&:split)
    .flatten
    .map(&:downcase)
    .map(&:strip)
    .uniq
    .select { _1.length > 3 }
    .then(&method(:remove_easy_words))
    .split(", ")

  card_headers = [ "front", "back" ]

  p "translating words..."
  card_data = words.map do |word|
    { "front" => word, "back" => translate(word) }
  end

  p "generating anki deck"
  Anki::Deck.new(card_headers:, card_data: ).generate_deck(file: './norwegian_words.txt')
  p "done"
end

def get_prf_id(show, season, episode)
  Faraday.get("https://psapi.nrk.no/tv/catalog/series/#{show}")
  .body
  .then(&JSON.method(:parse))
  .then { _1.dig('_embedded', 'seasons', season, '_embedded', 'episodes', episode, 'prfId') }
end

def nrk_subs(prf_id)
  prefix = prf_id[0...6]
  cache = prf_id[6...8]

  link = "https://undertekst.nrk.no/prod/%{prefix}/%{dir}/%{prfid}/%{lang}/%{prfid}.vtt"
  real_link = link % {prfid: prf_id, prefix: prefix, dir: cache, lang: "TTV"}
  subs = Faraday.get(real_link).body

  WebVTT.from_blob(subs).cues
end

def translate(text)
  params = { key: ENV['GOOGLE_TRANSLATIONS_API_KEY'], q: text, source: 'no', target: 'en' }

  Faraday.get("https://translation.googleapis.com/language/translate/v2", params)
  .body
  .then(&JSON.method(:parse))
  .dig('data', 'translations')
  .first['translatedText']
end

def remove_easy_words(words)
  chat_question = "act as a norwegian student with an a2 level. "\
                  "Which of this words are likely new words for you?: #{words.join(" ")}. "\
                  "Only give me the words as an answer, separated by commas. no smart bot response text."\
                  "Remove words that are in english or in other languages that are not norwegian as well. "\
                  #"Return only the 40 most difficult words."

  ask_chat_gpt(chat_question)
end

def remove_easy_subs(subs)
  chat_question = "act as a norwegian student with an a2 level that wants to study words from subtitles "\
                  "on a norwegian tv show. Which of these groups of subtitles are likely difficult to understand for you?: #{subs.map(&:text).join(';')}."\
                  "Each group of subtitles is separated with the ; character. Return the group of subtitles separated with the character ; as well. "\
                  "Only return the grouped subtitles separated by ;, no enumeration, no smart bot response text, because i want to use this output as a"\
                  "csv file."\
                  "Return only the 20 most difficult groups of subtitles."

  ask_chat_gpt(chat_question).split(";")
end

def ask_chat_gpt(question)
  chatgpt = OpenAI::Client.new(access_token: ENV['OPENAI_TOKEN'])
  chatgpt.chat(
  parameters: {
    model: "gpt-3.5-turbo",
    messages: [{ role: "user", content: question}],
    temperature: 0.7,
  }).dig("choices", 0, "message", "content")
end

if ARGV[3] == 'words'
  create_anki_cards_by_words(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
else
  create_anki_cards_by_subs(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
end

