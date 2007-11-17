$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'protofilter'

#DEFAULT_DIAG_LEVEL = 0

class TestProtofilter < Test::Unit::TestCase
  def setup
    @protofilter = ProtoFilter.new
  end

  def test_help
    assert_match(/protofilter -- enumerate all/, @protofilter.execute(%w(help)), "help command")
  end
  
  def test_tid_parsing
    assert_match(/protofilter -- enumerate all/, @protofilter.execute(%w(#1 help)), "tid parsing")
  end

  def test_tid_listing
    assert_match(/TID.*Description/, @protofilter.execute([]), "tid listing - no tid")
    assert_match(/TID.*Description/, @protofilter.execute(%w(#1)), "tid listing - tid given")
  end
  
  def test_proto_list
    assert_match(/#,category,protocol,block,log,description,signature/, @protofilter.execute(["#1", "list"]), "tid listing")
  end
  
  def test_update_list
    assert_match(/Protocol added/, @protofilter.execute(%w(#1 add test-cat1 test-proto1 true true desc1 sign1)), "add protocol")
    assert_match(/Protocol added/, @protofilter.execute(%w(#1 add test-cat2 test-proto2 true true desc2 sign2)), "add protocol")
    assert_match(/Protocol added/, @protofilter.execute(%w(#1 add test-cat3 test-proto3 true true desc3 sign3)), "add protocol")
    assert_match(/Protocol 1 was removed/, @protofilter.execute(%w(#1 remove 1)), "remove protocol")
    assert_match(/Protocol 2 was removed/, @protofilter.execute(%w(#1 remove 2)), "remove protocol")
    assert_match(/test-cat2.*test-proto2.*desc2.*sign2/, @protofilter.execute(%w(#1 list)), "listing")
    assert_match(/Protocol 1 updated/, @protofilter.execute(%w(#1 update 1 test-cat5 test-proto5 true true desc5 sign5)), "update protocol")
    assert_match(/test-cat5.*test-proto5.*desc5.*sign5/, @protofilter.execute(%w(#1 list)), "listing")
  end

  def test_validation
    # TODO
  end
end
