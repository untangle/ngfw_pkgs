from  untangle.ats.utilities import get_package_version

class TestPostgres:

  PROPER_VERSION = "8.3"

  def test_version:
    assert get_package_version("postgresql-7.4") is None
    assert get_package_version("postgresql-8.3") is not None
