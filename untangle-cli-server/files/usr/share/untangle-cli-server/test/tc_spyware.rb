$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'spyware'

#DEFAULT_DIAG_LEVEL = 0

class TestSpyware < Test::Unit::TestCase
  def setup
    @spyware = Spyware.new
  end

  def test_help
    assert_match(/spyware -- enumerate all/, @spyware.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/spyware -- enumerate all/, @spyware.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @spyware.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @spyware.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_block_list_url
    assert_match(/Spyware and ad URL blocking enabled/, @spyware.execute(%w(#1 block-list url true)), "enable ad URL blocking")
    assert_match(/Spyware and ad URL blocking: enabled/, @spyware.execute(%w(#1 block-list url)), "display ad URL blocking")
    
    assert_match(/Spyware and ad URL blocking disabled/, @spyware.execute(%w(#1 block-list url false)), "disable ad URL blocking")
    assert_match(/Spyware and ad URL blocking: disabled/, @spyware.execute(%w(#1 block-list url)), "display ad URL blocking")
    
    # validation test
    assert_match(/Error: invalid value for 'enable' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list url xxx)), "validation for ad URL blocking")    
  end

  def test_block_list_subnet
    # list
    assert_match(/#,name,subnet,log/, @spyware.execute(%w(#1 block-list subnet)), "tid block-list subnet listing")
    
    # add
    assert_match(/Subnet rule added to the block list/, @spyware.execute(%w(#1 block-list subnet add sub1 192.168.1.0/24 true)), "add subnet rule")
    assert_match(/Subnet rule added to the block list/, @spyware.execute(%w(#1 block-list subnet add sub2 192.168.2.0/24 false)), "add subnet rule")
    assert_match(/^\d+,sub1,192\.168\.1\.0\/24,true$/, @spyware.execute(%w(#1 block-list subnet)), "listing")
    assert_match(/Error: invalid value for 'subnet'/, @spyware.execute(%w(#1 block-list subnet add sub2 192.168.2.0/124 true)), "validation for adding a subnet rule - subnet")    
    assert_match(/Error: invalid value for 'log' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list subnet add sub2 192.168.2.0/24 xxx)), "validation for adding a subnet rule - log")    
    
    # update
    assert_match(/Subnet rule 2 was updated/, @spyware.execute(%w(#1 block-list subnet update 2 sub3 192.168.3.0/24 true)), "update subnet rule")
    assert_match(/^\d+,sub3,192\.168\.3\.0\/24,true$/, @spyware.execute(%w(#1 block-list subnet)), "listing")
    assert_match(/Error: invalid value for 'subnet rule number'/, @spyware.execute(%w(#1 block-list subnet update -2 sub3 192.168.3.0/24 true)), "validation for updating a subnet rule - rule number")    
    assert_match(/Error: invalid value for 'subnet'/, @spyware.execute(%w(#1 block-list subnet update 2 sub3 192.168.3.0/124 true)), "validation for updating a subnet rule - subnet")    
    assert_match(/Error: invalid value for 'log' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list subnet update 2 sub3 192.168.3.0/24 xxx)), "validation for updating a subnet rule - log")    
    
    # remove
    assert_match(/Subnet rule 2 was removed/, @spyware.execute(%w(#1 block-list subnet remove 2)), "remove subnet rule")
    assert_match(/Error: invalid value for 'subnet rule number'/, @spyware.execute(%w(#1 block-list subnet remove -2)), "validation for removing a subnet rule - rule number")    
  end

  def test_block_list_cookie
    # list
    assert_match(/#,identification,block/, @spyware.execute(%w(#1 block-list cookie)), "tid block-list cookie listing")
    
    # add
    assert_match(/Cookie rule added to the block list/, @spyware.execute(%w(#1 block-list cookie add identif1 true)), "add cookie rule")
    assert_match(/Cookie rule added to the block list/, @spyware.execute(%w(#1 block-list cookie add identif2 false)), "add cookie rule")
    assert_match(/^\d+,identif1,true$/, @spyware.execute(%w(#1 block-list cookie)), "listing")
    assert_match(/Error: invalid value for 'block' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list cookie add identif xyz)), "validation for adding a cookie rule - block")    
    
    # update
    assert_match(/Cookie rule 2 was updated/, @spyware.execute(%w(#1 block-list cookie update 2 identif3 true)), "update cookie rule")
    assert_match(/^\d+,identif3,true$/, @spyware.execute(%w(#1 block-list cookie)), "listing")
    assert_match(/Error: invalid value for 'cookie rule number'/, @spyware.execute(%w(#1 block-list cookie update -2 identif true)), "validation for updating a cookie rule - rule number")    
    assert_match(/Error: invalid value for 'block' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list cookie update 2 identif xyz)), "validation for updating a cookie rule - block")    
    
    # remove
    assert_match(/Cookie rule 2 was removed/, @spyware.execute(%w(#1 block-list cookie remove 2)), "remove cookie rule")
    assert_match(/Error: invalid value for 'cookie rule number'/, @spyware.execute(%w(#1 block-list cookie remove 12345)), "validation for removing a cookie rule - rule number")    
  end
  
  def test_block_list_activex
    # list
    assert_match(/#,identification,block/, @spyware.execute(%w(#1 block-list activex)), "tid block-list activex listing")
    
    # add
    assert_match(/ActiveX rule added to the block list/, @spyware.execute(%w(#1 block-list activex add identif1 true)), "add activex rule")
    assert_match(/ActiveX rule added to the block list/, @spyware.execute(%w(#1 block-list activex add identif2 false)), "add activex rule")
    assert_match(/^\d+,identif1,true$/, @spyware.execute(%w(#1 block-list activex)), "listing")
    assert_match(/Error: invalid value for 'block' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list activex add identif xyz)), "validation for adding a activex rule - block")    
    
    # update
    assert_match(/ActiveX rule 2 was updated/, @spyware.execute(%w(#1 block-list activex update 2 identif3 true)), "update activex rule")
    assert_match(/^\d+,identif3,true$/, @spyware.execute(%w(#1 block-list activex)), "listing")
    assert_match(/Error: invalid value for 'ActiveX rule number'/, @spyware.execute(%w(#1 block-list activex update -2 identif true)), "validation for updating a activex rule - rule number")    
    assert_match(/Error: invalid value for 'block' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-list activex update 2 identif xyz)), "validation for updating a activex rule - block")    
    
    # remove
    assert_match(/ActiveX rule 2 was removed/, @spyware.execute(%w(#1 block-list activex remove 2)), "remove activex rule")
    assert_match(/Error: invalid value for 'ActiveX rule number'/, @spyware.execute(%w(#1 block-list activex remove 12345)), "validation for removing a activex rule - rule number")    
  end
  
  def test_pass_list
    # list
    assert_match(/#,pass,domain/, @spyware.execute(["#1", "pass-list"]), "tid pass-list listing")
    
    # add
    assert_match(/Domain added to the pass list/, @spyware.execute(%w(#1 pass-list add true domain1)), "add domain")
    assert_match(/Domain added to the pass list/, @spyware.execute(%w(#1 pass-list add false domain2)), "add domain")
    assert_match(/^\d+,false,domain2$/, @spyware.execute(%w(#1 pass-list)), "listing")
    assert_match(/Error: invalid value for 'pass' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 pass-list add xxx domain1)), "validation for adding a domain")    
    
    # update
    assert_match(/Domain 2 was updated/, @spyware.execute(%w(#1 pass-list update 2 true domain2up)), "update domain")
    assert_match(/^\d+,true,domain2up$/, @spyware.execute(%w(#1 pass-list)), "listing")
    assert_match(/Error: invalid value for 'domain number'/, @spyware.execute(%w(#1 pass-list update -2 true domain1)), "validation for updating a domain - domain number")    
    assert_match(/Error: invalid value for 'pass' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 pass-list update 2 xxx domain1)), "validation for updating a domain - pass")    
    
    # remove
    assert_match(/Domain 2 was removed from the pass list/, @spyware.execute(%w(#1 pass-list remove 2)), "remove domain")
    assert_match(/Error: invalid value for 'domain number'/, @spyware.execute(%w(#1 pass-list remove -2)), "validation for removing a domain - domain number")    
  end
  
  def test_block_all_activex
    assert_match(/Block all ActiveX enabled/, @spyware.execute(%w(#1 block-all-activex true)), "enable block-all-activex")
    assert_match(/Block all ActiveX: enabled/, @spyware.execute(%w(#1 block-all-activex)), "display block-all-activex")
    
    assert_match(/Block all ActiveX disabled/, @spyware.execute(%w(#1 block-all-activex false)), "disable block-all-activex")
    assert_match(/Block all ActiveX: disabled/, @spyware.execute(%w(#1 block-all-activex)), "display block-all-activex")
    
    # validation test
    assert_match(/Error: invalid value for 'enable' - valid values are 'true' and 'false'/, @spyware.execute(%w(#1 block-all-activex xxx)), "validation for block-all-activex")    
  end

  def test_quick_passlist
    assert_match(/Quick-passlist None/, @spyware.execute(%w(#1 quick-passlist none)), "update quick-passlist settings")
    assert_match(/Quick-passlist: None/, @spyware.execute(%w(#1 quick-passlist)), "display quick-passlist settings")
    
    assert_match(/Quick-passlist User and Global/, @spyware.execute(%w(#1 quick-passlist user-and-global)), "update quick-passlist settings")
    assert_match(/Quick-passlist: User and Global/, @spyware.execute(%w(#1 quick-passlist)), "display quick-passlist settings")
    
    # validation test
    assert_match(/Error: invalid value for 'quick-passlist' - valid values are none, user-only, user-and-global/, @spyware.execute(%w(#1 quick-passlist xxx)), "validation for quick-passlist")    
  end
  
end
