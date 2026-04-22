# /// script
# requires-python = ">=3.11"
# dependencies = ["reportlab", "faker"]
# ///
"""Generate fake invoice + email PDFs shaped to the anyformat splitter workflow schemas.

Run: uv run /tmp/anyformat-demo/script.py [out_dir]

Produces:
  - invoice.pdf  — hits the `invoices` branch (extract_1)
  - email.pdf    — hits the `emails`   branch (extract_2)
"""

import random
import sys
from datetime import timedelta
from pathlib import Path

from faker import Faker
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

fake = Faker()
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/anyformat-demo")
OUT.mkdir(parents=True, exist_ok=True)


def make_invoice(path: Path) -> dict:
    c = canvas.Canvas(str(path), pagesize=letter)
    W, H = letter

    issue = fake.date_between(start_date="-90d", end_date="today")
    due = issue + timedelta(days=random.choice([14, 30, 45, 60]))
    currency = random.choice(["USD", "EUR", "GBP"])
    symbol = {"USD": "$", "EUR": "€", "GBP": "£"}[currency]
    vendor = fake.company()
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

    c.save()
    truth = {
        "invoice_number": number,
        "issue_date": issue.isoformat(),
        "due_date": due.isoformat(),
        "vendor_name": vendor,
        "total_amount": total,
        "currency": currency,
    }
    print(f"[invoice] {path.name}: {truth}")
    return truth


def make_email(path: Path) -> dict:
    c = canvas.Canvas(str(path), pagesize=letter)
    W, H = letter

    sender = fake.company_email()
    recipients = [fake.company_email() for _ in range(random.randint(1, 3))]
    subject = fake.sentence(nb_words=6).rstrip(".")
    sent = fake.date_time_between(start_date="-30d", end_date="now")
    has_atts = random.random() < 0.4

    y = H - inch
    c.setFont("Helvetica-Bold", 12); c.drawString(inch, y, f"Subject: {subject}"); y -= 20
    c.setFont("Helvetica", 10)
    c.drawString(inch, y, f"From: {sender}"); y -= 14
    c.drawString(inch, y, f"To:   {', '.join(recipients)}"); y -= 14
    c.drawString(inch, y, f"Date: {sent.isoformat()}"); y -= 14
    if has_atts:
        c.drawString(inch, y, f"Attachments: {fake.word()}.pdf"); y -= 14
    y -= 10; c.line(inch, y, W - inch, y); y -= 20

    c.setFont("Helvetica", 10)
    for para in (fake.paragraph(nb_sentences=3) for _ in range(3)):
        line = ""
        for w in para.split():
            if len(line) + len(w) > 90:
                c.drawString(inch, y, line); y -= 12
                line = w
            else:
                line = (line + " " + w).strip()
        if line:
            c.drawString(inch, y, line); y -= 12
        y -= 8

    c.setFont("Helvetica-Oblique", 9)
    c.drawString(inch, inch, "-- Best regards,")
    c.drawString(inch, inch - 12, fake.name())

    c.save()
    truth = {
        "sender": sender,
        "recipients": recipients,
        "subject": subject,
        "sent_at": sent.isoformat(),
        "has_attachments": has_atts,
    }
    print(f"[email]   {path.name}: {truth}")
    return truth


if __name__ == "__main__":
    make_invoice(OUT / "invoice.pdf")
    make_email(OUT / "email.pdf")
    print(f"\nwrote to {OUT}")
