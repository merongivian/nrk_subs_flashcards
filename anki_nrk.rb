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

def create_anki_cards_by_subs(show:, season:, episode: )
  @anki_subtitles = Anki2.new(name: "#{show}: Season #{season} Episode #{episode}", output_path: "./#{show}_#{season}_#{episode}.apkg")

  prf_id = get_prf_id(show, season, episode)
  prefix = prf_id[0...6]
  cache = prf_id[6...8]

  nrk_subs(prf_id, prefix, cache).each do |sub|
    translation = translate(sub.text)

    p "start: #{sub.start}"
    p "text: #{sub.text}"
    p "translation: #{translation}"
    p "------------------"

    @anki_subtitles.add_card("time: #{sub.start}<br><br>text: #{sub.text}", translation)
  end

  @anki_subtitles.save
end

def get_prf_id(show, season, episode)
  Faraday.get("https://psapi.nrk.no/tv/catalog/series/#{show}")
  .body
  .then(&JSON.method(:parse))
  .then { _1.dig('_embedded', 'seasons', season, '_embedded', 'episodes', episode, 'prfId') }
end

def nrk_subs(prf_id, prefix ,cache )
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

create_anki_cards_by_subs(show: ARGV[0], season: ARGV[1].to_i, episode: ARGV[2].to_i)
