#
# mock_server.rb - Moch NUCLI Server, for client unit tests
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'test/unit'
require File.dirname(__FILE__) + '/mock_server'
require 'client'

class TC_NUCLIClientTests < Test::Unit::TestCase
  
  # def setup
  # end
  
  # def teardown
  # end
  
  # TC: can we create a nucli client?
  def test_new
    client = NUCLIClient.new([])
    assert_not_nil(client, 'Failed to create NUCLIClient.')
  end
  
  def test_options
    args = ["-h", "tchost", "-p", "6789", "-t", "-u", "tc_user"]
    client = NUCLIClient.new(args)
    assert_not_nil(client.get_server(args[1]), 'Option hostname failed.')
    assert_not_nil(client.get_server(args[1]+":"+args[3]), 'Option port failed.')
    assert(!client.use_ssh_tunnels, 'Option use ssh tunnels failed.')
    assert_equal(client.user, args[6], 'Option user failed.')
  end
  
  def test_run_command
    client = NUCLIClient.new([])
    # run simple command
    cmd_a = client.run_command(":ls /tmp")
    assert(cmd_a == [":ls", "/tmp"], "Run command: local command failed.")
    # run background command
    cmd_a = client.run_command(":ls /tmp &")
    assert_equal(cmd_a, [":ls", "/tmp", "&"], "Run command: local background command failed.")
    assert_not_nil(client.get_job(0) != nil, "Run command: local background job not found.")
    # run forbidden background command
    cmd_a = client.run_command("with #1 &")
    assert_nil(cmd_a, "Run command: simple local background command failed.")
  end
  
  def test_command_requires_server
    client = NUCLIClient.new([])
    assert(client.command_requires_server("ruby"), "Command requires server failed.")
    assert_equal(client.command_requires_server("history"), false, "Command does not require server failed.")
  end
    
  def test_cleanup
    client = NUCLIClient.new([])
    cmd_a = client.run_command(":ls /tmp &")
    job = client.get_job(0)
    job[0].join
    client.cleanup
    out = client.get_job_output(1)
    assert_equal(out, [], "Cleanup failed.")
  end

  def test_jobs
    client = NUCLIClient.new([])
    cmd_a = client.run_command(":ls /tmp &")
    job = client.get_job(0)
    job[0].join
    assert_not_nil(job, "Jobs: background job not found.")
    out = client.get_job_output(1)
    assert_kind_of(Array, out, "Jobs: job output not found.")
    assert_not_equal(out, [], "Jobs: job output not found.")
  end

  def test_quiet
    client = NUCLIClient.new([])
    client.quiet()
    displayed = client.message("This message should not be issued.", 1)
    assert(!displayed, "Quiet: message should not have been issued.")
  end

end
