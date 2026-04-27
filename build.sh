#!/bin/sh
set -e
cd "$(dirname "$0")"
podman build -t speconn-dart:build -f Containerfile.build .
echo "speconn-dart: build OK"
