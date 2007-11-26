$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'phish'

#DEFAULT_DIAG_LEVEL = 0

class TestPhish < Test::Unit::TestCase
  def setup
    @phish = Phish.new
  end

  def test_help
    assert_match(/phish -- enumerate all/, @phish.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/phish -- enumerate all/, @phish.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @phish.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @phish.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_display_settings
    assert_match(/scan,action,description/, @phish.execute(["#1", "SMTP"]), "display SMTP settings")
    assert_match(/SMTP/, @phish.execute(["#1", "SMTP"]), "display SMTP settings")
    
    assert_match(/scan,action,description/, @phish.execute(["#1", "POP"]), "display POP settings")
    assert_match(/POP/, @phish.execute(["#1", "POP"]), "display POP settings")
    
    assert_match(/scan,action,description/, @phish.execute(["#1", "IMAP"]), "display IMAP settings")
    assert_match(/IMAP/, @phish.execute(["#1", "IMAP"]), "display IMAP settings")
  end
  
  def test_update_settings
    assert_match(/scan for SMTP updated/, @phish.execute(%w(#1 SMTP update scan false)), "update SMAP scan")
    
    assert_match(/action for SMTP updated/, @phish.execute(%w(#1 SMTP update action quarantine)), "update SMTP action")
    assert_match(/quarantine/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/action for IMAP updated/, @phish.execute(%w(#1 IMAP update action pass)), "update IMAP action")
    assert_match(/pass/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/description for POP updated/, @phish.execute(%w(#1 POP update description test-description)), "update POP description")
    assert_match(/test-description/, @phish.execute(["#1", "POP"]), "display POP settings after update")
  end

  def test_web_settings
    assert_match(/Web anti-phishing protection enabled/, @phish.execute(%w(#1 web true)), "enable web settings")
    assert_match(/Web anti-phishing protection: enabled/, @phish.execute(["#1", "web"]), "display web settings")
    
    assert_match(/Web anti-phishing protection disabled/, @phish.execute(%w(#1 web false)), "disable web settings")
    assert_match(/Web anti-phishing protection: disabled/, @phish.execute(["#1", "web"]), "display web settings")
  end

  def test_validation
    # TODO
  end
end
