# Show RAID/LUKS status on login
if [ -x /usr/local/bin/raid-luks-status ]; then
  echo "🔒 RAID/LUKS Storage Status:"
  /usr/local/bin/raid-luks-status | head -10 | tail -8
  echo
fi
