#!/bin/sh

# no-member is broken in pylint 1.6.x
# broad-except
IGNORED="broad-except,no-member"

# wring-import-position is ignored because we modify the path before import
# protected-access because we need to use os._exit
# global-variable-not-assigned because pylint doesn't like global variables
# global-statement because pylint doesn't like global variables
MAIN_IGNORED="wrong-import-position,protected-access,global-variable-not-assigned,global-statement"

pylint3 \
    --max-line-length 1024 \
    --disable="$IGNORED" \
    --disable="$MAIN_IGNORED" \
    --module-rgx='(([a-z_][a-z0-9_-]*)|([A-Z][a-zA-Z0-9]+))$' \
    --const-rgx='[a-z_][a-z0-9_]{2,30}$' \
    ./bin/sync-settings
