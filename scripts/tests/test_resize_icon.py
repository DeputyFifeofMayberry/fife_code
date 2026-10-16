#!/usr/bin/env python3
"""Reproduction tests for the resize_icon.py portability fix (LOC-14 adoption).

RED before the fix: the module imported Pillow at load time and hard-coded the
original author's absolute /Users/grapeot/... paths, so it could not even be
imported (no Pillow) or resolve paths (any other checkout). GREEN after: paths
resolve relative to the repository root with CLI overrides, Pillow is imported
lazily, and a missing source exits cleanly with code 2.
"""

import os
import sys
import unittest

# This file lives in scripts/tests/, so the scripts dir (import root for
# resize_icon) is one level up, and the repo root is two levels up.
SCRIPTS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(SCRIPTS_DIR)
sys.path.insert(0, SCRIPTS_DIR)

import resize_icon  # noqa: E402

# This suite may be run against a scripts-only copy; the full-checkout test
# needs the real repo layout, so guard it on a repo-root marker file.
_FULL_CHECKOUT = os.path.isfile(os.path.join(REPO_ROOT, "docs", "logo_light.png"))


class ResizeIconPathTests(unittest.TestCase):
    def test_module_imports_and_exposes_path_resolution(self):
        # The fix moved `from PIL import Image` inside resize_icon(); the module
        # must stay importable and testable on machines without Pillow.
        self.assertTrue(hasattr(resize_icon, "resolve_paths"),
                        "resize_icon.resolve_paths is missing")

    @unittest.skipUnless(_FULL_CHECKOUT,
                         "full repo layout not present in this copy "
                         "(scripts-only checkout)")
    def test_paths_resolve_inside_this_checkout(self):
        source, target = resize_icon.resolve_paths()
        repo_root = REPO_ROOT
        self.assertEqual(source, os.path.join(repo_root, "docs", "logo_light.png"))
        self.assertTrue(os.path.isfile(source), f"missing repo logo: {source}")
        expected_target = os.path.join(
            repo_root, "OpenCodeClient", "OpenCodeClient",
            "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
        self.assertEqual(target, expected_target)
        self.assertTrue(os.path.isdir(os.path.dirname(target)),
                        f"missing appiconset dir: {os.path.dirname(target)}")

    def test_overrides_are_honored(self):
        source, target = resize_icon.resolve_paths("/tmp/a.png", "/tmp/b/c.png")
        self.assertEqual(source, os.path.abspath("/tmp/a.png"))
        self.assertEqual(target, os.path.abspath("/tmp/b/c.png"))

    def test_missing_source_exits_cleanly_with_two(self):
        missing = os.path.join(SCRIPTS_DIR, "no-such-source.png")
        rc = resize_icon.resize_icon(missing, os.path.join(SCRIPTS_DIR, "unused-out.png"))
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
