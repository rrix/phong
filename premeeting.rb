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

@config = get_config
#wiki_page = premeeting_wiki_generation @config['wiki']

#send_reminder_mail_for wiki_page, @config['mailer']
print send_reminder_mail_for "http://wiki.heatsynclabs.org/wiki/HYH_Meeting_2012-11-08", @config['mailer']

