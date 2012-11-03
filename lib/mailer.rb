require 'net/smtp'

def send_reminder_mail_for wiki_page, config
  @mailer_config = config
  template = config['template']

  templated =  template.gsub(/\$URL\$/i, wiki_page)
  templated = templated.gsub(/\$GREETING\$/i, greeting)

  header = generate_header

  full_mail = header + templated

  smtp = Net::SMTP.new(config['smtp']['server'],
                       config['smtp']['port'])
  smtp.enable_starttls
  smtp.start( 'localhost',
              config['smtp']['username'],
              config['smtp']['password'],
              :plain) do
    smtp.send_message full_mail, config['smtp']['username'], config['mailing_list']
  end

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
