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

  def test_SMTP
    # display
    assert_match(/scan,strength,action,tarpit,description/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings")

    # update
    assert_match(/scan for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update scan false)), "update SMTP scan - false")
    assert_match(/false/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/scan for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update scan true)), "update SMTP scan -true")
    assert_match(/true/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/strength for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update strength low)), "update SMTP strength - low")
    assert_match(/low/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/strength for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update strength very-high)), "update SMTP strength - very-high")
    assert_match(/very high/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/action for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update action mark)), "update SMTP action - mark")
    assert_match(/mark/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/action for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update action quarantine)), "update SMTP action - quarantine")
    assert_match(/quarantine/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/tarpit for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update tarpit false)), "update SMTP tarpit - false")
    assert_match(/false/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/tarpit for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update tarpit true)), "update SMTP tarpit -true")
    assert_match(/true/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/description for SMTP updated/, @spamblocker.execute(%w(#1 SMTP update description test-smtp-description)), "update SMTP description")
    assert_match(/test-smtp-description/, @spamblocker.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @spamblocker.execute(%w(#1 SMTP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'strength' - valid values are medium, high, extreme, very-high, low/, @spamblocker.execute(%w(#1 SMTP update strength test)), "validation for updating SMAP strength")    
    assert_match(/Error: invalid value for 'action' - valid values are block, mark, quarantine, pass/, @spamblocker.execute(%w(#1 SMTP update action test)), "validation for updating SMAP action")    
    assert_match(/Error: invalid value for 'tarpit' - valid values are 'true' and 'false'/, @spamblocker.execute(%w(#1 SMTP update tarpit xxx)), "validation for updating SMAP tarpit")    
  end
  
  def test_POP
    # display
    assert_match(/scan,strength,action,description/, @spamblocker.execute(["#1", "POP"]), "display POP settings")

    # update
    assert_match(/scan for POP updated/, @spamblocker.execute(%w(#1 POP update scan false)), "update POP scan - false")
    assert_match(/false/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/scan for POP updated/, @spamblocker.execute(%w(#1 POP update scan true)), "update POP scan -true")
    assert_match(/true/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/strength for POP updated/, @spamblocker.execute(%w(#1 POP update strength low)), "update POP strength - low")
    assert_match(/low/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/strength for POP updated/, @spamblocker.execute(%w(#1 POP update strength very-high)), "update POP strength - very-high")
    assert_match(/very high/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/action for POP updated/, @spamblocker.execute(%w(#1 POP update action mark)), "update POP action - mark")
    assert_match(/mark/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/action for POP updated/, @spamblocker.execute(%w(#1 POP update action pass)), "update POP action - pass")
    assert_match(/pass/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/description for POP updated/, @spamblocker.execute(%w(#1 POP update description test-pop-description)), "update POP description")
    assert_match(/test-pop-description/, @spamblocker.execute(["#1", "POP"]), "display POP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @spamblocker.execute(%w(#1 POP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'strength' - valid values are medium, high, extreme, very-high, low/, @spamblocker.execute(%w(#1 POP update strength test)), "validation for updating SMAP strength")    
    assert_match(/Error: invalid value for 'action' - valid values are mark, pass/, @spamblocker.execute(%w(#1 POP update action quarantine)), "validation for updating SMAP action")    
  end
  
  def test_IMAP
    # display
    assert_match(/scan,strength,action,description/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings")

    # update
    assert_match(/scan for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update scan false)), "update IMAP scan - false")
    assert_match(/false/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/scan for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update scan true)), "update IMAP scan -true")
    assert_match(/true/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/strength for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update strength low)), "update IMAP strength - low")
    assert_match(/low/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/strength for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update strength very-high)), "update IMAP strength - very-high")
    assert_match(/very high/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/action for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update action mark)), "update IMAP action - mark")
    assert_match(/mark/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/action for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update action pass)), "update IMAP action - pass")
    assert_match(/pass/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/description for IMAP updated/, @spamblocker.execute(%w(#1 IMAP update description test-imap-description)), "update IMAP description")
    assert_match(/test-imap-description/, @spamblocker.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @spamblocker.execute(%w(#1 IMAP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'strength' - valid values are medium, high, extreme, very-high, low/, @spamblocker.execute(%w(#1 IMAP update strength test)), "validation for updating SMAP strength")    
    assert_match(/Error: invalid value for 'action' - valid values are mark, pass/, @spamblocker.execute(%w(#1 IMAP update action quarantine)), "validation for updating SMAP action")    
  end
  
end
