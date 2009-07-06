from  untangle.ats.utilities import get_package_version

class TestPostgres:

  OLDER_VERSION = "7.4"
  PROPER_VERSION = "8.3"

  def test_version(test):
    assert get_package_version("postgresql-%s" % (OLDER_VERSION,)) is None
    assert get_package_version("postgresql-%s" % (PROPER_VERSION,)) is not None
