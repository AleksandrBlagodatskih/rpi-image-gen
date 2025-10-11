# Show RAID status on login
if [ -x /usr/local/bin/raid-status ]; then
  echo "🔄 RAID Storage Status:"
  /usr/local/bin/raid-status | head -10 | tail -8
  echo
fi
