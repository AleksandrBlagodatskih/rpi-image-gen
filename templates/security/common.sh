#!/bin/bash
# Common functions for security layer templates
# This file provides shared utilities for all security components

set -euo pipefail

# Function to create backup directory with timestamp
create_backup_dir() {
    local component="$1"
    local target_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$target_dir/var/backups/security/${component}_backup_$timestamp"

    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Function to validate component enablement
validate_component_enabled() {
    local component="$1"
    local enable_var="IGconf_${component}_enable"

    if [ "${!enable_var:-n}" != "y" ]; then
        echo "ℹ️  $component disabled (set $enable_var=y to enable)"
        exit 0
    fi
}

# Function to check if configuration variable is set to 'y'
igconf_isy() {
    local var_name="$1"
    local var_value="${!var_name:-n}"
    [ "$var_value" = "y" ]
}

# Function to install component script with proper permissions
install_component_script() {
    local source_file="$1"
    local target_path="$2"
    local target_dir="$3"

    if [ ! -f "$source_file" ]; then
        echo "⚠️  Warning: Source file $source_file not found, skipping installation"
        return 1
    fi

    # Create target directory if it doesn't exist
    local target_dir_path="$target_dir/$(dirname "$target_path")"
    uchroot "$target_dir" mkdir -p "$(dirname "$target_path")"

    # Copy file with appropriate permissions
    if [[ "$target_path" == *.sh ]]; then
        install -m 755 "$source_file" "$target_dir/$target_path"
    else
        install -m 644 "$source_file" "$target_dir/$target_path"
    fi

    echo "✅ Installed $source_file to $target_path"
}

# Function to safely modify configuration files
safe_config_update() {
    local file_path="$1"
    local search_pattern="$2"
    local replace_line="$3"
    local target_dir="$4"

    local full_path="$target_dir/$file_path"

    # Create backup if file exists
    if [ -f "$full_path" ]; then
        cp "$full_path" "${full_path}.backup"
    fi

    # Update or append configuration
    if grep -q "^$search_pattern" "$full_path" 2>/dev/null; then
        sed -i "s|^$search_pattern.*|$replace_line|" "$full_path"
    else
        echo "$replace_line" >> "$full_path"
    fi
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if [[ $ip =~ $regex ]]; then
        # Check if each octet is between 0-255
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate port number
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

# Function to check if a service is available
check_service_available() {
    local service="$1"
    local target_dir="$2"

    if uchroot "$target_dir" systemctl list-units --all | grep -q "$service"; then
        return 0
    fi
    return 1
}

# Function to safely restart service
safe_service_restart() {
    local service="$1"
    local target_dir="$2"

    if check_service_available "$service" "$target_dir"; then
        echo "🔄 Restarting $service..."
        uchroot "$target_dir" systemctl restart "$service" || echo "⚠️  Failed to restart $service"
    else
        echo "ℹ️  Service $service not available, skipping restart"
    fi
}

# Function to safely enable service
safe_service_enable() {
    local service="$1"
    local target_dir="$2"

    if check_service_available "$service" "$target_dir"; then
        echo "🔧 Enabling $service..."
        uchroot "$target_dir" systemctl enable "$service" || echo "⚠️  Failed to enable $service"
    else
        echo "ℹ️  Service $service not available, skipping enable"
    fi
}

# Function to create systemd service file
create_systemd_service() {
    local service_name="$1"
    local service_content="$2"
    local target_dir="$3"

    local service_file="$target_dir/etc/systemd/system/${service_name}.service"

    # Create backup if file exists
    if [ -f "$service_file" ]; then
        cp "$service_file" "${service_file}.backup"
    fi

    echo "$service_content" > "$service_file"
    uchroot "$target_dir" systemctl daemon-reload
    echo "✅ Created systemd service: $service_name"
}

# Function to log security events
log_security_event() {
    local event="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $event" >&2
}

# Function to validate configuration syntax
validate_config_syntax() {
    local config_file="$1"
    local validator="$2"

    if command -v "$validator" >/dev/null 2>&1; then
        if "$validator" "$config_file" >/dev/null 2>&1; then
            echo "✅ Configuration syntax valid: $config_file"
            return 0
        else
            echo "❌ Configuration syntax invalid: $config_file"
            return 1
        fi
    else
        echo "⚠️  Validator not available: $validator"
        return 0
    fi
}

echo "🔧 Security common functions loaded"
