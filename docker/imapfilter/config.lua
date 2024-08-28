options.timeout = 30

main_account = IMAP {
    server = os.getenv("MAIN_IMAP"),
    username = os.getenv("MAIN_USER"),
    password = os.getenv("MAIN_PASS"),
    port     = 993,
    ssl      = 'tls13',
}

local other_oauth2 = os.getenv("OTHER_OAUTH2")
if (other_oauth2 ~= nil and other_oauth2 ~= '') then
  other_account = IMAP {
    server   = os.getenv("OTHER_IMAP"),
    username = os.getenv("OTHER_USER"),
    oauth2   = other_oauth2,
    port     = 993,
    ssl      = 'tls13',
  }
else
  other_account = IMAP {
    server = os.getenv("OTHER_IMAP"),
    username = os.getenv("OTHER_USER"),
    password = os.getenv("OTHER_PASS"),
    port     = 993,
    ssl      = 'tls13',
  }
end
results = other_account.INBOX:select_all()
results:move_messages(main_account['INBOX'])

local junk = os.getenv("OTHER_JUNK")
if (junk ~= nil and junk ~= '') then
  results = other_account[junk]:select_all()
  results:move_messages(main_account['Spam'])
end

results = main_account.INBOX:contain_field('List-ID',  'SlackBuildsOrg/slackbuilds')
results:move_messages(main_account['github'])

results = main_account.INBOX:contain_field('List-Id',  'slackbuilds-devel.slackbuilds.org')
results:move_messages(main_account['slackbuilds-devel'])
