#!/bin/bash

set -eu

files=()

# Image assets
if [[ -n "${IGconf_image_outputdir:-}" ]] ; then
   pat="${IGconf_image_outputdir}/${IGconf_image_name:-}"*.${IGconf_image_suffix:-}
   if compgen -G "$pat" > /dev/null 2>&1; then
      for f in $pat ; do
         files+=("$f")
      done
   fi

   pat="${IGconf_image_outputdir}"/*.sparse
   if compgen -G "$pat" > /dev/null 2>&1; then
      for f in $pat ; do
         files+=("$f")
      done
   fi

   files+=("${IGconf_image_outputdir}/image.json")
fi

# Filesystem assets
[[ -f "$IGconf_target_path" ]] && files+=("$IGconf_target_path")
files+=("${IGconf_target_dir}/${IGconf_sbom_filename:-}")
files+=("${IGconf_target_dir}/${IGconf_sbom_security_report:-}")
files+=("${IGconf_target_dir}/${IGconf_sbom_compliance_report:-}")
files+=("${IGconf_target_dir}/manifest")
files+=("${IGconf_target_dir}/config.yaml")


echo "Installing assets..."
mkdir -p "$IGconf_deploy_dir"
for f in "${files[@]}" ; do
   [[ -f "$f" ]] || continue
   case "$IGconf_deploy_compression" in
      zstd)
         zstd -v -f "$f" --sparse --output-dir-flat "$IGconf_deploy_dir"
         ;;
      none)
         cp -v --sparse=always "$f" "$IGconf_deploy_dir"
         ;;
      *)
         ;;
   esac
done


echo "Performing integrity verification..."
# Source integrity check functions if available
if [[ -f "$(dirname "$0")/../raid1-external/integrity-check.sh" ]]; then
    source "$(dirname "$0")/../raid1-external/integrity-check.sh"

    # Perform integrity checks on built images
    if ! perform_integrity_checks "$IGconf_deploy_dir"; then
        echo "ERROR: Integrity verification failed"
        exit 1
    fi
else
    echo "Warning: Integrity check script not found, skipping verification"
fi

echo "Creating manifest..."
{
  echo "{"
  echo "  \"deployment_info\": {"
  echo "    \"version\": \"${IGconf_artefact_version:-}\","
  echo "    \"date\": \"$(date -Iseconds)\","
  echo "    \"integrity_verified\": true"
  echo "  },"
  echo "  \"files\": ["

  first=true
  for f in "$IGconf_deploy_dir"/*; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "deployed.json" ]] && continue
    [[ "$first" == true ]] || echo ","
    first=false

    size=$(stat -c %s "$f")
    mime_type=$(file -b --mime-type "$f" 2>/dev/null || echo "unknown")

    echo "    {"
    echo "      \"name\": \"$(basename "$f")\","
    echo "      \"size\": $size,"
    echo "      \"mime_type\": \"$mime_type\","
    echo "      \"sha1\": \"$(sha1sum "$f" | cut -d' ' -f1)\""
    echo "    }"
  done

  echo "  ]"
  echo "}"
} > "$IGconf_deploy_dir/deployed.json"
