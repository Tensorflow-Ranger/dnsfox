#!/bin/bash

# ================================
# CONFIG
# ================================

SERVICE="Wi-Fi"

PRIVATE_DNS=(
  "<YOUR_PRIVATE_DNS_IP>"
)

# ================================
# LOGIC
# ================================

ACTION="$1"

if [[ "$ACTION" != "up" && "$ACTION" != "down" ]]; then
  echo "Usage: $0 {up|down}"
  exit 1
fi

WIFI_DEVICE=$(networksetup -listallhardwareports \
  | awk '/Wi-Fi|AirPort/{getline; print $2}')

SSID=$(networksetup -getairportnetwork "$WIFI_DEVICE" | sed 's/.*: //')

echo "Wi-Fi SSID      : $SSID"
echo "Network Service: $SERVICE"

if [[ "$ACTION" == "down" ]]; then
  echo "Disabling private DNS (captive portal mode)"
  sudo networksetup -setdnsservers "$SERVICE" Empty
  echo "DNS cleared. Log in to the captive portal."
else
  echo "Restoring private DNS"
  sudo networksetup -setdnsservers "$SERVICE" "${PRIVATE_DNS[@]}"
  echo "Private DNS restored."
fi