#!/usr/bin/env python3
"""Refuse to publish a catalog that lost a big share of a source's cameras.

The builder skips a district or source whose feed fails, so one bad feed doesn't sink a
local run. In the scheduled build that would push a hole in coverage to every phone, so the
workflow runs this first and keeps the published copy when it fails.

Usage: python3 tools/check_catalog.py NEW [PUBLISHED] [--max-drop 0.2]
Exits 1 if any source in PUBLISHED shrank by more than --max-drop in NEW, or is missing.
"""

import argparse
import json
import os
import sys
from collections import Counter


def counts(path):
    with open(path) as f:
        return Counter(cam["source"] for cam in json.load(f)["cameras"])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("new")
    parser.add_argument("published", nargs="?")
    parser.add_argument("--max-drop", type=float, default=0.2)
    args = parser.parse_args()

    new = counts(args.new)
    if not new:
        sys.exit("check: the new catalog has no cameras")
    if not args.published or not os.path.exists(args.published):
        print(f"check: nothing published yet; {sum(new.values())} cameras", file=sys.stderr)
        return

    old = counts(args.published)
    failed = False
    for source, before in sorted(old.items()):
        after = new.get(source, 0)
        ok = after >= before * (1 - args.max_drop)
        failed |= not ok
        print(f"check: {source} {before} -> {after}{'' if ok else '  (too few)'}", file=sys.stderr)
    if failed:
        sys.exit(f"check: a source lost more than {args.max_drop:.0%} of its cameras; not publishing")


if __name__ == "__main__":
    main()
