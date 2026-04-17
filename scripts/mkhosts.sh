#!/bin/sh

curl -sL \
  http://sbc.io/hosts/hosts \
  https://big.oisd.nl/ \
  https://urlhaus.abuse.ch/downloads/hostfile/ |
awk '
{
  # remove comments
  sub(/#.*/, "")

  # handle adblock-style lines: ||domain^
  if ($0 ~ /^\|\|[^\/^]+\^/) {
    sub(/^\|\|/, "")
    sub(/\^.*/, "")
    print "0.0.0.0", $0
    next
  }

  # skip empty lines
  if ($0 ~ /^[[:space:]]*$/) next

  # normalize whitespace fields
  n = split($0, f, /[[:space:]]+/)

  if (n == 1) {
    host = f[1]
    ip = "0.0.0.0"
  } else {
    ip = f[1]
    host = f[2]

    # normalize IPs
    if (ip == "127.0.0.1") ip = "0.0.0.0"
    else if (ip != "0.0.0.0") ip = "0.0.0.0"
  }

  # avoid invalid entries
  if (host != "" && host != "0.0.0.0")
    print ip, host
}
' |
LC_ALL=C sort -u > blocklist.hosts
