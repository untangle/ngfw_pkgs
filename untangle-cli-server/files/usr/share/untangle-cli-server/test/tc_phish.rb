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
  
  def test_SMTP
    # display
    assert_match(/scan,action,description/, @phish.execute(["#1", "SMTP"]), "display SMTP settings")

    # update
    assert_match(/scan for SMTP updated/, @phish.execute(%w(#1 SMTP update scan false)), "update SMTP scan - false")
    assert_match(/false/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/scan for SMTP updated/, @phish.execute(%w(#1 SMTP update scan true)), "update SMTP scan -true")
    assert_match(/true/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/action for SMTP updated/, @phish.execute(%w(#1 SMTP update action mark)), "update SMTP action - mark")
    assert_match(/mark/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/action for SMTP updated/, @phish.execute(%w(#1 SMTP update action quarantine)), "update SMTP action - quarantine")
    assert_match(/quarantine/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/description for SMTP updated/, @phish.execute(%w(#1 SMTP update description test-smtp-description)), "update SMTP description")
    assert_match(/test-smtp-description/, @phish.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @phish.execute(%w(#1 SMTP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are block, mark, quarantine, pass/, @phish.execute(%w(#1 SMTP update action test)), "validation for updating SMAP action")    
  end
  
  def test_POP
    # display
    assert_match(/scan,action,description/, @phish.execute(["#1", "POP"]), "display POP settings")

    # update
    assert_match(/scan for POP updated/, @phish.execute(%w(#1 POP update scan false)), "update POP scan - false")
    assert_match(/false/, @phish.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/scan for POP updated/, @phish.execute(%w(#1 POP update scan true)), "update POP scan -true")
    assert_match(/true/, @phish.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/action for POP updated/, @phish.execute(%w(#1 POP update action mark)), "update POP action - mark")
    assert_match(/mark/, @phish.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/action for POP updated/, @phish.execute(%w(#1 POP update action pass)), "update POP action - pass")
    assert_match(/pass/, @phish.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/description for POP updated/, @phish.execute(%w(#1 POP update description test-pop-description)), "update POP description")
    assert_match(/test-pop-description/, @phish.execute(["#1", "POP"]), "display POP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @phish.execute(%w(#1 POP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are mark, pass/, @phish.execute(%w(#1 POP update action quarantine)), "validation for updating SMAP action")    
  end
  
  def test_IMAP
    # display
    assert_match(/scan,action,description/, @phish.execute(["#1", "IMAP"]), "display IMAP settings")

    # update
    assert_match(/scan for IMAP updated/, @phish.execute(%w(#1 IMAP update scan false)), "update IMAP scan - false")
    assert_match(/false/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/scan for IMAP updated/, @phish.execute(%w(#1 IMAP update scan true)), "update IMAP scan -true")
    assert_match(/true/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/action for IMAP updated/, @phish.execute(%w(#1 IMAP update action mark)), "update IMAP action - mark")
    assert_match(/mark/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/action for IMAP updated/, @phish.execute(%w(#1 IMAP update action pass)), "update IMAP action - pass")
    assert_match(/pass/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/description for IMAP updated/, @phish.execute(%w(#1 IMAP update description test-imap-description)), "update IMAP description")
    assert_match(/test-imap-description/, @phish.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @phish.execute(%w(#1 IMAP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are mark, pass/, @phish.execute(%w(#1 IMAP update action quarantine)), "validation for updating SMAP action")    
  end

  def test_web_settings
    assert_match(/Web anti-phishing protection enabled/, @phish.execute(%w(#1 web true)), "enable web settings")
    assert_match(/Web anti-phishing protection: enabled/, @phish.execute(["#1", "web"]), "display web settings")
    
    assert_match(/Web anti-phishing protection disabled/, @phish.execute(%w(#1 web false)), "disable web settings")
    assert_match(/Web anti-phishing protection: disabled/, @phish.execute(["#1", "web"]), "display web settings")
    
    # validation
    assert_match(/Error: invalid value for 'enable' - valid values are 'true' and 'false'/, @phish.execute(%w(#1 web xyz)), "validation for updating web")    
  end

end
