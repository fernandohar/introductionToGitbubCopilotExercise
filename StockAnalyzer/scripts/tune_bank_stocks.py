"""CLI entry for bank stock tuning."""

from app.bank_tuning import tune_banks

if __name__ == "__main__":
    import json

    print(json.dumps(tune_banks(years=10.0), indent=2))
