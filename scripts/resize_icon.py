#!/usr/bin/env python3
"""Regenerate the 1024x1024 App Store icon from docs/logo_light.png.

Paths resolve inside this checkout by default (repo-relative), with optional
CLI overrides: resize_icon.py [source_image] [target_path]. Pillow is imported
lazily so the module stays importable (and testable) on machines without it.
"""

import os
import sys


def resolve_paths(source=None, target=None):
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(scripts_dir)
    default_source = os.path.join(repo_root, "docs", "logo_light.png")
    default_target = os.path.join(
        repo_root, "OpenCodeClient", "OpenCodeClient",
        "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
    resolved_source = os.path.abspath(source) if source else default_source
    resolved_target = os.path.abspath(target) if target else default_target
    return resolved_source, resolved_target


def resize_icon(source=None, target=None):
    source, target = resolve_paths(source, target)
    if not os.path.isfile(source):
        print(f"Source image not found: {source}", file=sys.stderr)
        return 2
    try:
        from PIL import Image
    except ImportError:
        print("Pillow is required to resize icons: python3 -m pip install Pillow",
              file=sys.stderr)
        return 3
    with Image.open(source) as img:
        icon = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
        icon.save(target, "PNG")
    print(f"Saved {target}")
    return 0


if __name__ == "__main__":
    cli_source = sys.argv[1] if len(sys.argv) > 1 else None
    cli_target = sys.argv[2] if len(sys.argv) > 2 else None
    sys.exit(resize_icon(cli_source, cli_target))
