"""Run walk-forward model validation and print metrics."""

from __future__ import annotations

import json
import sys

from app.validation import run_validation, run_validation_batch


def main() -> None:
    args = sys.argv[1:]
    adapt = "--no-adapt" not in args
    filtered = [a for a in args if not a.startswith("--")]

    if not filtered:
        result = run_validation_batch(["0700.HK", "9988.HK", "AAPL", "MSFT"], adapt=adapt)
    elif len(filtered) == 1:
        result = run_validation(filtered[0], adapt=adapt)
    else:
        result = run_validation_batch(filtered, adapt=adapt)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
