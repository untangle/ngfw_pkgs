$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'ips'

#DEFAULT_DIAG_LEVEL = 0

class TestIps < Test::Unit::TestCase
  def setup
    @ips = Ips.new
  end

  def test_help
    assert_match(/ips -- enumerate all/, @ips.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/ips -- enumerate all/, @ips.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @ips.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @ips.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_rule_list
    assert_match(/sid, category,block,log,description,info-URL,signature/, @ips.execute(["#1", "rule-list"]), "tid rule listing")
  end
  
  def test_update_rule_list
    assert_match(/Rule added/, @ips.execute(%w(#1 rule-list add 1 test-cat1 true true desc1 http://www.k1.com sign1)), "add rule")
    assert_match(/Rule added/, @ips.execute(%w(#1 rule-list add 2 test-cat2 true false desc2 http://www.k2.com sign2)), "add rule")
    assert_match(/Rule added/, @ips.execute(%w(#1 rule-list add 3 test-cat3 false true desc3 http://www.k3.com sign3)), "add rule")
    assert_match(/Rule 1 was removed/, @ips.execute(%w(#1 rule-list remove 1)), "remove rule")
    assert_match(/Rule 2 was removed/, @ips.execute(%w(#1 rule-list remove 2)), "remove rule")
    assert_match(/test-cat3.*desc3.*sign3/, @ips.execute(%w(#1 rule-list)), "listing")
    assert_match(/Rule 3 was updated/, @ips.execute(%w(#1 rule-list update 3 test-cat5 true true desc5 http://www.k5.com sign5)), "update rule")
    assert_match(/test-cat5.*desc5.*sign5/, @ips.execute(%w(#1 rule-list)), "listing")
    assert_match(/Rule 3 was removed/, @ips.execute(%w(#1 rule-list remove 3)), "remove rule")
  end
  
  def test_variable_list
    assert_match(/name,value,description/, @ips.execute(["#1", "variable-list"]), "tid variable listing")
  end
  
  def test_update_rule_list
    assert_match(/Variable added/, @ips.execute(%w(#1 variable-list add name1 value1 desc1)), "add variable")
    assert_match(/Variable added/, @ips.execute(%w(#1 variable-list add name2 value2 desc2)), "add variable")
    assert_match(/Variable added/, @ips.execute(%w(#1 variable-list add name3 value3 desc3)), "add variable")
    assert_match(/Variable name2 was removed/, @ips.execute(%w(#1 variable-list remove name2)), "remove variable")
    assert_match(/Variable name1 was removed/, @ips.execute(%w(#1 variable-list remove name1)), "remove variable")
    assert_match(/name3.*value3.*desc3/, @ips.execute(%w(#1 variable-list)), "listing")
    assert_match(/Variable name3 was updated/, @ips.execute(%w(#1 variable-list update name3 value5 desc5)), "update variable")
    assert_match(/name3.*value5.*desc5/, @ips.execute(%w(#1 variable-list)), "listing")
    assert_match(/Variable name3 was removed/, @ips.execute(%w(#1 variable-list remove name3)), "remove variable")
  end
  
  def test_validation
    # TODO
  end
end
