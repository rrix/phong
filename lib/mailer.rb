# vim: set foldmethod=marker foldlevel=0:
require 'net/smtp'

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

def send_agenda_for url, stuffed_envelopes, config
  print "*** Sending agenda mail ... "
  show_wait_spinner{
    @mailer_config = config

    template = config['agenda_template']

    subjects = stuffed_envelopes.map{|prop| prop['ENVELOPE'].subject} * ", "

    templated =  template.gsub(/\$URL\$/i, wiki_page)
    templated = templated.gsub(/\$GREETING\$/i, greeting)
    templated = templated.gsub(/\$PROPOSALS\$/i, subjects)

    header = generate_agenda_header
    full_mail = header + templated

    send_message full_mail
  }
end

def send_reminder_mail_for wiki_page, config
  print "*** Sending reminder mail ... "
  show_wait_spinner{
    @mailer_config = config
    template = config['reminder_template']

    templated =  template.gsub(/\$URL\$/i, wiki_page)
    templated = templated.gsub(/\$GREETING\$/i, greeting)

    header = generate_reminder_header

    full_mail = header + templated

    send_message full_mail
  }

  puts 'Message sent to mailing list!'
end

def send_message full_mail
    smtp = Net::SMTP.new(@mailer_config['smtp']['server'],
                         @mailer_config['smtp']['port'])
    smtp.enable_starttls if @mailer_config['smtp']['ssl']
    smtp.start( 'localhost',
                @mailer_config['smtp']['username'],
                @mailer_config['smtp']['password'],
                :plain) do
      smtp.send_message full_mail, @mailer_config['smtp']['username'], @mailer_config['mailing_list']
    end
end

def generate_base_header
  str = <<HEREDOC
From: Phong <#{@mailer_config['smtp']['username']}>
To: #{@mailer_config['mailing_list']}
Date: #{DateTime.now.to_s}
HEREDOC
end

def generate_agenda_header
  header = generate_base_header + "Subject: Hack Your Hackerspace Proposals for next week are in!

  "
end

def generate_reminder_header
  header = generate_base_header + "Subject: Hack Your Hackerspace Meeting Tomorrow!

  "
end

def greeting
  possibilities = [
    "Howdy Hackers!",
    "Greetings!",
    "Hackers, Makers, Doers and Breakers!",
    "Salut, hackers!",
    "INCOMING TRANSMISSION:",
    "Namaste hackers!"
  ]

  possibilities[(rand*possibilities.count).to_i]
end
