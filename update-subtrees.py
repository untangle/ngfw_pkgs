#! /usr/bin/python3
"""Update subtrees"""

import subprocess

SUBTREES = {
    'untangle-python-sync-settings': 'git@github.com:untangle/sync-settings.git',
    'untangle-python-runtests': 'git@github.com:untangle/runtests.git'
}

branch = subprocess.getoutput('git symbolic-ref --short HEAD')

for directory, repository in SUBTREES.items():
    # FIXME: handle release branch as wwell
    cmd = 'git subtree pull --prefix={} {} {}'.format(directory, repository, branch)

    print('Updating {} from {}:{}'.format(directory, repository, branch))
    subprocess.call(cmd, shell=True)
