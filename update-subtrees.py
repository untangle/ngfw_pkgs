#! /usr/bin/python3

"""Update subtrees, and optionally push result back to origin"""

import argparse
import subprocess
import yaml

# constants
SUBTREES = yaml.load(open("subtrees.yaml"))['subtrees']

# CL args
parser = argparse.ArgumentParser(description="Update subtrees, and optionally push result back to origin")
parser.add_argument('--push', dest='push',
                    action='store_true',
                    default=False,
                    help='push result back to origin (default=False)')

# main
args = parser.parse_args()

branch = subprocess.getoutput('git symbolic-ref --short HEAD')
origin = subprocess.getoutput('git remote').split('\n')[0]

for directory, repository in SUBTREES.items():
    # FIXME: handle release branch as well
    updateCmd = 'git subtree pull --prefix={} {} {}'.format(directory, repository, branch)

    print('Updating {} from {}:{}'.format(directory, repository, branch))
    subprocess.call(updateCmd, shell=True)

if args.push:
    pushCmd = 'git push {} {}:{}'.format(origin, branch, branch)
    print('Pushing with {}'.format(pushCmd))
    subprocess.call(pushCmd, shell=True)
