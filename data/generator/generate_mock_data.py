#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["faker~=40.0"]
# ///
"""Generates mock e-commerce CSVs into data/seed/. Deterministic via --seed, so the
committed CSVs can be regenerated (modulo Faker version drift) if needed.

Usage (uv resolves the faker dependency itself, no venv/pip step needed):
    uv run data/generator/generate_mock_data.py [--seed 42] [--out-dir ../seed]
"""

import argparse
import csv
import os
import random
from datetime import datetime, timedelta

from faker import Faker

N_CUSTOMERS = 500
N_PRODUCTS = 200
N_ORDERS = 5000
N_ORDER_ITEMS_PER_ORDER = (1, 5)

CATEGORIES = ["electronics", "home", "apparel", "books", "toys", "grocery", "sports"]
ORDER_STATUSES = ["placed", "shipped", "delivered", "cancelled", "returned"]


def generate(seed: int, out_dir: str) -> None:
    fake = Faker()
    Faker.seed(seed)
    random.seed(seed)

    os.makedirs(out_dir, exist_ok=True)

    signup_start = datetime(2022, 1, 1)
    signup_end = datetime(2026, 1, 1)

    with open(os.path.join(out_dir, "customers.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["customer_id", "first_name", "last_name", "email", "signup_date", "country"])
        for customer_id in range(1, N_CUSTOMERS + 1):
            signup_date = fake.date_between(start_date=signup_start, end_date=signup_end)
            writer.writerow([
                customer_id,
                fake.first_name(),
                fake.last_name(),
                fake.unique.email(),
                signup_date.isoformat(),
                fake.country_code(),
            ])

    product_created_start = datetime(2021, 1, 1)
    with open(os.path.join(out_dir, "products.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["product_id", "name", "category", "unit_price", "created_at"])
        for product_id in range(1, N_PRODUCTS + 1):
            created_at = fake.date_time_between(start_date=product_created_start, end_date="now")
            writer.writerow([
                product_id,
                fake.unique.catch_phrase(),
                random.choice(CATEGORIES),
                round(random.uniform(5, 500), 2),
                created_at.isoformat(sep=" "),
            ])

    order_date_start = datetime(2023, 1, 1)
    order_date_end = datetime(2026, 9, 6)

    orders_rows = []
    order_items_rows = []
    order_item_id = 1

    for order_id in range(1, N_ORDERS + 1):
        customer_id = random.randint(1, N_CUSTOMERS)
        order_date = fake.date_between(start_date=order_date_start, end_date=order_date_end)
        status = random.choice(ORDER_STATUSES)

        n_items = random.randint(*N_ORDER_ITEMS_PER_ORDER)
        order_total = 0.0
        for _ in range(n_items):
            product_id = random.randint(1, N_PRODUCTS)
            quantity = random.randint(1, 4)
            unit_price = round(random.uniform(5, 500), 2)
            order_items_rows.append([order_item_id, order_id, product_id, quantity, unit_price])
            order_total += quantity * unit_price
            order_item_id += 1

        orders_rows.append([order_id, customer_id, order_date.isoformat(), status, round(order_total, 2)])

    with open(os.path.join(out_dir, "orders.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["order_id", "customer_id", "order_date", "status", "total_amount"])
        writer.writerows(orders_rows)

    with open(os.path.join(out_dir, "order_items.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["order_item_id", "order_id", "product_id", "quantity", "unit_price"])
        writer.writerows(order_items_rows)

    print(f"wrote {N_CUSTOMERS} customers, {N_PRODUCTS} products, {N_ORDERS} orders, "
          f"{len(order_items_rows)} order_items to {out_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-dir", default=os.path.join(os.path.dirname(__file__), "..", "seed"))
    args = parser.parse_args()
    generate(args.seed, args.out_dir)
