# Show hybrid RAID layout status on login
if [ -x /usr/local/bin/raid-status ] || [ -x /usr/local/bin/luks-status ]; then
  echo "💽 Hybrid RAID Layout Status:"
  echo "   Layout: SD card (boot) + RAID1 SSD (root)"

  # Show RAID status if available
  if [ -x /usr/local/bin/raid-status ]; then
    /usr/local/bin/raid-status | grep -A 3 "1. RAID Status" | tail -3 | sed 's/^/   /'
  fi

  # Show LUKS status if available
  if [ -x /usr/local/bin/luks-status ]; then
    /usr/local/bin/luks-status | grep -A 3 "1. LUKS Encryption Status" | tail -3 | sed 's/^/   /'
  fi

  echo
fi
