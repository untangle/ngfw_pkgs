#!/bin/sh

# no-member is broken in pylint 1.6.x
# IGNORED="no-member"

pylint3 \
    --max-line-length 1024 \
    --disable="$IGNORED" \
    --module-rgx='(([a-z_][a-z0-9_-]*)|([A-Z][a-zA-Z0-9]+))$' \
    --const-rgx='[a-z_][a-z0-9_]{1,30}$' \
    --variable-rgx='[a-z_][a-z0-9_]{0,30}$' \
    --function-rgx='[a-z_][a-z0-9_]{2,50}$' \
    ./bin/sync-settings ./sync/nftables_util.py
