#! /usr/bin/python3

"""Update subtrees via git subtree push+pull, after which it can optionally
   push the main tree back to its origin"""

import argparse
import locale
import re
import subprocess
import sys
import yaml

# constants
SUBTREES = yaml.load(open("subtrees.yaml"))['subtrees']
ENCODING = locale.getpreferredencoding()

# functions
def run(cmd, simulate=False):
    print('... running {}'.format(cmd))
    if not simulate:
        try:
            bytesOutput = subprocess.check_output(cmd, shell=True)
            return bytesOutput.decode(ENCODING).strip()
        except subprocess.CalledProcessError as e:
            print("Error:\n", e.output)
            sys.exit(1)

# CL args
parser = argparse.ArgumentParser(description="Update subtrees, and optionally push result back to origin")
parser.add_argument('--push', dest='push',
                    action='store_true',
                    default=False,
                    help="after subtrees' updates, push main tree back to its origin (default=False)")
parser.add_argument('--simulate', dest='simulate',
                    action='store_true',
                    default=False,
                    help="do not execute any push/pull command, instead only print them (default=False)")

# main
args = parser.parse_args()

branch = run('git symbolic-ref --short HEAD')
if not re.search(r'^(master|release-)', branch):
    print('Cowardly refusing to operate on branches other than master or release-*')
    sys.exit(2)

origin = run('git remote').split('\n')[0]

for directory, repository in SUBTREES.items():
    # FIXME: handle release branch as well
    subtreeUpdateCmd = 'git subtree pull --prefix={} {} {}'.format(directory, repository, branch)
    print('Updating subtree {} from {}:{}'.format(directory, repository, branch))
    run(subtreeUpdateCmd, args.simulate)

    subtreePushCmd = 'git subtree push --prefix={} {} {}'.format(directory, repository, branch)
    print('Pushing subtree {} to {}:{}'.format(directory, repository, branch))
    run(subtreePushCmd, args.simulate)

if args.push:
    pushCmd = 'git push {} {}:{}'.format(origin, branch, branch)
    print('Pushing main tree with {}'.format(pushCmd))
    run(pushCmd, args.simulate)
