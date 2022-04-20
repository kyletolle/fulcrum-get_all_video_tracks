# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'json'
require 'shellwords'

require 'dotenv'
Dotenv.load
require 'fastenv'

require 'fulcrum'

class Fulcrum::VideoTrackDownloader
  def download_gpx_tracks
    download_tracks(:gpx)
  end

  def download_geojson_tracks
    download_tracks(:geojson) do |video_key, track_geojson_string|
      geojson = track_geojson_string.to_json
      validate_response = `curl --data #{geojson.to_s.shellescape} http://geojsonlint.com/validate 2> /dev/null`
      validate_hash = JSON.parse(validate_response)
      case validate_hash["status"]
      when "ok"
        geojson
      else
        puts "Invalid track for video #{video_key} won't be written:"
        puts validate_hash
        nil
      end
    end
  end

private

  def client
    @client ||= Fulcrum::Client.new(Fastenv.fulcrum_api_key)
  end

  def all_videos
    client.videos.all(page: 1, per_page: 1000).objects
      .tap do |videos_array|
        def videos_array.with_track
          self.select{|v| v["track"]}
        end
      end
  end

  def keys_for_videos_with_tracks
    all_videos.with_track.map{|v| v["access_key"]}
  end

  def fetch_tracks(format, &block)
    keys_for_videos_with_tracks
      .map do |video_key|
        begin
          #TODO: Should be able to soon change this to:
          #track_data = client.videos.track(video_key, format.to_s)
          track_data = client.videos.call(:get, client.videos.member_action(video_key, 'track', format.to_s))
        rescue Faraday::ClientError
          puts "Problem fetching track for video #{video_key}"
          next
        end

        yield video_key, track_data

        track_data
      end
  end

  def download_tracks(format, &block)
    fetch_tracks(format) do |video_key, track_data|
      track_file_name = "track_#{video_key}.#{format.to_s}"
      track_file_path = File.join(Fastenv.track_save_path, track_file_name)

      track_data =
        if block_given?
          yield video_key, track_data
        else
          track_data
        end

      next if track_data.nil?

      File.open(track_file_path, 'w') do |track_file|
        track_file.write(track_data)
      end
    end
  end
end

Fulcrum::VideoTrackDownloader.new.download_geojson_tracks

