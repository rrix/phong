# vim: set foldmethod=marker foldlevel=0:

require 'media_wiki'
require './lib/proposals'

#{{{1 Magick
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

  return valid_section
end

def generate_wiki_page_from config, proposals
  mw = MediaWiki::Gateway.new "#{config['url']}/w/api.php", {bot: true}
  mw.login(config['username'], config['password'])

  template_page = mw.get config['template']
  section_text = ""

  template_page = template_page.gsub(/\$LAST_MEETING\$/, "HYH Meeting #{last_meeting.to_s}")

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

* '''RESULT: #FIXME#''' <!-- record final verdict and tally of votes -->

"

    section_text += proposal_text
  end

  filled_template = [split[0], section_text, split[1]].join("\n")
  filled_template.gsub(/\$LAST_MEETING\$/, "HYH Meeting #{last_meeting.strftime("%F")}")

  page_name = next_meeting.strftime("HYH Meeting %F")

  new_page = mw.create page_name, filled_template, summary: "Set up meeting page"

  return "#{config['url']}wiki/#{MediaWiki.wiki_to_uri page_name}"
end
#1}}}

#{{{1 Runner
def premeeting_wiki_generation config
  @wiki_config = config
  @proposals = []

  print "*** Fetching proposals since #{ (last_meeting - 7).strftime("%F") } to #{ (next_meeting - 7).strftime("%F")} ... "
  @proposals = show_wait_spinner{
    find_proposals_in messages_since( last_meeting - 7, next_meeting - 6 )
  }
  puts "Done!"

  print "*** Generating wiki page for #{next_meeting.strftime("%F")} ... "
  begin
    show_wait_spinner{
      @page_url = generate_wiki_page_from @wiki_config['wiki'], @proposals
    }
  rescue
    puts "Could not save page!"
    return nil
  end
  puts "Done! Page is at #{@page_url}"

  puts "===== Summary ====="
  print "This week we're voting on: "
  puts @proposals.map{|prop| prop['ENVELOPE'].subject} * ", "
  puts ""
  puts "'Phong, the wise one. It is an honor to finally meet you...'"

  return @page_url
end
#}}}1

