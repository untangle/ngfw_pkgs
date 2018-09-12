#! /usr/bin/python3

import subprocess

SUBTREES = { 'untangle-python-sync-settings': 'git@github.com:untangle/sync-settings.git' }

for directory, repository in SUBTREES.items():
  # FIXME: handle release branch as wwell
  cmd = 'git subtree pull --prefix={} {} master'.format(directory, repository)

  print('Updating {} from {}'.format(directory, repository))
  subprocess.call(cmd, shell=True)
