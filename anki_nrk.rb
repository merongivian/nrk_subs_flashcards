require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'anki2'
  gem 'faraday'
  gem 'webvtt-ruby'
  gem 'dotenv'
end

require 'dotenv'; Dotenv.load
require 'anki2'
require "faraday"
require "json"
require "webvtt"

def create_anki_cards_for_episode(show:, season:, episode: )
  @anki = Anki2.new(name: "#{show}: Season #{season} Episode #{episode}", output_path: "./#{show}_#{season}_#{episode}.apkg")

  Faraday.get("https://psapi.nrk.no/tv/catalog/series/#{show}")
  .body
  .then(&JSON.method(:parse))
  .then { _1.dig('_embedded', 'seasons', season, '_embedded', 'episodes', episode, 'prfId') }
  .then do |prf_id|
    prefix = prf_id[0...6]
    cache = prf_id[6...8]

    create_anki_cards_for_subs(prf_id: , prefix: , cache: )
    @anki.save
  end
end

def create_anki_cards_for_subs(prf_id:, prefix: ,cache: )
  link = "https://undertekst.nrk.no/prod/%{prefix}/%{dir}/%{prfid}/%{lang}/%{prfid}.vtt"
  real_link = link % {prfid: prf_id, prefix: prefix, dir: cache, lang: "TTV"}
  subs = Faraday.get(real_link).body

  WebVTT.from_blob(subs).cues.each do |cue|
    translation = translate(cue.text)

    p "start: #{cue.start}"
    p "text: #{cue.text}"
    p "translation: #{translation}"
    p "------------------"

    @anki.add_card("start: #{cue.start}<br>text: #{cue.text}", translation)
  end
end

def translate(text)
  params = { key: ENV['GOOGLE_TRANSLATIONS_API_KEY'], q: text, source: 'no', target: 'en' }

  Faraday.get("https://translation.googleapis.com/language/translate/v2", params)
  .body
  .then(&JSON.method(:parse))
  .dig('data', 'translations')
  .first['translatedText']
end

create_anki_cards_for_episode(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
