#!/bin/env ruby
# vim: set foldmethod=marker foldlevel=0:
require 'yaml'
require './lib/wiki'
require './lib/mailer'

#{{{1 Magick
def get_config
  YAML::load File.open('config.yaml')
end
#}}}1

if next_meeting != Date.today + 1
  # This script runs every wednesday, but we don't have meetings that often, we need to check for that because cron (move to atd?)
  print "Must be an off-week. Our next meeting is #{next_meeting.to_s}, not tomorrow (which is #{(Date.today + 1).to_s})!\n"
  exit 0
end

@config = get_config
send_reminder_mail_for wiki_page, @config['mailer']

#testing
#print send_reminder_mail_for "http://wiki.heatsynclabs.org/wiki/HYH_Meeting_2012-11-08", @config['mailer']

