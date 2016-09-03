#! /bin/bash
docker pull mozilla/ssh_scan
docker run -it mozilla/ssh_scan /app/bin/ssh_scan -t 52.91.225.2 -P policies/mozilla_modern.yml -u
