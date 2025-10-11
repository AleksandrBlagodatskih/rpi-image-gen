# Show LUKS status on login
if [ -x /usr/local/bin/luks-status ]; then
  echo "🔒 LUKS Encryption Status:"
  /usr/local/bin/luks-status | head -10 | tail -8
  echo
fi
