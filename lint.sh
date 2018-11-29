#!/bin/sh

# no-member is broken in pylint 1.6.x
# IGNORED="no-member"

pylint3 \
    --max-line-length 1024 \
    --disable="$IGNORED" \
    --module-rgx='(([a-z_][a-z0-9_-]*)|([A-Z][a-zA-Z0-9]+))$' \
    --const-rgx='[a-z_][a-z0-9_]{2,30}$' \
    ./bin/sync-settings
