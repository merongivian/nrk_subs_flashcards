require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'anki2'
  gem 'anki'
  gem 'faraday'
  gem 'webvtt-ruby'
  gem 'dotenv'
end

require 'dotenv'; Dotenv.load
require 'anki2'
require 'anki'
require "faraday"
require "json"
require "webvtt"

def create_anki_cards_by_subs(show:, season:, episode: )
  anki_subtitles = Anki2.new(name: "#{show}: Season #{season} Episode #{episode}", output_path: "./#{show}_#{season}_#{episode}.apkg")

  prf_id = get_prf_id(show, season, episode)

  nrk_subs(prf_id).each do |sub|
    translation = translate(sub.text)

    p "start: #{sub.start}"
    p "text: #{sub.text}"
    p "translation: #{translation}"
    p "------------------"

    anki_subtitles.add_card("time: #{sub.start}<br><br>text: #{sub.text}", translation)
  end

  anki_subtitles.save
end

def create_anki_cards_by_words(show:, season:, episode: )
  prf_id = get_prf_id(show, season, episode)

  # cleanup: get rid of easy words, duplicates, etc
  words = nrk_subs(prf_id)
    .map(&:text)
    .map { _1.gsub(/[^a-zA-Z]/, " ") }
    .map(&:split)
    .flatten
    .map(&:downcase)
    .map(&:strip)
    .uniq
    .select { _1.length > 3 }

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

if ARGV[3] == 'words'
  create_anki_cards_by_words(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
else
  create_anki_cards_by_subs(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
end

