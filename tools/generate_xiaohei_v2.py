#!/usr/bin/env python3
"""
Compatibility entrypoint for rebuilding Xiaohei assets.

The old procedural frame generator has been retired. Use
tools/build_xiaohei_assets.py for the public-source sticker/GIF pipeline.
"""

from build_xiaohei_assets import build_assets


if __name__ == "__main__":
    build_assets()
