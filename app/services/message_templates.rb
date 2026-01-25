module MessageTemplates
  GLOBAL_MENU = <<~TEXT.strip
    Welcome to CoverText! 📋

    Reply with:
    • CARD - Get your insurance card
    • EXPIRING - Check policy expiration dates
    • HELP - Show this menu again

    What can I help you with today?
  TEXT

  GLOBAL_MENU_SHORT = <<~TEXT.strip
    Reply: CARD, EXPIRING, or HELP
  TEXT
end
