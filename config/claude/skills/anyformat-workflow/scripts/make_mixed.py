# /// script
# requires-python = ">=3.11"
# dependencies = ["reportlab", "faker"]
# ///
"""Generate a 3-page mixed PDF hitting invoice / packages / flights splitter categories.

Run: uv run ~/.claude/skills/anyformat-workflow/scripts/make_mixed.py [out_dir]
     (out_dir defaults to /tmp/anyformat-demo)

Produces:
  - mixed.pdf  — page 1 invoice, page 2 package label, page 3 boarding pass

One page per branch means the document_splitter routes exactly one page
to each downstream extract node, producing real extracted values in all
three child extraction tabs.
"""

import random
import sys
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

fake = Faker()
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/anyformat-demo")
OUT.mkdir(parents=True, exist_ok=True)

# Fixed vendor list so a companion CSV (vendor_catalog.csv) can demonstrate
# smart_lookup joins. `draw_invoice` picks one at random and prints its name;
# any CSV whose `vendor_name` column includes these will join cleanly.
VENDORS = [
    ("V-0001", "Acme Industries"),
    ("V-0002", "Globex Corporation"),
    ("V-0003", "Initech LLC"),
    ("V-0004", "Umbrella Logistics"),
    ("V-0005", "Stark Enterprises"),
    ("V-0006", "Wayne Freight Co"),
    ("V-0007", "Oceanic Traders"),
    ("V-0008", "Hooli Supplies"),
]


def draw_invoice(c: canvas.Canvas) -> dict:
    W, H = letter
    issue = fake.date_between(start_date="-90d", end_date="today")
    due = issue + timedelta(days=random.choice([14, 30, 45, 60]))
    currency = random.choice(["USD", "EUR", "GBP"])
    symbol = {"USD": "$", "EUR": "€", "GBP": "£"}[currency]
    vendor = random.choice(VENDORS)[1]
    number = f"INV-{fake.year()}-{random.randint(1000, 9999)}"

    c.setFont("Helvetica-Bold", 22); c.drawString(inch, H - inch, "INVOICE")
    y = H - 1.6 * inch
    c.setFont("Helvetica", 11)
    c.drawString(inch, y, f"Invoice #: {number}"); y -= 16
    c.drawString(inch, y, f"Issue date: {issue.isoformat()}"); y -= 16
    c.drawString(inch, y, f"Due date:   {due.isoformat()}"); y -= 16
    c.drawString(inch, y, f"Currency:   {currency}"); y -= 28

    c.setFont("Helvetica-Bold", 12); c.drawString(inch, y, f"From: {vendor}"); y -= 16
    c.setFont("Helvetica", 10); c.drawString(inch, y, fake.address().replace("\n", ", ")); y -= 28
    c.setFont("Helvetica-Bold", 12); c.drawString(inch, y, f"Bill to: {fake.company()}"); y -= 28

    c.setFont("Helvetica-Bold", 10)
    c.drawString(inch, y, "Description")
    c.drawString(4.5 * inch, y, "Qty")
    c.drawString(5.2 * inch, y, "Unit price")
    c.drawString(6.5 * inch, y, "Amount")
    y -= 14; c.line(inch, y, W - inch, y); y -= 14

    c.setFont("Helvetica", 10)
    subtotal = 0.0
    for _ in range(random.randint(2, 5)):
        qty = random.randint(1, 10)
        unit = round(random.uniform(12, 450), 2)
        amt = qty * unit
        subtotal += amt
        c.drawString(inch, y, fake.bs().title()[:40])
        c.drawString(4.5 * inch, y, str(qty))
        c.drawString(5.2 * inch, y, f"{symbol}{unit:,.2f}")
        c.drawString(6.5 * inch, y, f"{symbol}{amt:,.2f}")
        y -= 14

    tax = round(subtotal * 0.1, 2); total = round(subtotal + tax, 2)
    y -= 18
    c.drawString(5 * inch, y, f"Subtotal: {symbol}{subtotal:,.2f}"); y -= 14
    c.drawString(5 * inch, y, f"Tax (10%): {symbol}{tax:,.2f}"); y -= 14
    c.setFont("Helvetica-Bold", 12); c.drawString(5 * inch, y, f"TOTAL: {symbol}{total:,.2f}")

    return {
        "invoice_number": number,
        "issue_date": issue.isoformat(),
        "vendor_name": vendor,
        "total_amount": total,
        "currency": currency,
    }


def draw_package_label(c: canvas.Canvas) -> dict:
    W, H = letter
    tracking = "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789", k=12))
    carrier = random.choice(["UPS", "FedEx", "DHL", "USPS"])
    sender_name = fake.name()
    sender_addr = fake.address().replace("\n", ", ")
    recipient_name = fake.name()
    recipient_addr = fake.address().replace("\n", ", ")
    weight_kg = round(random.uniform(0.3, 25.0), 2)
    ship_date = fake.date_between(start_date="-14d", end_date="today")
    service = random.choice(["Ground", "Express", "Priority Overnight", "2-Day Air"])

    c.setFont("Helvetica-Bold", 26); c.drawString(inch, H - inch, "SHIPPING LABEL")
    c.setFont("Helvetica-Bold", 14); c.drawString(inch, H - 1.35 * inch, f"Carrier: {carrier}")

    y = H - 2 * inch
    c.setFont("Helvetica-Bold", 13); c.drawString(inch, y, "TRACKING NUMBER"); y -= 18
    c.setFont("Courier-Bold", 20); c.drawString(inch, y, tracking); y -= 30

    c.setFont("Helvetica-Bold", 11); c.drawString(inch, y, "FROM (Sender):"); y -= 14
    c.setFont("Helvetica", 10)
    c.drawString(inch, y, sender_name); y -= 12
    c.drawString(inch, y, sender_addr); y -= 22

    c.setFont("Helvetica-Bold", 11); c.drawString(inch, y, "TO (Recipient):"); y -= 14
    c.setFont("Helvetica", 10)
    c.drawString(inch, y, recipient_name); y -= 12
    c.drawString(inch, y, recipient_addr); y -= 22

    c.setFont("Helvetica", 10)
    c.drawString(inch, y, f"Weight: {weight_kg} kg"); y -= 14
    c.drawString(inch, y, f"Service: {service}"); y -= 14
    c.drawString(inch, y, f"Ship date: {ship_date.isoformat()}"); y -= 14

    c.setFont("Courier", 8)
    c.drawString(inch, 1.2 * inch, "|" * 80)
    c.drawString(inch, 1.0 * inch, "| | |   ||  ||| | ||   || |   |||  |  ||||  | || | |   ||")
    c.setFont("Helvetica", 8); c.drawString(inch, 0.8 * inch, tracking)

    return {
        "tracking_number": tracking,
        "carrier": carrier,
        "sender_name": sender_name,
        "recipient_name": recipient_name,
        "weight_kg": weight_kg,
        "ship_date": ship_date.isoformat(),
    }


def draw_boarding_pass(c: canvas.Canvas) -> dict:
    W, H = letter
    airlines = [("American Airlines", "AA"), ("Lufthansa", "LH"), ("United", "UA"), ("Iberia", "IB"), ("British Airways", "BA")]
    airline_name, airline_code = random.choice(airlines)
    flight_number = f"{airline_code}{random.randint(100, 9999)}"
    passenger = fake.name().upper()
    airports = [("JFK", "New York"), ("LHR", "London"), ("MAD", "Madrid"), ("FRA", "Frankfurt"),
                ("CDG", "Paris"), ("LAX", "Los Angeles"), ("NRT", "Tokyo"), ("SFO", "San Francisco")]
    origin, destination = random.sample(airports, 2)
    departure = datetime.now() + timedelta(days=random.randint(1, 30), hours=random.randint(0, 23))
    seat = f"{random.randint(1, 45)}{random.choice('ABCDEF')}"
    gate = f"{random.choice('ABCDE')}{random.randint(1, 40)}"
    boarding = departure - timedelta(minutes=30)
    pnr = "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", k=6))

    c.setFont("Helvetica-Bold", 28); c.drawString(inch, H - inch, "BOARDING PASS")
    c.setFont("Helvetica-Bold", 16); c.drawString(inch, H - 1.4 * inch, airline_name)

    y = H - 2.2 * inch
    c.setFont("Helvetica", 10); c.drawString(inch, y, "PASSENGER NAME"); y -= 14
    c.setFont("Helvetica-Bold", 16); c.drawString(inch, y, passenger); y -= 30

    c.setFont("Helvetica", 10); c.drawString(inch, y, "FLIGHT"); c.drawString(3.5 * inch, y, "DATE"); c.drawString(5.5 * inch, y, "SEAT"); y -= 14
    c.setFont("Helvetica-Bold", 18)
    c.drawString(inch, y, flight_number)
    c.drawString(3.5 * inch, y, departure.strftime("%d %b %Y"))
    c.drawString(5.5 * inch, y, seat)
    y -= 36

    c.setFont("Helvetica", 10); c.drawString(inch, y, "FROM"); c.drawString(4 * inch, y, "TO"); y -= 16
    c.setFont("Helvetica-Bold", 22)
    c.drawString(inch, y, origin[0]); c.drawString(4 * inch, y, destination[0]); y -= 16
    c.setFont("Helvetica", 11)
    c.drawString(inch, y, origin[1]); c.drawString(4 * inch, y, destination[1]); y -= 30

    c.setFont("Helvetica", 10); c.drawString(inch, y, "DEPARTURE"); c.drawString(3 * inch, y, "BOARDING"); c.drawString(5 * inch, y, "GATE"); y -= 14
    c.setFont("Helvetica-Bold", 14)
    c.drawString(inch, y, departure.strftime("%H:%M"))
    c.drawString(3 * inch, y, boarding.strftime("%H:%M"))
    c.drawString(5 * inch, y, gate); y -= 30

    c.setFont("Helvetica", 10); c.drawString(inch, y, f"Booking reference: {pnr}"); y -= 14
    c.drawString(inch, y, f"Class: {random.choice(['Economy', 'Premium Economy', 'Business'])}"); y -= 14

    c.setFont("Courier", 8)
    c.drawString(inch, 1.2 * inch, "||| | || |||  | |||| ||  | || ||| | |  ||| || | |||  | | |||")

    return {
        "flight_number": flight_number,
        "airline": airline_name,
        "passenger_name": passenger,
        "origin": origin[0],
        "destination": destination[0],
        "departure_time": departure.isoformat(timespec="minutes"),
        "seat": seat,
    }


def make_mixed(path: Path) -> dict:
    c = canvas.Canvas(str(path), pagesize=letter)
    invoice = draw_invoice(c); c.showPage()
    package = draw_package_label(c); c.showPage()
    flight = draw_boarding_pass(c); c.showPage()
    c.save()

    truth = {"invoice": invoice, "packages": package, "flights": flight}
    print(f"[mixed] {path.name}:")
    for cat, fields in truth.items():
        print(f"  {cat}: {fields}")
    return truth


def make_vendor_catalog(path: Path) -> None:
    """CSV companion for smart_lookup demos on the invoice branch."""
    lines = ["vendor_id,vendor_name,contact_email,payment_terms"]
    for vid, vname in VENDORS:
        slug = vname.lower().replace(" ", "").replace(",", "")
        terms = random.choice(["Net 15", "Net 30", "Net 45", "Net 60"])
        lines.append(f"{vid},{vname},ap@{slug}.example,{terms}")
    path.write_text("\n".join(lines) + "\n")
    print(f"[catalog] {path.name}: {len(VENDORS)} vendors")


def make_airline_codes(path: Path) -> None:
    """CSV companion for master_file demos on the flights branch.

    Covers every airline that `draw_boarding_pass` may emit, so the
    reference-guided extraction always has a matching row to anchor on.
    """
    rows = [
        ("AA", "American Airlines", "USA"),
        ("LH", "Lufthansa", "Germany"),
        ("UA", "United", "USA"),
        ("IB", "Iberia", "Spain"),
        ("BA", "British Airways", "UK"),
    ]
    lines = ["airline_code,airline_name,country"]
    for code, name, country in rows:
        lines.append(f"{code},{name},{country}")
    path.write_text("\n".join(lines) + "\n")
    print(f"[airlines] {path.name}: {len(rows)} airlines")


if __name__ == "__main__":
    make_mixed(OUT / "mixed.pdf")
    make_vendor_catalog(OUT / "vendor_catalog.csv")
    make_airline_codes(OUT / "airline_codes.csv")
    print(f"\nwrote to {OUT}")
