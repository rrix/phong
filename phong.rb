#!/bin/env ruby
# vim: set foldmethod=marker foldlevel=0:

require 'yaml'
require 'chronic'
require 'net/imap'
require 'media_wiki'
require 'pry'

#{{{1 Magick
def get_config
  YAML::load File.open('config.yaml')
end

def show_wait_spinner(fps=5)
  chars = %w[ | / - \\ ]
  delay = 1.0/fps
  iter = 0
  spinner = Thread.new do
    while iter do  # Keep spinning until told otherwise
      print chars[(iter+=1) % chars.length]
      sleep delay
      print "\b"
    end
  end
  yield.tap{       # After yielding to the block, save the return value
    iter = false   # Tell the thread to exit, cleaning up after itself…
    spinner.join   # …and wait for it to do so.
  }                # Use the block's return value as the method's
end
#1}}}

#{{{1 Message fetching
def messages_since since = last_meeting - 7, before = next_meeting - 7
  messages = []

  imap = Net::IMAP.new( @config['imap']['server'], @config['imap']['port'], @config['imap']['ssl'])
  imap.login @config['imap']['username'], @config['imap']['password']
  imap.examine @config['imap']['mailbox']
  imap.search(["SINCE", since.strftime("%e-%b-%Y"),
               "BEFORE", before.strftime("%e-%b-%Y"),
               "SUBJECT", "PROPOSAL\: "]).each do |message_id|
    data = imap.fetch(message_id, ["ENVELOPE", "BODY[]"])
    message = {}
    message['ENVELOPE'] = data[0].attr["ENVELOPE"]
    message['BODY'] = data[0].attr["BODY[]"]

    messages << message
  end

  return messages
end

def find_proposals_in messages
  proposals = []

  messages.each do |message|
    envelope = message['ENVELOPE']

    if message_to_group envelope
      if envelope.subject =~ /PROPOSAL:/i
        # Filter replies
        unless envelope.subject =~ /Re:/i
          envelope.subject = clean_subject_of( envelope )

          next if @config['past_proposals'].index(envelope.subject) != nil
          next if DateTime.parse(envelope.date) < last_meeting - 7
          next if DateTime.parse(envelope.date) > next_meeting - 7

          proposals << message
          @config['past_proposals'] << envelope.subject
        end
      end
    end
  end

  proposals
end

def clean_subject_of envelope
  subject = envelope.subject

  cleaned = subject.gsub(/(Re: ?)/i, "")
  cleaned = cleaned.gsub(/(\[HSL\] ?)/, "")
  cleaned = cleaned.gsub(/(PROPOSAL: ?)/i, "")

  return cleaned
end

def message_to_group envelope
  if envelope.cc
    envelope.cc.each do |rcpt|
      return true if "#{rcpt.mailbox}@#{rcpt.host}" == @config['mailing_list']
    end
  end

  if envelope.to
    envelope.to.each do |rcpt|
      return true if "#{rcpt.mailbox}@#{rcpt.host}" == @config['mailing_list']
    end
  end

  false
end
# }}}1

#{{{1 Find meetings logic
#last_meeting = Date.parse(@config['last_meeting'])
def first_thursday month_date
  first_thursday = Date.new(month_date.year, month_date.month, 1)

  while not first_thursday.thursday?
    first_thursday = first_thursday+1
  end 

  return first_thursday
end

def second_thursday month = Date.today
  first_thursday(month) + 7
end

def fourth_thursday month = Date.today
  first_thursday(month) + 21
end

def last_meeting
  if (second_thursday <=> Date.today) == -1
    last_meeting = second_thursday
  elsif (fourth_thursday <=> Date.today) == -1
    last_meeting = fourth_thursday
  else
    last_meeting = fourth_thursday( Date.today << 1 )
  end
end

def next_meeting
  if (second_thursday <=> Date.today) == 1
    next_meeting = second_thursday
  elsif (fourth_thursday <=> Date.today) == 1
    next_meeting = fourth_thursday
  else
    next_meeting = fourth_thursday( Date.today << 1 )
  end
end
#}}}1

#{{{1 Setup Wiki Pages
def strip_headers body
  new_body = body.split("\r\n\r\n")
  new_body.shift
  
  new_body.join("\r\n\r\n")
end

def get_first_part body
  seperator = /--(.*)$/.match(body)[0]

  sections = body.split(seperator)

  valid_section = ""
  #find the valid section
  sections.each do |section|
    if section =~ /text\/plain/
      valid_section = section
      break
    end
  end

  ary = valid_section.split("\r\n\r\n")
  ary.shift

  valid_section = ary.join("\r\n\r\n")

  binding.pry
  return valid_section
end

def generate_wiki_page_from config, proposals
  mw = MediaWiki::Gateway.new config['url'], {bot: true}
  mw.login(config['username'], config['password'])

  template_page = mw.get config['template']
  section_text = ""

  template_page.gsub(/\$LAST_MEETING\$/, "HYH Meeting #{last_meeting.to_s}")

  # Transform template_page
  split = template_page.split("$PROPOSALS$")

  proposals.each do |proposal|
    envelope = proposal["ENVELOPE"]
    body     = proposal["BODY"]

    proposal_text = "
=== #{envelope.subject} ===

* Proposal by '''#{envelope.from[0].name}'''
* Proposed on '''#{envelope.date}'''

<pre>
#{get_first_part strip_headers body}
</pre>

==== Discussion ====
<!-- note any discussion here, preferably with attribution of discussers -->

* '''RESULT: #FIXME#''' <!-- recrod final verdict and tally of votes -->

"

    section_text += proposal_text
  end

  filled_template.gsub(/\$LAST_MEETING\$/, "HYH Meeting #{last_meeting.strftime("%F")}"

  filled_template = [split[0], section_text, split[1]].join("\n")

  new_page = mw.create next_meeting.strftime("HYH Meeting %F"), filled_template, summary: "Set up meeting page"
end
#1}}}

@config = get_config
@proposals = []

print "*** Fetching proposals since #{ (last_meeting - 7).strftime("%F") } to #{ (next_meeting - 7).strftime("%F")} ... "
#FIXME: messages a week before this meeting aren't valid
@proposals = show_wait_spinner{
  find_proposals_in messages_since( last_meeting - 7, Date.today )
}
puts "Done!"

print "*** Generating wiki page for #{next_meeting.strftime("%F")} ... "
#begin
#show_wait_spinner{
  generate_wiki_page_from @config['wiki'], @proposals
#}
#rescue
#  puts "Could not save page!"
#end
puts "Done!"

puts "===== Summary ====="
print "This week we're voting on: "
puts @proposals.map{|prop| prop['ENVELOPE'].subject} * ", "
puts ""
puts "'Phong, the wise one. It is an honor to finally meet you...'"

