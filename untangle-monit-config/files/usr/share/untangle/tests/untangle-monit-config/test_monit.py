from untangle.ats.utilities import is_process_running

class TestMonit:
  def test_monit_running(self):
    assert is_process_running("/usr/bin/monit")

  def test_wrapper_running(self):
    assert is_process_running("sh /usr/share/untangle/bin/monit-wrapper.sh")  
