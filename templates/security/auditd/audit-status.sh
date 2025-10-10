# Auditd status profile for bash
# This file is sourced by /etc/profile.d/ to show auditd status on login

# Only show status if running interactively and not in scripts
if [[ $- == *i* ]] && [ -z "${AUDITD_STATUS_SHOWN:-}" ]; then
    export AUDITD_STATUS_SHOWN=1

    # Check if auditd is available
    if command -v auditctl >/dev/null 2>&1 && systemctl is-active --quiet auditd 2>/dev/null; then
        echo "🔍 Auditd Status:"
        rule_count=$(auditctl -l 2>/dev/null | wc -l)
        echo "   📋 Loaded rules: $rule_count"

        # Check if audit log exists and has events
        if [ -f /var/log/audit/audit.log ]; then
            event_count=$(wc -l < /var/log/audit/audit.log 2>/dev/null || echo "0")
            echo "   📊 Recent events: $event_count"
        fi

        echo
    fi
fi
