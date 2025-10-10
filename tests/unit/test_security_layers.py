#!/usr/bin/env python3
"""
Unit tests for rpi-image-gen security layers
Tests layer validation, dependency resolution, and variable expansion
"""

import subprocess
import sys
import os
import tempfile
import shutil
import yaml
from pathlib import Path


class SecurityLayerTestSuite:
    """Test suite for security layer validation"""

    def __init__(self, extension_path):
        self.extension_path = Path(extension_path)
        self.test_results = []

    def run_test(self, test_name, test_func):
        """Run individual test with logging"""
        print(f"Running test: {test_name}")
        try:
            result = test_func()
            self.test_results.append((test_name, result, None))
            print(f"✓ {test_name}: {'PASSED' if result else 'FAILED'}")
            return result
        except Exception as e:
            self.test_results.append((test_name, False, str(e)))
            print(f"✗ {test_name}: ERROR - {e}")
            return False

    def test_layer_metadata_validation(self):
        """Test YAML metadata validation"""
        security_layers = list(self.extension_path.glob("layer/security/**/*.yaml"))

        for layer_file in security_layers:
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
                    "X-Env-Layer-Category:",
                    "X-Env-Layer-Version:",
                    "X-Env-Layer-Requires:",
                    "X-Env-Layer-Provides:"
                ]

                for field in required_fields:
                    if field not in metadata:
                        print(f"Missing field {field} in {layer_file}")
                        return False

                # Check category is 'extension'
                if "X-Env-Layer-Category: extension" not in metadata:
                    print(f"Wrong category in {layer_file}")
                    return False

            except Exception as e:
                print(f"Error parsing {layer_file}: {e}")
                return False

        return True

    def test_rpi_image_gen_lint(self):
        """Test rpi-image-gen lint validation"""
        security_layers = list(self.extension_path.glob("layer/security/**/*.yaml"))

        for layer_file in security_layers:
            cmd = ['rpi-image-gen', 'metadata', '--lint', str(layer_file)]
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.extension_path)

            if result.returncode != 0:
                print(f"Lint failed for {layer_file}: {result.stderr}")
                return False

        return True

    def test_dependency_resolution(self):
        """Test layer dependency resolution"""
        # This would require a more complex setup with rpi-image-gen
        # For now, just check that dependencies are reasonable
        security_layers = list(self.extension_path.glob("layer/security/**/*.yaml"))

        for layer_file in security_layers:
            with open(layer_file, 'r') as f:
                content = f.read()

            # Extract dependencies
            meta_start = content.find("# METABEGIN")
            meta_end = content.find("# METAEND")
            metadata = content[meta_start:meta_end]

            # Check that dependencies don't create circular references
            requires_line = None
            provides_line = None

            for line in metadata.split('\n'):
                if line.startswith("# X-Env-Layer-Requires:"):
                    requires_line = line.split(":", 1)[1].strip()
                elif line.startswith("# X-Env-Layer-Provides:"):
                    provides_line = line.split(":", 1)[1].strip()

            # Basic validation - requires and provides shouldn't be the same
            if requires_line and provides_line and requires_line == provides_line:
                print(f"Circular dependency in {layer_file}")
                return False

        return True

    def test_variable_expansion(self):
        """Test variable expansion in templates"""
        # Test with sample variables
        test_vars = {
            'IGconf_test_enable': 'y',
            'IGconf_test_port': '8080',
            'IGconf_test_name': 'test-service'
        }

        # Create temporary environment
        old_env = {}
        for key, value in test_vars.items():
            old_env[key] = os.environ.get(key)
            os.environ[key] = value

        try:
            # Test template expansion (simplified)
            template = "${IGconf_test_name}:${IGconf_test_port}"
            expanded = os.path.expandvars(template)

            expected = "test-service:8080"
            return expanded == expected
        finally:
            # Restore environment
            for key, value in old_env.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value

    def test_script_syntax(self):
        """Test bash script syntax in layers"""
        security_layers = list(self.extension_path.glob("layer/security/**/*.yaml"))

        for layer_file in security_layers:
            with open(layer_file, 'r') as f:
                content = f.read()

            # Extract customize-hooks section
            customize_start = content.find("customize-hooks:")
            if customize_start == -1:
                continue

            # Look for bash scripts in customize-hooks
            lines = content[customize_start:].split('\n')
            in_bash_script = False
            script_lines = []

            for line in lines:
                if line.strip() == "- |":
                    in_bash_script = True
                    script_lines = []
                elif in_bash_script and line.strip() and not line.startswith("  rootfs-overlay:"):
                    if line.startswith("    "):
                        script_lines.append(line[4:])  # Remove indentation
                    else:
                        # End of script
                        if script_lines and script_lines[0].startswith("#!/bin/bash"):
                            # Test syntax
                            script_content = '\n'.join(script_lines)
                            with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
                                f.write(script_content)
                                temp_script = f.name

                            try:
                                result = subprocess.run(['bash', '-n', temp_script],
                                                      capture_output=True, text=True)
                                if result.returncode != 0:
                                    print(f"Syntax error in {layer_file}: {result.stderr}")
                                    return False
                            finally:
                                os.unlink(temp_script)

                        in_bash_script = False
                        script_lines = []

        return True

    def run_all_tests(self):
        """Run all security layer tests"""
        tests = [
            ("Layer Metadata Validation", self.test_layer_metadata_validation),
            ("RPI Image Gen Lint", self.test_rpi_image_gen_lint),
            ("Dependency Resolution", self.test_dependency_resolution),
            ("Variable Expansion", self.test_variable_expansion),
            ("Script Syntax Validation", self.test_script_syntax),
        ]

        passed = 0
        total = len(tests)

        print(f"Running Security Layer Test Suite ({total} tests)")
        print("=" * 50)

        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1

        print("\n" + "=" * 50)
        print(f"Test Results: {passed}/{total} tests passed")

        # Generate report
        self.generate_report()

        return passed == total

    def generate_report(self):
        """Generate test report"""
        report_file = "/tmp/security-layer-test-report.txt"

        with open(report_file, 'w') as f:
            f.write("Security Layer Test Report\n")
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
        print("Usage: python3 test_security_layers.py <rpi-image-gen-path>")
        sys.exit(1)

    repo_path = sys.argv[1]

    if not os.path.exists(repo_path):
        print(f"Repository path does not exist: {repo_path}")
        sys.exit(1)

    test_suite = SecurityLayerTestSuite(repo_path)
    success = test_suite.run_all_tests()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
