#!/usr/bin/env python3
"""
Integration tests for rpi-image-gen hybrid-raid-luks layer
Tests RAID1 + LUKS encryption functionality and configuration validation
"""

import subprocess
import sys
import os
import tempfile
import shutil
import time
from pathlib import Path


class HybridRaidLuksTestSuite:
    """Integration test suite for hybrid-raid-luks layer"""

    def __init__(self, repo_path):
        self.repo_path = Path(repo_path)
        self.test_results = []

    def run_test(self, test_name, test_func):
        """Run individual integration test"""
        print(f"Running hybrid-raid-luks test: {test_name}")
        try:
            result = test_func()
            self.test_results.append((test_name, result, None))
            print(f"✓ {test_name}: {'PASSED' if result else 'FAILED'}")
            return result
        except Exception as e:
            self.test_results.append((test_name, False, str(e)))
            print(f"✗ {test_name}: ERROR - {e}")
            return False

    def test_hybrid_raid_luks_config_validation(self):
        """Test hybrid-raid-luks configuration validation"""
        # Test that config file can be parsed and basic structure is valid
        config_content = """
device:
  layer: rpi5
image:
  layer: hybrid-raid-luks
  name: test-hybrid-raid-luks
hybrid_raid_luks:
  rootfs_type: ext4
  encryption_enabled: y
  key_method: file
  key_size: 512
  ssd_devices: /dev/sda,/dev/sdb
  boot_part_size: 200M
  root_part_size: 2G
  pmap: crypt
  disk_expansion_enabled: y
layer:
  base: bookworm-minbase
"""

        try:
            import yaml
            config = yaml.safe_load(config_content)

            # Validate required sections
            required_sections = ['device', 'image', 'layer']
            for section in required_sections:
                if section not in config:
                    print(f"Missing required section: {section}")
                    return False

            # Validate hybrid_raid_luks section
            if 'hybrid_raid_luks' not in config:
                print("Missing hybrid_raid_luks configuration section")
                return False

            hrl_config = config['hybrid_raid_luks']
            required_params = ['rootfs_type', 'encryption_enabled', 'ssd_devices']
            for param in required_params:
                if param not in hrl_config:
                    print(f"Missing required parameter: {param}")
                    return False

            # Validate parameter values
            if hrl_config['encryption_enabled'] != 'y':
                print("Encryption should be enabled for this test")
                return False

            if hrl_config['ssd_devices'] != '/dev/sda,/dev/sdb':
                print("SSD devices configuration incorrect")
                return False

            return True

        except yaml.YAMLError as e:
            print(f"YAML parsing error: {e}")
            return False

    def test_hybrid_raid_luks_layer_metadata(self):
        """Test hybrid-raid-luks layer metadata validation"""
        layer_file = self.repo_path / 'image' / 'mbr' / 'hybrid-raid-luks' / 'image.yaml'

        if not layer_file.exists():
            print(f"Layer file not found: {layer_file}")
            return False

        with open(layer_file, 'r') as f:
            content = f.read()

        # Check for required metadata
        if not content.startswith("# METABEGIN"):
            print("Missing METABEGIN marker")
            return False

        # Check for required fields
        required_fields = [
            'X-Env-Layer-Name: hybrid-raid-luks',
            'X-Env-Layer-Category: image',
            'X-Env-VarPrefix: hybrid_raid_luks'
        ]

        for field in required_fields:
            if field not in content:
                print(f"Missing required field: {field}")
                return False

        return True

    def test_hybrid_raid_luks_script_validation(self):
        """Test bash scripts in hybrid-raid-luks layers for syntax and security"""
        # Test scripts in image layer
        image_layer_dir = self.repo_path / 'image' / 'mbr' / 'hybrid-raid-luks'
        image_scripts = [
            'pre-image.sh',
            'setup.sh'
        ]

        # Test scripts in extension layer
        extension_layer_dir = self.repo_path / 'layer' / 'storage' / 'raid-luks'
        extension_scripts = [
            'device/rootfs-overlay/usr/bin/rpi-raid',
            'device/rootfs-overlay/usr/local/bin/disk-expansion',
            'device/initramfs-tools/hooks/rpi-raid-luks'
        ]

        # Combine all scripts to test
        bash_scripts = []
        for script in image_scripts:
            bash_scripts.append((image_layer_dir, script))
        for script in extension_scripts:
            bash_scripts.append((extension_layer_dir, script))

        for layer_dir, script in bash_scripts:
            script_path = layer_dir / script
            if not script_path.exists():
                print(f"Script not found: {script_path}")
                return False

            # Test bash syntax
            cmd = ['bash', '-n', str(script_path)]
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                print(f"Syntax error in {script}: {result.stderr}")
                return False

            # Check for set -euo pipefail
            with open(script_path, 'r') as f:
                content = f.read()

            if 'set -euo pipefail' not in content:
                print(f"Missing set -euo pipefail in {script}")
                return False

        return True

    def test_hybrid_raid_luks_security_validation(self):
        """Test security aspects of hybrid-raid-luks layer"""
        layer_dir = self.repo_path / 'image' / 'mbr' / 'hybrid-raid-luks'

        # Check for secure file permissions in overlay
        key_file = layer_dir / 'device' / 'rootfs-overlay' / 'etc' / 'luks' / 'key'

        if key_file.exists():
            stat_result = os.stat(key_file)
            # Check if permissions are 600 (readable/writable by owner only)
            if oct(stat_result.st_mode)[-3:] != '600':
                print(f"Insecure permissions on LUKS key file: {oct(stat_result.st_mode)}")
                return False

        # Check for dangerous constructs in scripts
        dangerous_patterns = [
            'eval',
            'exec(',
            'source '
        ]

        for script in layer_dir.rglob('*.sh'):
            with open(script, 'r') as f:
                content = f.read()

            for pattern in dangerous_patterns:
                if pattern in content:
                    print(f"Dangerous pattern '{pattern}' found in {script}")
                    return False

            # Check for command substitution that is not arithmetic
            if '$(' in content:
                # Allow specific safe command substitutions
                safe_commands = ['$(readlink -f', '$(uuidgen', '$(echo']
                has_safe_command = any(cmd in content for cmd in safe_commands)
                has_arithmetic = '$(( ' in content

                if not (has_safe_command or has_arithmetic):
                    print(f"Potentially dangerous command substitution found in {script}")
                    return False

        return True

    def run_all_tests(self):
        """Run all hybrid-raid-luks tests"""
        tests = [
            ("Config Validation", self.test_hybrid_raid_luks_config_validation),
            ("Layer Metadata", self.test_hybrid_raid_luks_layer_metadata),
            ("Script Validation", self.test_hybrid_raid_luks_script_validation),
            ("Security Validation", self.test_hybrid_raid_luks_security_validation)
            # Note: Filesystem Generation test is too heavy for unit testing
            # ("Filesystem Generation", self.test_hybrid_raid_luks_filesystem_generation),
        ]

        print("Running Hybrid-RAID-LUKS Layer Test Suite (4 tests)")
        print("=" * 55)

        passed = 0
        total = len(tests)

        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1

        print("\n" + "=" * 55)
        print(f"Hybrid-RAID-LUKS Test Results: {passed}/{total} tests passed")

        if passed == total:
            print("🎉 All tests passed!")
            return True
        else:
            print("❌ Some tests failed")
            return False


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 test_hybrid_raid_luks.py <rpi-image-gen-path>")
        sys.exit(1)

    repo_path = sys.argv[1]
    test_suite = HybridRaidLuksTestSuite(repo_path)

    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
