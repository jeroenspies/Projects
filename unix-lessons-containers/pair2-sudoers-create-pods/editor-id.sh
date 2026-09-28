#!/bin/sh
# sudoedit runs this as the invoking user. Record that uid and do not edit the file.
set -eu
id > /tmp/sudoedit-id
exit 0
