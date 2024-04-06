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

LOGGER.level = ENV.fetch("LOG_LEVEL") { "info" }.to_sym

SLEEP_SECONDS = ENV.fetch("SLEEP_SECONDS") { "900" }.to_i

LOGGER.info "Start"

require "active_record"
I18n.enforce_available_locales = false
require "uri"
# This snippet ref. https://gist.github.com/kaosf/f4451b36e55012e6b7d1781e6a88df6a

ActiveRecord::Base.logger = Logger.new($stdout) if IS_DEVELOPMENT && (ENV.fetch("OUTPUT_SQL") { "" } == "1")

module Source
  class NostrEvent < ActiveRecord::Base
    establish_connection ENV["DATABASE_URL"]

    validates :id, presence: true, uniqueness: true
    validates :kind, presence: true
    validates :created_at, presence: true
    validates :body, presence: true
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(adapter: "sqlite3", database: "data/database.sqlite3")
end

File.open("setup.sql").read.split(";").map(&:strip).reject(&:empty?).each do |query|
  ApplicationRecord.connection.execute query
end

LOGGER.info "DB setup done"

class NostrEvent < ApplicationRecord
  has_many :urls
end

class Url < ApplicationRecord
  belongs_to :nostr_event
  has_many :images
  validates :body, uniqueness: { scope: :nostr_event_id }
end

class Image < ApplicationRecord
  belongs_to :url
end

require "fileutils"
require "json"
require "cgi"
require "action_view"
require "bech32"
require "erb"
require "open-uri"

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

def download_and_get_checksum(url)
  LOGGER.info "Sleep 1 second before download; URL: #{url}"
  sleep 1
  File.open("data/img/tmp", "wb") { |fo| fo.write URI.parse(url).read }
  sha256 = Digest::SHA256.file("data/img/tmp").to_s
  FileUtils.mv("data/img/tmp", "data/img/#{sha256}")
  sha256
end

FileUtils.mkdir_p "data/img"
LOGGER.info "Create data/img done"

loop do
  ids = Source::NostrEvent.select(:id).where(kind: 1).pluck(:id)

  ids.each_slice(1000).with_index do |ids_part, slice_index|
    LOGGER.info "Fetch NostrEvent #{slice_index * 1000}/#{ids.size}"
    nostr_events = Source::NostrEvent.where(id: ids_part)
    nostr_events.each do |ne| # nostr event
      next unless NostrEvent.find_by(id: ne.id).nil?

      NostrEvent.create(id: ne.id, kind: ne.kind, created_at: ne.created_at, body: ne.body.to_json)
    end
  end
  LOGGER.info "Fetch NostrEvent OK"

  NostrEvent.order(created_at: :asc).each do |ne| # nostr event
    image_urls = []
    JSON.parse(ne.body)["content"].scan(%r{(?:https?)://\S+}) do |match|
      url = Url.find_or_create_by nostr_event_id: ne.id, body: match

      image_urls << url if match.include?("nostr.build")
    end

    image_urls.each do |url|
      LOGGER.debug url
      image = Image.find_by(url_id: url.id)

      if image.nil?
        sha256 = download_and_get_checksum(url.body)
        Image.create(url_id: url.id, sha256:)
      else
        sha256 = image.sha256
        unless File.exist?("data/img/#{sha256}")
          sha256_real = download_and_get_checksum(url.body)
          if sha256 != sha256_real
            LOGGER.info "Downloaded file's SHA256: #{sha256_real} != recorded SHA256: #{sha256}; Update to the new one."
            url_to_checksum.update(sha256: sha256_real)
          end
        end
      end
    end
  end

  ym_to_ids_dictionary = {}
  all_ym = Set.new
  NostrEvent.select(:id, :created_at).each do |nostr_event|
    created_at = Time.at(nostr_event.created_at)
    year = format "%04d", created_at.year
    month = format "%02d", created_at.month
    ym = "#{year}-#{month}"
    id = nostr_event.id
    ym_to_ids_dictionary[ym] ||= []
    ym_to_ids_dictionary[ym] << id
    all_ym.add ym
  end
  all_ym = all_ym.to_a.sort

  LOGGER.info "Output index.html"
  File.open("data/www/index.html", "w") do |f|
    f.print ErbHelper.new("templates/index.html.erb").run(binding)
  end

  erb_helper = ErbHelper.new("templates/yyyy-mm.html.erb")
  all_ym.each do |ym|
    LOGGER.info "Output #{ym}.html"
    File.open("data/www/#{ym}.html", "w") do |f|
      events = []
      ym_to_ids_dictionary[ym].each do |id|
        event = JSON.parse(NostrEvent.find(id).body)
        events << event
      end
      events.sort_by! { _1["created_at"] }
      f.print erb_helper.run(binding)
    end
  end

  erb_helper = ErbHelper.new("templates/id.html.erb")
  ids.each.with_index do |id, id_index|
    LOGGER.info "Output NostrEvent #{id_index}/#{ids.size}" if id_index % 1000 == 0

    event = NostrEvent.find(id).body
    unless File.exist?("data/www/#{id}.json")
      File.open("data/www/#{id}.json", "w") do |f|
        f.print event
      end
    end

    event = JSON.parse(event)
    content = content_converter.run(event["content"])
    File.open("data/www/#{id}.html", "w") do |f|
      f.print erb_helper.run(binding)
    end
  end

  exit 0 if ENV["RUN_ONCE"] == "1"

  LOGGER.info "Finished and sleep #{SLEEP_SECONDS} seconds"
  sleep SLEEP_SECONDS
end
