IS_DEVELOPMENT = ENV.fetch("IS_DEVELOPMENT") { "" } == "1"

if IS_DEVELOPMENT
  require "dotenv"
  Dotenv.load
else
  $stdout = IO.new(IO.sysopen("/proc/1/fd/1", "w"), "w")
  $stdout.sync = true
end

require "logger"
LOGGER = Logger.new $stdout

if ENV["TZ"] != "Asia/Tokyo"
  LOGGER.info "ENV[\"TZ\"] is not Asia/Tokyo"
  sleep 30
  exit 1
end

SLEEP_SECONDS = ENV.fetch("SLEEP_SECONDS") { "900" }.to_i

LOGGER.info "Start"

require "active_record"
I18n.enforce_available_locales = false
require "uri"
ActiveRecord::Base.establish_connection ENV["DATABASE_URL"]
# This snippet ref. https://gist.github.com/kaosf/f4451b36e55012e6b7d1781e6a88df6a

LOGGER.info "DB setup done"

class NostrEvent < ActiveRecord::Base
  validates :id, presence: true, uniqueness: true
  validates :kind, presence: true
  validates :created_at, presence: true
  validates :body, presence: true
end

require "fileutils"
require "json"
require "cgi"
require "action_view"
require "bech32"
require "erb"

class ContentConverter
  include ActionView::Helpers::SanitizeHelper

  def run(content)
    content = CGI.escapeHTML content
    content.gsub!(%r{(?:https?|ftp)://\S+}, '<a href="\0" target="_blank">\0</a>')
    content.gsub!(/\n/, "<br>")
    sanitize(content, tags: %w[a br])
  end
end

content_converter = ContentConverter.new

class ErbHelper
  def initialize(erb_filepath)
    @template = ERB.new(File.open(erb_filepath).read, trim_mode: "-")
  end

  def run(binding)
    @template.result(binding)
  end
end

loop do
  ids = NostrEvent.select(:id).where(kind: 1).pluck(:id)

  ids.each_slice(1000).with_index do |ids_part, slice_index|
    LOGGER.info "Fetch NostrEvent #{slice_index * 1000}/#{ids.size}"
    nostr_events = NostrEvent.where(id: ids_part)
    nostr_events.each do |nostr_event|
      File.open("data/events/#{nostr_event.id}.json", "w") do |f|
        f.puts nostr_event.body.to_json
      end
    end
  end
  LOGGER.info "Fetch NostrEvent OK"

  ym_to_ids_dictionary = {}
  all_ym = Set.new
  Dir.glob("data/events/*.json") do |filepath|
    event = JSON.parse(File.open(filepath).read)
    created_at = Time.at(event["created_at"])
    year = format "%04d", created_at.year
    month = format "%02d", created_at.month
    ym = "#{year}-#{month}"
    id = event["id"]
    ym_to_ids_dictionary[ym] ||= []
    ym_to_ids_dictionary[ym] << id
    all_ym.add ym
  end
  all_ym = all_ym.to_a.sort

  LOGGER.info "Output index.html"
  output_file = "data/www/index.html"
  File.open(output_file, "w") do |f|
    f.print ErbHelper.new("templates/index.html.erb").run(binding)
  end

  erb_helper = ErbHelper.new("templates/yyyy-mm.html.erb")
  all_ym.each do |ym|
    LOGGER.info "Output #{ym}.html"
    File.open("data/www/#{ym}.html", "w") do |f|
      events = []
      ym_to_ids_dictionary[ym].each do |id|
        event = JSON.parse(File.open("data/events/#{id}.json").read)
        events << event
      end
      events.sort_by! { _1["created_at"] }
      f.print erb_helper.run(binding)
    end
  end

  erb_helper = ErbHelper.new("templates/id.html.erb")
  ids.each.with_index do |id, id_index|
    LOGGER.info "Output NostrEvent #{id_index}/#{ids.size}" if id_index % 1000 == 0

    FileUtils.cp "data/events/#{id}.json", "data/www/#{id}.json"

    event = JSON.parse(File.open("data/events/#{id}.json").read)
    content = content_converter.run(event["content"])
    File.open("data/www/#{id}.html", "w") do |f|
      f.print erb_helper.run(binding)
    end
  end

  exit 0 if ENV["RUN_ONCE"] == "1"

  LOGGER.info "Finished and sleep #{SLEEP_SECONDS} seconds"
  sleep SLEEP_SECONDS
end
