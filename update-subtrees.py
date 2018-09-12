#! /usr/bin/python3

import subprocess

SUBTREES = { 'untangle-python-sync-settings': 'git@github.com:untangle/sync-settings.git' }

for directory, repository in SUBTREES.items():
  # FIXME: handle release branch as wwell
  cmd = f'git subtree pull --prefix={directory} {repository} master'

  print(f'Updating {directory} from {repository}')
  subprocess.call(cmd, shell=True)
