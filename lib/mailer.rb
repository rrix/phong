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

def send_reminder_mail_for wiki_page, config
  print "*** Sending mail ... "
  show_wait_spinner{
    @mailer_config = config
    template = config['template']

    templated =  template.gsub(/\$URL\$/i, wiki_page)
    templated = templated.gsub(/\$GREETING\$/i, greeting)

    header = generate_header

    full_mail = header + templated

    smtp = Net::SMTP.new(config['smtp']['server'],
                         config['smtp']['port'])
    smtp.enable_starttls if config['smtp']['ssl']
    smtp.start( 'localhost',
                config['smtp']['username'],
                config['smtp']['password'],
                :plain) do
      smtp.send_message full_mail, config['smtp']['username'], config['mailing_list']
    end
  }

  puts 'Message sent to mailing list!'
end

def generate_header
  str = <<HEREDOC
From: Phong <#{@mailer_config['smtp']['username']}>
To: #{@mailer_config['mailing_list']}
Subject: Hack Your Hackerspace Meeting Tomorrow!
Date: #{DateTime.now.to_s}

HEREDOC

end

def greeting
  possibilities = [
    "Howdy Hackers!",
    "Greetings!",
    "Hackers, Makers, Doers and Breakers!",
    "Salut, hackers!",
    "INCOMING TRANSMISSION:"
  ]

  possibilities[(rand*possibilities.count).to_i]
end
