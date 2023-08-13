options.timeout = 30

main_account = IMAP {
    server = os.getenv("MAIN_IMAP"),
    username = os.getenv("MAIN_USER"),
    password = os.getenv("MAIN_PASS"),
    port     =  993,
    ssl      = 'tls13',
}

other_account = IMAP {
  server = os.getenv("OTHER_IMAP"),
  username = os.getenv("OTHER_USER"),
  password = os.getenv("OTHER_PASS"),
  port     =  993,
  ssl      = 'tls13',
}
results = other_account.INBOX:select_all()
results:move_messages(main_account['INBOX'])
