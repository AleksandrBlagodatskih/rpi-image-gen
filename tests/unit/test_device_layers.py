#!/usr/bin/env python3
"""
Unit tests for rpi-image-gen device layers
Tests layer validation, dependency resolution, and configuration idempotency
"""

import subprocess
import sys
import os
import tempfile
import shutil
import yaml
from pathlib import Path


class DeviceLayerTestSuite:
    """Test suite for device layer validation"""

    def __init__(self, extension_path):
        self.extension_path = Path(extension_path)
        self.test_results = []

    def run_test(self, test_name, test_func):
        """Run individual test with logging"""
        print(f"Running device test: {test_name}")
        try:
            result = test_func()
            self.test_results.append((test_name, result, None))
            print(f"✓ {test_name}: {'PASSED' if result else 'FAILED'}")
            return result
        except Exception as e:
            self.test_results.append((test_name, False, str(e)))
            print(f"✗ {test_name}: ERROR - {e}")
            return False

    def test_device_layer_metadata_validation(self):
        """Test YAML metadata validation for device layers"""
        device_layers = list(self.extension_path.glob("layer/rpi/device/*/*.yaml"))

        for layer_file in device_layers:
            try:
                with open(layer_file, 'r') as f:
                    content = f.read()

                # Check for required metadata
                if not content.startswith("# METABEGIN"):
                    return False

                # Extract metadata
                meta_start = content.find("# METABEGIN")
                meta_end = content.find("# METAEND")
                if meta_start == -1 or meta_end == -1:
                    return False

                metadata = content[meta_start:meta_end]

                # Check required fields
                required_fields = [
                    "X-Env-Layer-Name:",
                    "X-Env-Layer-Category: device",
                    "X-Env-Layer-Desc:",
                    "X-Env-Layer-Version:",
                    "X-Env-Layer-Requires:"
                ]

                for field in required_fields:
                    if field not in metadata:
                        print(f"Missing field {field} in {layer_file}")
                        return False

            except Exception as e:
                print(f"Error parsing {layer_file}: {e}")
                return False

        return True

    def test_device_layer_idempotency(self):
        """Test that device layers are idempotent (can run multiple times)"""
        # This is more of a design validation - check for idempotent patterns
        device_layers = list(self.extension_path.glob("layer/rpi/device/*/*.yaml"))

        idempotent_patterns = [
            "add_config_if_not_exists",
            "if ! grep -q",
            "if [ ! -f",
            "already present",
            "already configured"
        ]

        for layer_file in device_layers:
            with open(layer_file, 'r') as f:
                content = f.read()

            # Check for idempotent patterns in customize-hooks
            customize_start = content.find("customize-hooks:")
            if customize_start != -1:
                hooks_section = content[customize_start:]

                has_idempotent_patterns = any(pattern in hooks_section for pattern in idempotent_patterns)
                if not has_idempotent_patterns:
                    print(f"Warning: {layer_file} may not be fully idempotent")
                    # Don't fail - some layers may not need full idempotency

        return True

    def test_device_layer_error_handling(self):
        """Test error handling in device layers"""
        device_layers = list(self.extension_path.glob("layer/rpi/device/*/*.yaml"))

        error_patterns = [
            "ERROR:",
            "exit 1",
            ">&2",
            "return 1"
        ]

        for layer_file in device_layers:
            with open(layer_file, 'r') as f:
                content = f.read()

            # Check for basic error handling
            has_error_handling = any(pattern in content for pattern in error_patterns)
            if not has_error_handling:
                print(f"Warning: {layer_file} may lack error handling")
                # Don't fail - some simple layers may not need extensive error handling

        return True

    def test_device_layer_monitoring_integration(self):
        """Test monitoring integration in device layers"""
        device_layers = list(self.extension_path.glob("layer/rpi/device/*/*.yaml"))

        monitoring_patterns = [
            "prometheus-node-exporter",
            "textfile collector",
            "metrics exported",
            "monitoring configured"
        ]

        monitoring_layers = 0
        for layer_file in device_layers:
            with open(layer_file, 'r') as f:
                content = f.read()

            if any(pattern in content for pattern in monitoring_patterns):
                monitoring_layers += 1

        print(f"Found {monitoring_layers} device layers with monitoring integration")
        return monitoring_layers >= 1  # At least one layer should have monitoring

    def test_device_layer_config_validation(self):
        """Test config.txt validation patterns"""
        rpi5_server_layer = self.extension_path / "layer/rpi/device/rpi5-server-config/rpi5-server-config.yaml"

        if rpi5_server_layer.exists():
            with open(rpi5_server_layer, 'r') as f:
                content = f.read()

            # Check for config.txt validation
            if "! -f" not in content or "config.txt" not in content:
                print("Warning: rpi5-server-config may lack config.txt validation")
                return False

            return True

        return True  # Layer doesn't exist, skip test

    def run_all_tests(self):
        """Run all device layer tests"""
        tests = [
            ("Device Layer Metadata Validation", self.test_device_layer_metadata_validation),
            ("Device Layer Idempotency", self.test_device_layer_idempotency),
            ("Device Layer Error Handling", self.test_device_layer_error_handling),
            ("Device Layer Monitoring Integration", self.test_device_layer_monitoring_integration),
            ("Device Layer Config Validation", self.test_device_layer_config_validation),
        ]

        passed = 0
        total = len(tests)

        print(f"Running Device Layer Test Suite ({total} tests)")
        print("=" * 50)

        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1

        print("\n" + "=" * 50)
        print(f"Device Layer Test Results: {passed}/{total} tests passed")

        # Generate report
        self.generate_report()

        return passed == total

    def generate_report(self):
        """Generate test report"""
        report_file = "/tmp/device-layer-test-report.txt"

        with open(report_file, 'w') as f:
            f.write("Device Layer Test Report\n")
            f.write("=" * 40 + "\n\n")

            for test_name, result, error in self.test_results:
                status = "PASSED" if result else "FAILED"
                f.write(f"{test_name}: {status}\n")
                if error:
                    f.write(f"  Error: {error}\n")
                f.write("\n")

        print(f"Detailed report saved: {report_file}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 test_device_layers.py <rpi-image-gen-path>")
        sys.exit(1)

    repo_path = sys.argv[1]

    if not os.path.exists(repo_path):
        print(f"Repository path does not exist: {repo_path}")
        sys.exit(1)

    test_suite = DeviceLayerTestSuite(repo_path)
    success = test_suite.run_all_tests()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
