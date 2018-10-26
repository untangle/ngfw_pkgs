#!/bin/sh

# no-member is broken in pylint 1.6.x

pylint3 --disable="line-too-long,wrong-import-position,no-member" --module-rgx='(([a-z_][a-z0-9_-]*)|([A-Z][a-zA-Z0-9]+))$' ./bin/sync-settings
