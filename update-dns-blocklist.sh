#!/bin/bash
# URLs for Blocklists
AD_URL="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/multi.txt"
ADULT_URL="https://raw.githubusercontent.com/emiliodallatorre/adult-hosts-list/main/list.txt"

# Destination Files
AD_FILE="/etc/dnsdist/blocklists/ad-block.txt"
ADULT_FILE="/etc/dnsdist/blocklists/adult-block.txt"

echo "Downloading HaGeZi Ad blocklist..."
# 1. Download
# 2. tr -d '\r' -> Removes Windows line endings
# 3. grep -v "^#" -> Removes comments
# 4. grep -v "^$" -> Removes empty lines
# 5. sed 's/\.*$//' -> Strips existing dots
# 6. sed 's/$/./' -> Adds exactly one trailing dot
# 7. sort -u -> Removes duplicates to save memory
curl -s -L "$AD_URL" | tr -d '\r' | grep -v "^#" | grep -v "^$" | sed 's/\.*$//' | sed 's/$/./' | sort -u > "$AD_FILE"

echo "Downloading Adult blocklist..."
curl -s -L "$ADULT_URL" | tr -d '\r' | grep -v "^#" | grep -v "^$" | sed 's/\.*$//' | sed 's/$/./' | sort -u > "$ADULT_FILE"

# Restart to apply
systemctl restart dnsdist
echo "DNS lists updated successfully."