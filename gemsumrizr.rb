#!/usr/bin/env ruby
require 'rubygems'
require File.join(File.dirname(__FILE__), 'secretz')
require 'twitter'
require 'typhoeus'
require 'googl'
require 'nokogiri'

Twitter.configure do |config|
  config.consumer_key = CONSUMER_KEY
  config.consumer_secret = CONSUMER_SECRET
  config.oauth_token = OAUTH_TOKEN
  config.oauth_token_secret = OAUTH_TOKEN_SECRET
end

last_run_file = File.join(File.dirname(__FILE__), 'last_run')

last_run = ''
File.open(last_run_file, 'r') do |f|
  last_run = f.gets
  if last_run.to_s != ''
    last_run = DateTime.parse(last_run)
  end
end

posts = []

hydra = Typhoeus::Hydra.new

Twitter.user_timeline('rubygems').each do |p|
  created_at = DateTime.parse(p.created_at)
  if !last_run || created_at > last_run
    url_regexp = /http:\/\/.*/
    url = p.text.match(/http:\/\/.*/)[0]
    #because ln-s.net urls aren't always parsed correctly by twitter
    new_url = Googl.shorten(url).short_url
    post = {:text => p.text.gsub(url, new_url), :url => url}

    rubygems_request = Typhoeus::Request.new(url, :follow_location => true)
    rubygems_request.on_complete do |response|
      begin
        summary = Nokogiri::HTML(response.body).css('#markup').first.text.strip
        post[:summary] =  summary
        posts << post
      rescue
      end
    end
    hydra.queue rubygems_request
  end
end

hydra.run

client = Twitter::Client.new

posts.each do |post|
  new_text = "#{post[:text]} #{post[:summary]}"
  if new_text.length > 140
    new_text = new_text[0,139] + "-"
  end

  client.update(new_text)
end

File.open(last_run_file, 'w') do |f|
  f.puts(DateTime.now.to_s)
end
