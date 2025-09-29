#!/bin/bash
#
# RAID External Layer Test Framework
# Comprehensive testing for RAID external layer functionality
#

set -eu

TEST_DIR="$(dirname "$0")"
RAID_LAYER_DIR="$(dirname "$TEST_DIR")/image/mbr/raid1-external"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Framework Functions
# ============================================================================

print_header() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN} RAID External Layer Test Suite${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
}

print_test() {
    local test_name="$1"
    echo -e "${YELLOW}[TEST]${NC} $test_name"
    ((TESTS_RUN++))
}

print_result() {
    local result="$1"
    local message="$2"

    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        ((TESTS_FAILED++))
    fi
}

print_summary() {
    echo
    echo -e "${GREEN}================================${NC}"
    echo "Test Summary:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo -e "${GREEN}================================${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# ============================================================================
# Individual Test Functions
# ============================================================================

test_layer_metadata() {
    print_test "Layer metadata validation"

    if [[ -f "$RAID_LAYER_DIR/image.yaml" ]]; then
        # Check if metadata file exists and is readable
        if grep -q "X-Env-Layer-Name: raid-external" "$RAID_LAYER_DIR/image.yaml"; then
            print_result "PASS" "Layer metadata file exists and contains correct layer name"
        else
            print_result "FAIL" "Layer metadata missing or incorrect"
            return 1
        fi
    else
        print_result "FAIL" "Layer metadata file not found"
        return 1
    fi
}

test_variable_prefixes() {
    print_test "Variable prefixes validation"

    if grep -q "X-Env-VarPrefix: raid_external" "$RAID_LAYER_DIR/image.yaml"; then
        print_result "PASS" "Variable prefix is correct (raid_external)"

        # Check that variables use the correct prefix
        if grep -q "X-Env-Var-raid_external_" "$RAID_LAYER_DIR/image.yaml"; then
            print_result "PASS" "Variables use correct raid_external prefix"
        else
            print_result "FAIL" "Variables don't use raid_external prefix"
            return 1
        fi
    else
        print_result "FAIL" "Variable prefix is incorrect"
        return 1
    fi
}

test_dependencies() {
    print_test "Dependencies validation"

    if grep -q "X-Env-Layer-Requires: image-base,raid-base,mdadm-tools" "$RAID_LAYER_DIR/image.yaml"; then
        print_result "PASS" "Correct dependencies specified"
    else
        print_result "FAIL" "Incorrect or missing dependencies"
        return 1
    fi
}

test_genimage_paths() {
    print_test "Genimage paths validation"

    local issues=0

    # Check ext4 genimage file
    if [[ -f "$RAID_LAYER_DIR/genimage.cfg.in.ext4" ]]; then
        if grep -q '$(readlink -ef ../setup.sh)' "$RAID_LAYER_DIR/genimage.cfg.in.ext4"; then
            print_result "PASS" "Ext4 genimage uses correct absolute paths"
        else
            print_result "FAIL" "Ext4 genimage has incorrect paths"
            ((issues++))
        fi
    else
        print_result "FAIL" "Ext4 genimage file not found"
        ((issues++))
    fi

    # Check btrfs genimage file
    if [[ -f "$RAID_LAYER_DIR/genimage.cfg.in.btrfs" ]]; then
        if grep -q '$(readlink -ef ../setup.sh)' "$RAID_LAYER_DIR/genimage.cfg.in.btrfs"; then
            print_result "PASS" "Btrfs genimage uses correct absolute paths"
        else
            print_result "FAIL" "Btrfs genimage has incorrect paths"
            ((issues++))
        fi
    else
        print_result "FAIL" "Btrfs genimage file not found"
        ((issues++))
    fi

    return $issues
}

test_provisioning_maps() {
    print_test "Provisioning maps validation"

    local issues=0

    # Check clear provisioning map
    if [[ -f "$RAID_LAYER_DIR/device/provisionmap-clear.json" ]]; then
        if grep -q '"PMAPversion": "1.2.0"' "$RAID_LAYER_DIR/device/provisionmap-clear.json" && \
           grep -q '"system_type": "slotted"' "$RAID_LAYER_DIR/device/provisionmap-clear.json"; then
            print_result "PASS" "Clear provisioning map has correct PMAP 1.2.0 structure"
        else
            print_result "FAIL" "Clear provisioning map has incorrect structure"
            ((issues++))
        fi
    else
        print_result "FAIL" "Clear provisioning map not found"
        ((issues++))
    fi

    # Check encrypted provisioning map
    if [[ -f "$RAID_LAYER_DIR/device/provisionmap-crypt.json" ]]; then
        if grep -q '"PMAPversion": "1.2.0"' "$RAID_LAYER_DIR/device/provisionmap-crypt.json" && \
           grep -q '"system_type": "slotted"' "$RAID_LAYER_DIR/device/provisionmap-crypt.json"; then
            print_result "PASS" "Encrypted provisioning map has correct PMAP 1.2.0 structure"
        else
            print_result "FAIL" "Encrypted provisioning map has incorrect structure"
            ((issues++))
        fi
    else
        print_result "FAIL" "Encrypted provisioning map not found"
        ((issues++))
    fi

    return $issues
}

test_security_features() {
    print_test "Security features validation"

    local issues=0

    # Check for security-related files
    if [[ -f "$RAID_LAYER_DIR/key-management.sh" ]]; then
        print_result "PASS" "Key management script exists"
    else
        print_result "FAIL" "Key management script not found"
        ((issues++))
    fi

    if [[ -f "$RAID_LAYER_DIR/integrity-check.sh" ]]; then
        print_result "PASS" "Integrity check script exists"
    else
        print_result "FAIL" "Integrity check script not found"
        ((issues++))
    fi

    # Check for performance optimization script
    if [[ -f "$RAID_LAYER_DIR/performance-optimization.sh" ]]; then
        print_result "PASS" "Performance optimization script exists"
    else
        print_result "FAIL" "Performance optimization script not found"
        ((issues++))
    fi

    return $issues
}

test_configuration_examples() {
    print_test "Configuration examples validation"

    local issues=0

    # Check test files exist
    local test_files=(
        "test-raid-external-validation.yaml"
        "test-raid-external-raid0.yaml"
        "test-raid-external-raid5.yaml"
        "test-raid-external-raid10.yaml"
        "test-raid-external-performance.yaml"
    )

    for test_file in "${test_files[@]}"; do
        if [[ -f "$(dirname "$TEST_DIR")/$test_file" ]]; then
            print_result "PASS" "Test configuration $test_file exists"
        else
            print_result "FAIL" "Test configuration $test_file not found"
            ((issues++))
        fi
    done

    # Check that configurations use correct variable names
    for test_file in "${test_files[@]}"; do
        if [[ -f "$(dirname "$TEST_DIR")/$test_file" ]]; then
            if grep -q "raid_external_" "$(dirname "$TEST_DIR")/$test_file"; then
                print_result "PASS" "Test configuration $test_file uses correct raid_external_ prefix"
            else
                print_result "FAIL" "Test configuration $test_file doesn't use raid_external_ prefix"
                ((issues++))
            fi
        fi
    done

    return $issues
}

test_documentation() {
    print_test "Documentation validation"

    if [[ -f "$RAID_LAYER_DIR/README.md" ]]; then
        # Check if README contains key sections
        if grep -q "## Features" "$RAID_LAYER_DIR/README.md" && \
           grep -q "## Configuration" "$RAID_LAYER_DIR/README.md" && \
           grep -q "## Examples" "$RAID_LAYER_DIR/README.md"; then
            print_result "PASS" "README contains required sections"
        else
            print_result "FAIL" "README missing required sections"
            return 1
        fi
    else
        print_result "FAIL" "README not found"
        return 1
    fi
}

test_enterprise_compliance() {
    print_test "Enterprise compliance validation"

    local issues=0

    # Check for enterprise features in metadata
    if grep -q "X-Env-Layer-Homepage:" "$RAID_LAYER_DIR/image.yaml" && \
       grep -q "X-Env-Layer-BugTracker:" "$RAID_LAYER_DIR/image.yaml" && \
       grep -q "X-Env-Layer-Support:" "$RAID_LAYER_DIR/image.yaml"; then
        print_result "PASS" "Enterprise metadata fields present"
    else
        print_result "FAIL" "Enterprise metadata fields missing"
        ((issues++))
    fi

    # Check for security variables
    if grep -q "raid_external_encryption_enabled" "$RAID_LAYER_DIR/image.yaml" && \
       grep -q "raid_external_key_method" "$RAID_LAYER_DIR/image.yaml"; then
        print_result "PASS" "Security configuration variables present"
    else
        print_result "FAIL" "Security configuration variables missing"
        ((issues++))
    fi

    return $issues
}

test_integration_capabilities() {
    print_test "Integration capabilities validation"

    local issues=0

    # Check for CI/CD integration examples
    if grep -q "GitHub Actions" "$RAID_LAYER_DIR/README.md" || \
       grep -q "parallel" "$RAID_LAYER_DIR/README.md"; then
        print_result "PASS" "CI/CD integration examples present"
    else
        print_result "FAIL" "CI/CD integration examples missing"
        ((issues++))
    fi

    # Check for enterprise use cases
    if grep -q "Enterprise" "$RAID_LAYER_DIR/README.md" && \
       grep -q "Automotive\|Industrial\|Medical" "$RAID_LAYER_DIR/README.md"; then
        print_result "PASS" "Enterprise use cases documented"
    else
        print_result "FAIL" "Enterprise use cases not documented"
        ((issues++))
    fi

    return $issues
}

test_performance_optimizations() {
    print_test "Performance optimizations validation"

    local issues=0

    # Check for performance variables
    if grep -q "raid_external_apt_cache" "$RAID_LAYER_DIR/image.yaml" && \
       grep -q "raid_external_ccache" "$RAID_LAYER_DIR/image.yaml" && \
       grep -q "raid_external_parallel_jobs" "$RAID_LAYER_DIR/image.yaml"; then
        print_result "PASS" "Performance optimization variables present"
    else
        print_result "FAIL" "Performance optimization variables missing"
        ((issues++))
    fi

    # Check for performance scripts
    if [[ -f "$RAID_LAYER_DIR/performance-optimization.sh" ]]; then
        print_result "PASS" "Performance optimization script exists"
    else
        print_result "FAIL" "Performance optimization script not found"
        ((issues++))
    fi

    return $issues
}

# ============================================================================
# Main Test Runner
# ============================================================================

run_all_tests() {
    print_header

    # Run all test functions
    test_layer_metadata
    test_variable_prefixes
    test_dependencies
    test_genimage_paths
    test_provisioning_maps
    test_security_features
    test_configuration_examples
    test_documentation
    test_enterprise_compliance
    test_integration_capabilities
    test_performance_optimizations

    # Print summary
    print_summary
}

# ============================================================================
# Test Execution
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
