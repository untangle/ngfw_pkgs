#!/usr/bin/env python

from setuptools import setup
#from untangle-python-sync-settings import __version__
__version__ = "0.1" # FIXME, see above

setup(name='untangle-python-sync-settings',
      version = __version__,
      description = 'Untangle Python Sync Settings.',
      long_description = '''Takes the network settings JSON file and syncs it to the operating system
                            It reads through the settings and writes the appropriate operating system files.''',
      author = 'Dirk Morris & Untangle.',
      author_email = 'dmorris@untangle.com',
      url = 'https://untangle.com',
      scripts = ['bin/sync-settings.py'],
      packages = ['sync'],
      install_requires = [],
      license = 'GPL',
#      test_suite = '',
#      cmdclass = {'test': PyTest},
      classifiers = (
        'Development Status :: 5 - Production/Stable',
        'License :: OSI Approved :: General Public License v2 (GPL-2)',
        'Environment :: Console',
        'Operating System :: POSIX',
        'Intended Audience :: Developers',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.3',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7'
    )
)
