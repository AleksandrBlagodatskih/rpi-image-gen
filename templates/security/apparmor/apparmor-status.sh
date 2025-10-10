# AppArmor status profile for bash
# This file is sourced by /etc/profile.d/ to show AppArmor status on login

# Only show status if running interactively and not in scripts
if [[ $- == *i* ]] && [ -z "${APPARMOR_STATUS_SHOWN:-}" ]; then
    export APPARMOR_STATUS_SHOWN=1

    # Check if AppArmor is available
    if command -v aa-status >/dev/null 2>&1; then
        echo "🛡️  AppArmor Status:"
        aa-status 2>/dev/null | head -3 | sed 's/^/   /'

        # Check for any complain mode profiles
        complain_profiles=$(aa-status 2>/dev/null | grep -c "in complain mode" || echo "0")
        if [ "$complain_profiles" -gt 0 ]; then
            echo "   ⚠️  $complain_profiles profiles in complain mode"
        fi

        # Check for any enforce mode profiles
        enforce_profiles=$(aa-status 2>/dev/null | grep -c "in enforce mode" || echo "0")
        if [ "$enforce_profiles" -gt 0 ]; then
            echo "   ✅ $enforce_profiles profiles in enforce mode"
        fi

        echo
    fi
fi
