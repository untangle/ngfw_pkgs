$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'spamblocker'

#DEFAULT_DIAG_LEVEL = 0

class TestSpamblocker < Test::Unit::TestCase
  def setup
    @spamblocker = SpamBlocker.new
  end

  def test_help
    assert_match(/spamblocker -- enumerate all/, @spamblocker.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/spamblocker -- enumerate all/, @spamblocker.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @spamblocker.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @spamblocker.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_display_settings
    assert_match(/scan,strength,action,tarpit,description/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings")
    assert_match(/SMTP/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings")
    
    assert_match(/scan,strength,action,description/, @spamblocker.execute(["#1", "POP"]), "display POP settings")
    assert_match(/POP/, @spamblocker.execute(["#1", "POP"]), "display POP settings")
    
    assert_match(/scan,strength,action,description/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings")
    assert_match(/IMAP/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings")
  end
  
  def test_update_settings
    assert_match(/scan for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update scan false)), "update SMAP scan")
    
    assert_match(/strength for POP updated/, @spamblocker.execute(%w(#1 POP update strength extreme)), "update POP strength")
    assert_match(/extreme/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/action for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update action quarantine)), "update SMTP action")
    assert_match(/quarantine/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/action for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update action pass)), "update IMAP action")
    assert_match(/pass/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/tarpit for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update tarpit true)), "update SMTP tarpit")
    
    assert_match(/description for POP updated/, @spamblocker.execute(%w(#1 POP update description test-description)), "update POP description")
    assert_match(/test-description/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
  end

  def test_validation
    # TODO
  end
end
