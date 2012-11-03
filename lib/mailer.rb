require 'net/smtp'

def send_reminder_mail_for wiki_page, config
  template = config['template']

  templated =  template.gsub(/\$URL\$/i, wiki_page)
  templated = templated.gsub(/\$GREETING\$/i, greeting)
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
