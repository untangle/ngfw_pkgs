$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'virus'

#DEFAULT_DIAG_LEVEL = 0

class TestVirus < Test::Unit::TestCase
  def setup
    @virus = Virus.new
  end

  def test_help
    assert_match(/virus -- enumerate all/, @virus.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/virus -- enumerate all/, @virus.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @virus.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @virus.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_http
    assert_match(/Scan HTTP files enabled/, @virus.execute(%w(#1 http true)), "enable 'Scan HTTP files' option")
    assert_match(/Scan HTTP files: enabled/, @virus.execute(%w(#1 http)), "display 'Scan HTTP files' option")
    
    assert_match(/Scan HTTP files disabled/, @virus.execute(%w(#1 http false)), "disable 'Scan HTTP files' option")
    assert_match(/Scan HTTP files: disabled/, @virus.execute(%w(#1 http)), "display 'Scan HTTP files' option")
    
    # validation test
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 http xxx)), "validation for 'Scan HTTP files' option")    
  end

  def test_ftp
    assert_match(/Scan FTP files enabled/, @virus.execute(%w(#1 ftp true)), "enable 'Scan FTP files' option")
    assert_match(/Scan FTP files: enabled/, @virus.execute(%w(#1 ftp)), "display 'Scan FTP files' option")
    
    assert_match(/Scan FTP files disabled/, @virus.execute(%w(#1 ftp false)), "disable 'Scan FTP files' option")
    assert_match(/Scan FTP files: disabled/, @virus.execute(%w(#1 ftp)), "display 'Scan FTP files' option")
    
    # validation test
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 ftp xxx)), "validation for 'Scan FTP files' option")    
  end

  def test_extension_list
    # list
    assert_match(/#,extension,scan,description/, @virus.execute(["#1", "extension-list"]), "tid file-extension-list listing")
    
    # add
    assert_match(/Item added to the file-extension-list/, @virus.execute(%w(#1 extension-list add tst1 true test1)), "add extension")
    assert_match(/Item added to the file-extension-list/, @virus.execute(%w(#1 extension-list add tst2 false test2)), "add extension")
    assert_match(/^\d+,tst2,false,test2$/, @virus.execute(%w(#1 extension-list)), "listing")
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 extension-list add tst trr test)), "validation for adding an extesion")    
    
    # update
    assert_match(/Item 2 was updated/, @virus.execute(%w(#1 extension-list update 2 tst3 true test3)), "update extension")
    assert_match(/^\d+,tst3,true,test3$/, @virus.execute(%w(#1 extension-list)), "listing")
    assert_match(/Error: invalid value for 'item-number'/, @virus.execute(%w(#1 extension-list update -2 tst true test)), "validation for adding an extesion - item-number")    
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 extension-list update 2 tst trr test)), "validation for adding an extension - scan")    
    
    # remove
    assert_match(/Item 2 was removed from the file-extension-list/, @virus.execute(%w(#1 extension-list remove 2)), "remove extension")
    assert_match(/Error: invalid value for 'item-number'/, @virus.execute(%w(#1 extension-list remove -2)), "validation for removing an extension - item-number")    
  end
  
  def test_mime_list
    # list
    assert_match(/#,MIME type,scan,description/, @virus.execute(["#1", "mime-list"]), "tid mime-type-list listing")
    
    # add
    assert_match(/Item added to the mime-type-list/, @virus.execute(%w(#1 mime-list add tst1 true test1)), "add mime")
    assert_match(/Item added to the mime-type-list/, @virus.execute(%w(#1 mime-list add tst2 false test2)), "add mime")
    assert_match(/^\d+,tst2,false,test2$/, @virus.execute(%w(#1 mime-list)), "listing")
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 mime-list add tst trr test)), "validation for adding an extesion")    
    
    # update
    assert_match(/Item 2 was updated/, @virus.execute(%w(#1 mime-list update 2 tst3 true test3)), "update mime")
    assert_match(/^\d+,tst3,true,test3$/, @virus.execute(%w(#1 mime-list)), "listing")
    assert_match(/Error: invalid value for 'item-number'/, @virus.execute(%w(#1 mime-list update -2 tst true test)), "validation for adding an extesion - item-number")    
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 mime-list update 2 tst trr test)), "validation for adding a mime - scan")    
    
    # remove
    assert_match(/Item 2 was removed from the mime-type-list/, @virus.execute(%w(#1 mime-list remove 2)), "remove mime")
    assert_match(/Error: invalid value for 'item-number'/, @virus.execute(%w(#1 mime-list remove -2)), "validation for removing a mime - item-number")    
  end
  
  
  def test_SMTP
    # display
    assert_match(/scan,action,description\n.*SMTP/, @virus.execute(["#1", "SMTP"]), "display SMTP settings")

    # update
    assert_match(/Scan for SMTP was updated/, @virus.execute(%w(#1 SMTP update scan false)), "update SMTP scan - false")
    assert_match(/false/, @virus.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/Scan for SMTP was updated/, @virus.execute(%w(#1 SMTP update scan true)), "update SMTP scan -true")
    assert_match(/true/, @virus.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/Action for SMTP was updated/, @virus.execute(%w(#1 SMTP update action remove)), "update SMTP action - remove")
    assert_match(/remove infection/, @virus.execute(["#1", "SMTP"]), "display SMTP settings after update")
    assert_match(/Action for SMTP was updated/, @virus.execute(%w(#1 SMTP update action block)), "update SMTP action - block")
    assert_match(/block message/, @virus.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    assert_match(/Description for SMTP was updated/, @virus.execute(%w(#1 SMTP update description test-smtp-description)), "update SMTP description")
    assert_match(/test-smtp-description/, @virus.execute(["#1", "SMTP"]), "display SMTP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 SMTP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are block, remove, pass/, @virus.execute(%w(#1 SMTP update action test)), "validation for updating SMAP action")    
  end
  
  def test_POP
    # display
    assert_match(/scan,action,description\n.*POP/, @virus.execute(["#1", "POP"]), "display POP settings")

    # update
    assert_match(/Scan for POP was updated/, @virus.execute(%w(#1 POP update scan false)), "update POP scan - false")
    assert_match(/false/, @virus.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/Scan for POP was updated/, @virus.execute(%w(#1 POP update scan true)), "update POP scan -true")
    assert_match(/true/, @virus.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/Action for POP was updated/, @virus.execute(%w(#1 POP update action remove)), "update POP action - remove")
    assert_match(/remove infection/, @virus.execute(["#1", "POP"]), "display POP settings after update")
    assert_match(/Action for POP was updated/, @virus.execute(%w(#1 POP update action pass)), "update POP action - pass")
    assert_match(/pass message/, @virus.execute(["#1", "POP"]), "display POP settings after update")
    
    assert_match(/Description for POP was updated/, @virus.execute(%w(#1 POP update description test-pop-description)), "update POP description")
    assert_match(/test-pop-description/, @virus.execute(["#1", "POP"]), "display POP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 POP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are remove, pass/, @virus.execute(%w(#1 POP update action block)), "validation for updating SMAP action")    
  end
  
  def test_IMAP
    # display
    assert_match(/scan,action,description\n.*IMAP/, @virus.execute(["#1", "IMAP"]), "display IMAP settings")

    # update
    assert_match(/Scan for IMAP was updated/, @virus.execute(%w(#1 IMAP update scan false)), "update IMAP scan - false")
    assert_match(/false/, @virus.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/Scan for IMAP was updated/, @virus.execute(%w(#1 IMAP update scan true)), "update IMAP scan -true")
    assert_match(/true/, @virus.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/Action for IMAP was updated/, @virus.execute(%w(#1 IMAP update action remove)), "update IMAP action - remove")
    assert_match(/remove infection/, @virus.execute(["#1", "IMAP"]), "display IMAP settings after update")
    assert_match(/Action for IMAP was updated/, @virus.execute(%w(#1 IMAP update action pass)), "update IMAP action - pass")
    assert_match(/pass message/, @virus.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    assert_match(/Description for IMAP was updated/, @virus.execute(%w(#1 IMAP update description test-imap-description)), "update IMAP description")
    assert_match(/test-imap-description/, @virus.execute(["#1", "IMAP"]), "display IMAP settings after update")
    
    # validation
    assert_match(/Error: invalid value for 'scan' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 IMAP update scan xxx)), "validation for updating SMAP scan")    
    assert_match(/Error: invalid value for 'action' - valid values are remove, pass/, @virus.execute(%w(#1 IMAP update action block)), "validation for updating SMAP action")    
  end
  
  def test_http_disable_resume
    assert_match(/Disable HTTP download resume set to true/, @virus.execute(%w(#1 http-disable-resume true)), "activate 'disable HTTP download resume' option")
    assert_match(/Disable HTTP download resume: true/, @virus.execute(%w(#1 http-disable-resume)), "display 'disable HTTP download resume' option")
    
    assert_match(/Disable HTTP download resume set to false/, @virus.execute(%w(#1 http-disable-resume false)), "deactivate 'disable HTTP download resume' option")
    assert_match(/Disable HTTP download resume: false/, @virus.execute(%w(#1 http-disable-resume)), "display 'disable HTTP download resume' option")
    
    # validation test
    assert_match(/Error: invalid value for 'value' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 http-disable-resume xxx)), "validation for 'disable HTTP download resume' option")    
  end
  
  def test_ftp_disable_resume
    assert_match(/Disable FTP download resume set to true/, @virus.execute(%w(#1 ftp-disable-resume true)), "activate 'disable FTP download resume' option")
    assert_match(/Disable FTP download resume: true/, @virus.execute(%w(#1 ftp-disable-resume)), "display 'disable FTP download resume' option")
    
    assert_match(/Disable FTP download resume set to false/, @virus.execute(%w(#1 ftp-disable-resume false)), "deactivate 'disable FTP download resume' option")
    assert_match(/Disable FTP download resume: false/, @virus.execute(%w(#1 ftp-disable-resume)), "display 'disable FTP download resume' option")
    
    # validation test
    assert_match(/Error: invalid value for 'value' - valid values are 'true' and 'false'/, @virus.execute(%w(#1 ftp-disable-resume xxx)), "validation for 'disable FTP download resume' option")    
  end
  
  def test_trickle_rate
    assert_match(/Scan trickle rate \(percent\) set to 75/, @virus.execute(%w(#1 trickle-rate 75)), "update trickle-rate value")
    assert_match(/Scan trickle rate \(percent\): 75/, @virus.execute(%w(#1 trickle-rate)), "display trickle-rate value")
    
    # validation test
    assert_match(/Error: invalid value for 'trickle-rate' - valid values are 0..100/, @virus.execute(%w(#1 trickle-rate 101)), "validation for trickle-rate")    
  end
  
end
