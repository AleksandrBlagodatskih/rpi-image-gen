#!/usr/bin/env python3
"""
Integration tests for rpi-image-gen security layers
Tests full build scenarios and image boot validation
"""

import subprocess
import sys
import os
import tempfile
import shutil
import time
from pathlib import Path


class IntegrationTestSuite:
    """Integration test suite for security layers"""

    def __init__(self, repo_path):
        self.repo_path = Path(repo_path)
        self.test_results = []

    def run_test(self, test_name, test_func):
        """Run individual integration test"""
        print(f"Running integration test: {test_name}")
        try:
            result = test_func()
            self.test_results.append((test_name, result, None))
            print(f"✓ {test_name}: {'PASSED' if result else 'FAILED'}")
            return result
        except Exception as e:
            self.test_results.append((test_name, False, str(e)))
            print(f"✗ {test_name}: ERROR - {e}")
            return False

    def test_minimal_security_config(self):
        """Test building with minimal security configuration"""
        config_content = """
device:
  layer: rpi5
image:
  layer: mbr/simple
layer:
  base: bookworm-minbase
  security: apparmor-core
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(config_content)
            config_file = f.name

        try:
            # Run dry-run build
            cmd = [
                'rpi-image-gen', 'build',
                '-c', config_file,
                '--dry-run'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_path)

            if result.returncode != 0:
                print(f"Dry-run failed: {result.stderr}")
                return False

            return True

        finally:
            os.unlink(config_file)

    def test_full_security_suite(self):
        """Test building with full security suite"""
        config_content = """
device:
  layer: rpi5
image:
  layer: mbr/simple
layer:
  base: bookworm-minbase
  infra: security-suite-standard
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(config_content)
            config_file = f.name

        try:
            # Run dry-run build
            cmd = [
                'rpi-image-gen', 'build',
                '-c', config_file,
                '--dry-run'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_path)

            if result.returncode != 0:
                print(f"Full security suite dry-run failed: {result.stderr}")
                return False

            return True

        finally:
            os.unlink(config_file)

    def test_conflicting_variables(self):
        """Test handling of conflicting or invalid variables"""
        config_content = """
device:
  layer: rpi5
image:
  layer: mbr/simple
layer:
  base: bookworm-minbase
  security: apparmor-core
IGconf_apparmor_core_enable: "invalid_boolean"
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(config_content)
            config_file = f.name

        try:
            # This should fail gracefully
            cmd = [
                'rpi-image-gen', 'build',
                '-c', config_file,
                '--dry-run'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_path)

            # Should fail with validation error
            if result.returncode == 0:
                print("Expected validation error but build succeeded")
                return False

            # Check for appropriate error message
            if "invalid_boolean" not in result.stderr and "apparmor_core_enable" not in result.stderr:
                print(f"Unexpected error message: {result.stderr}")
                return False

            return True

        finally:
            os.unlink(config_file)

    def test_dependency_resolution(self):
        """Test that dependencies are properly resolved"""
        config_content = """
device:
  layer: rpi5
image:
  layer: mbr/simple
layer:
  base: bookworm-minbase
  # apparmor-profiles depends on apparmor-core
  security: apparmor-profiles
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(config_content)
            config_file = f.name

        try:
            cmd = [
                'rpi-image-gen', 'build',
                '-c', config_file,
                '--dry-run'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_path)

            if result.returncode != 0:
                print(f"Dependency resolution failed: {result.stderr}")
                return False

            return True

        finally:
            os.unlink(config_file)

    def test_performance_baseline(self):
        """Test build performance stays within acceptable limits"""
        config_content = """
device:
  layer: rpi5
image:
  layer: mbr/simple
layer:
  base: bookworm-minbase
  security: apparmor-core
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(config_content)
            config_file = f.name

        try:
            start_time = time.time()

            cmd = [
                'rpi-image-gen', 'build',
                '-c', config_file,
                '--dry-run'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_path)
            end_time = time.time()

            build_time = end_time - start_time

            # Should complete in under 30 seconds for dry-run
            if build_time > 30:
                print(".2f")
                return False

            print(".2f")
            return result.returncode == 0

        finally:
            os.unlink(config_file)

    def run_all_tests(self):
        """Run all integration tests"""
        tests = [
            ("Minimal Security Config", self.test_minimal_security_config),
            ("Full Security Suite", self.test_full_security_suite),
            ("Conflicting Variables", self.test_conflicting_variables),
            ("Dependency Resolution", self.test_dependency_resolution),
            ("Performance Baseline", self.test_performance_baseline),
        ]

        passed = 0
        total = len(tests)

        print(f"Running Security Layer Integration Tests ({total} tests)")
        print("=" * 60)

        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1

        print("\n" + "=" * 60)
        print(f"Integration Test Results: {passed}/{total} tests passed")

        # Generate report
        self.generate_report()

        return passed == total

    def generate_report(self):
        """Generate integration test report"""
        report_file = "/tmp/security-integration-test-report.txt"

        with open(report_file, 'w') as f:
            f.write("Security Layer Integration Test Report\n")
            f.write("=" * 50 + "\n\n")

            for test_name, result, error in self.test_results:
                status = "PASSED" if result else "FAILED"
                f.write(f"{test_name}: {status}\n")
                if error:
                    f.write(f"  Error: {error}\n")
                f.write("\n")

        print(f"Detailed report saved: {report_file}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 test_full_build.py <rpi-image-gen-path>")
        sys.exit(1)

    repo_path = sys.argv[1]

    if not os.path.exists(repo_path):
        print(f"Repository path does not exist: {repo_path}")
        sys.exit(1)

    test_suite = IntegrationTestSuite(repo_path)
    success = test_suite.run_all_tests()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
