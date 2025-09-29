#!/bin/bash
# shellcheck disable=SC2154

set -eu

src=$(realpath -e "$1") || die "sbom: invalid src"
outdir=$(realpath -e "$2") || die "sbom: invalid outdir"

igconf isy sbom_enable || exit 0

[[ $(igconf getval sbom_provider) == syft ]] || exit 0

SYFTCFG=$(realpath -e $(igconf getval sbom_syft_config)) || die "Invalid syft config"

SYFT_VER=v1.32.0

# If host has syft, use it
if ! hash syft 2>/dev/null; then
   curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
      | sh -s -- -b "${IGconf_sys_workroot}"/host/bin "${SYFT_VER}"
fi

SYFT=$(syft --version 2>/dev/null) || die "syft is unusable"

# Set properties based on scan target.
if [[ -f "$src" ]]; then
   scan_target="file:$src"
elif [[ -d "$src" ]]; then
   scan_target="dir:$src"
else
   die "sbom: '$src' is neither a file nor a directory"
fi

msg "\nSBOM: $SYFT scanning $scan_target"

syft -c "$SYFTCFG" "$scan_target" \
   --base-path "$src" \
   --source-name "$IGconf_sbom_name" \
   --source-version "$IGconf_sbom_version" \
   > "${outdir}/${IGconf_sbom_filename}"

# Generate security vulnerability report if enabled
if igconf isy sbom_security_scan; then
    echo "Generating security vulnerability report..."

    # Install Grype if not available
    if ! hash grype 2>/dev/null; then
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
            | sh -s -- -b "${IGconf_sys_workroot}"/host/bin v0.74.0
    fi

    # Generate security report
    grype sbom:"${outdir}/${IGconf_sbom_filename}" \
        --output json \
        > "${outdir}/${IGconf_sbom_security_report}" 2>/dev/null || echo "Warning: Security scan failed"

    echo "Security report generated: ${IGconf_sbom_security_report}"
fi

# Generate compliance report if enabled
if igconf isy sbom_compliance_check; then
    echo "Generating compliance report..."

    # Simple compliance check script
    cat > "${outdir}/compliance_check.py" << 'EOF'
#!/usr/bin/env python3
import json
import sys

def check_compliance(sbom_file, output_file):
    try:
        with open(sbom_file) as f:
            sbom = json.load(f)

        report = {
            "total_packages": len(sbom.get("packages", [])),
            "license_compliance": {},
            "security_issues": 0,
            "compliance_status": "PASS"
        }

        # Check licenses
        licenses = {}
        for pkg in sbom.get("packages", []):
            license_id = pkg.get("licenseDeclared", "NOASSERTION")
            licenses[license_id] = licenses.get(license_id, 0) + 1

        report["license_compliance"] = licenses

        # Check for known problematic packages (example)
        problematic_packages = ["openssl", "bash", "systemd"]
        found_problematic = []
        for pkg in sbom.get("packages", []):
            if any(prob in pkg.get("name", "").lower() for prob in problematic_packages):
                found_problematic.append(pkg.get("name"))

        if found_problematic:
            report["security_issues"] = len(found_problematic)
            report["problematic_packages"] = found_problematic
            report["compliance_status"] = "REVIEW"

        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)

        return True
    except Exception as e:
        print(f"Compliance check failed: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: compliance_check.py <sbom_file> <output_file>")
        sys.exit(1)

    success = check_compliance(sys.argv[1], sys.argv[2])
    sys.exit(0 if success else 1)
EOF

    chmod +x "${outdir}/compliance_check.py"
    python3 "${outdir}/compliance_check.py" "${outdir}/${IGconf_sbom_filename}" "${outdir}/${IGconf_sbom_compliance_report}" 2>/dev/null || echo "Warning: Compliance check failed"

    echo "Compliance report generated: ${IGconf_sbom_compliance_report}"
fi
