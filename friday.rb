#!/bin/env ruby
# vim: set foldmethod=marker foldlevel=0:
require 'yaml'
require './lib/wiki'
require './lib/proposals'
require './lib/mailer'

#{{{1 Magick
def get_config
  YAML::load File.open('config.yaml')
end
#}}}1

@config = get_config

# This script runs every Friday; if the last meeting was yesterday we need
# to send minutes; otherwise we need to send out the agenda'd proposals and
# set up the wiki pages since voting is in 6 days
if last_meeting == Date.today - 1
  url = "#{@config['wiki']['wiki']['url']}#{last_meeting.to_s}"
  binding.pry

  send_minutes_for url
  exit
elsif next_meeting == Date.today + 6
  wiki_page = premeeting_wiki_generation @config['wiki']

  # mailer
  send_agenda_for wiki_page, messages_since(last_meeting - 7), @config['mailer']

  exit
end

puts "I shouldn't be here, kill me!"
exit

