# Unattended Upgrades status profile for bash
# This file is sourced by /etc/profile.d/ to show unattended upgrades status on login

# Only show status if running interactively and not in scripts
if [[ $- == *i* ]] && [ -z "${UNATTENDED_UPGRADES_STATUS_SHOWN:-}" ]; then
    export UNATTENDED_UPGRADES_STATUS_SHOWN=1

    # Check if unattended-upgrades is available
    if command -v unattended-upgrade >/dev/null 2>&1; then
        echo "🔄 Unattended Upgrades:"

        # Check if service is enabled
        if systemctl is-enabled unattended-upgrades.timer >/dev/null 2>&1 2>/dev/null; then
            echo "   ✅ Automatic upgrades enabled"
        else
            echo "   ⚠️  Automatic upgrades disabled"
        fi

        # Check for pending upgrades
        if command -v apt >/dev/null 2>&1; then
            pending=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
            if [ "$pending" -gt 0 ]; then
                echo "   📦 $pending packages pending upgrade"
            fi
        fi

        echo
    fi
fi
