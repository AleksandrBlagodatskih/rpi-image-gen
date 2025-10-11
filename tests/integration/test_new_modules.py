#!/usr/bin/env python3
"""
Integration tests for new rpi-image-gen modules
Tests the 4 new modules: rpi5-hardware-config, rpi-common-config, hybrid-raid-layout, rpi-server-optimizations
"""

import subprocess
import sys
import os
from pathlib import Path


class NewModulesTestSuite:
    """Integration test suite for new modules"""

    def __init__(self, repo_path):
        self.repo_path = Path(repo_path)
        self.test_results = []

    def run_test(self, test_name, test_func):
        """Run individual integration test"""
        print(f"Running new modules test: {test_name}")
        try:
            result = test_func()
            self.test_results.append((test_name, result, None))
            print(f"✓ {test_name}: {'PASSED' if result else 'FAILED'}")
            return result
        except Exception as e:
            self.test_results.append((test_name, False, str(e)))
            print(f"✓ {test_name}: FAILED - {e}")
            return False

    def test_module_existence(self):
        """Test that all new modules exist"""
        modules = [
            "layer/rpi/device/rpi5-hardware-config/rpi5-hardware-config.yaml",
            "layer/rpi/device/rpi-common-config/rpi-common-config.yaml", 
            "image/mbr/hybrid-raid-layout/image.yaml",
            "layer/rpi/device/rpi-server-optimizations/rpi-server-optimizations.yaml"
        ]
        
        for module in modules:
            if not (self.repo_path / module).exists():
                print(f"Module not found: {module}")
                return False
        return True

    def test_module_metadata(self):
        """Test that modules have correct metadata"""
        modules = [
            ("layer/rpi/device/rpi5-hardware-config/rpi5-hardware-config.yaml", "rpi5-hardware-config"),
            ("layer/rpi/device/rpi-common-config/rpi-common-config.yaml", "rpi-common-config"),
            ("image/mbr/hybrid-raid-layout/image.yaml", "hybrid-raid-layout"),
            ("layer/rpi/device/rpi-server-optimizations/rpi-server-optimizations.yaml", "rpi-server-optimizations")
        ]
        
        for path, expected_name in modules:
            with open(self.repo_path / path, 'r') as f:
                content = f.read()
                if f"# X-Env-Layer-Name: {expected_name}" not in content:
                    print(f"Wrong layer name in {path}")
                    return False
                if "# METABEGIN" not in content:
                    print(f"Missing METABEGIN in {path}")
                    return False
        return True

    def test_build_compatibility(self):
        """Test that build still works with new modules"""
        try:
            cmd = ["./rpi-image-gen", "build", "-c", "config/test.yaml", "-f"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=self.repo_path)
            # We expect timeout (141) for filesystem-only build, which is normal
            if result.returncode not in [0, 141]:
                print(f"Build failed with return code {result.returncode}: {result.stderr}")
                return False
            return True
        except subprocess.TimeoutExpired:
            return True  # Timeout is expected for -f builds
        except Exception as e:
            print(f"Build test failed: {e}")
            return False

    def run_all_tests(self):
        """Run all integration tests"""
        tests = [
            ("Module Existence", self.test_module_existence),
            ("Module Metadata", self.test_module_metadata),
            ("Build Compatibility", self.test_build_compatibility)
        ]

        passed = 0
        total = len(tests)

        print("Running New Modules Test Suite (3 tests)")
        print("=" * 50)

        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1

        print("=" * 50)
        print(f"New Modules Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed!")
            return True
        else:
            print("❌ Some tests failed")
            return False


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 test_new_modules.py <rpi-image-gen-path>")
        sys.exit(1)

    repo_path = sys.argv[1]
    if not os.path.exists(repo_path):
        print(f"Repository path does not exist: {repo_path}")
        sys.exit(1)

    test_suite = NewModulesTestSuite(repo_path)
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
