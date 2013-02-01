# vim: set foldmethod=marker foldlevel=0:
require 'net/imap'
require 'pry'
 
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

#{{{1 Message fetching
def messages_since since = last_meeting - 7, before = next_meeting - 6
  @since = since
  @before = before
  messages = []

  imap = Net::IMAP.new( @wiki_config['imap']['server'], @wiki_config['imap']['port'], @wiki_config['imap']['ssl'])
  imap.login @wiki_config['imap']['username'], @wiki_config['imap']['password']
  imap.examine @wiki_config['imap']['mailbox']
  imap.search(["SUBJECT", "PROPOSAL\: "]).each do |message_id|
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

          next if @wiki_config['past_proposals'].index(envelope.subject) != nil
          next if DateTime.parse(envelope.date) < @since
          next if DateTime.parse(envelope.date) > @before

          proposals << message
          @wiki_config['past_proposals'] << envelope.subject
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
      return true if "#{rcpt.mailbox}@#{rcpt.host}" == @wiki_config['mailing_list']
    end
  end

  if envelope.to
    envelope.to.each do |rcpt|
      return true if "#{rcpt.mailbox}@#{rcpt.host}" == @wiki_config['mailing_list']
    end
  end

  false
end
# }}}1

#{{{1 Find meetings logic
#last_meeting = Date.parse(@wiki_config['last_meeting'])
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

