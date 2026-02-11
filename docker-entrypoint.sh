#!/usr/bin/env sh
set -eu

# Default command mirrors official behavior while still allowing command override.
if [ "$#" -eq 0 ]; then
    exec /mattermost/bin/mattermost
fi

if [ "$1" = "mattermost" ]; then
    shift
    exec /mattermost/bin/mattermost "$@"
fi

# If the first argument looks like a flag, pass it to mattermost binary.
case "$1" in
    -*)
        exec /mattermost/bin/mattermost "$@"
        ;;
esac

# Support invoking bundled binaries directly by short name.
if [ "$1" = "mmctl" ]; then
    shift
    exec /mattermost/bin/mmctl "$@"
fi

exec "$@"
