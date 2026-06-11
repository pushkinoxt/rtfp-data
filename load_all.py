"""
Run all loaders for one provider's filing bundle.

Usage:
    python load_all.py --provider linkedin \\
        --period 2025-h2 \\
        --bundle /Users/pushkin/Documents/DSAPROJECT/duck-dsa-reports/raw/linkedin/2025h2
"""
import argparse
import subprocess
import sys

LOADERS = [
    "load_member_state_orders.py",
    "load_article16_notices.py",
    "load_own_initiative_illegal.py",
    "load_own_initiative_tc.py",
    "load_indicators.py",
    "load_qualitative_indicators.py",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True)
    parser.add_argument("--period", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--service-name", default=None,
                        help="pass through to each loader to target one service of a "
                             "multi-service provider (e.g. 'YouTube' vs 'YouTube Ads').")
    args = parser.parse_args()

    failures = []
    for loader in LOADERS:
        print(f"\n=== Running {loader} ===")
        cmd = [
            sys.executable, loader,
            "--provider", args.provider,
            "--period", args.period,
            "--bundle", args.bundle,
        ]
        if args.service_name:
            cmd += ["--service-name", args.service_name]
        result = subprocess.run(cmd)
        if result.returncode != 0:
            failures.append(loader)

    print("\n" + "=" * 50)
    if failures:
        print(f"FAILED loaders ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print(f"All {len(LOADERS)} loaders succeeded.")


if __name__ == "__main__":
    main()
