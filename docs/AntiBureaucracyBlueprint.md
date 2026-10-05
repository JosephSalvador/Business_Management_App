# Jolinx Anti-Bureaucracy Product Blueprint

> "Jolinx should adapt to the way business happens, instead of forcing business to adapt to software."

---

## 1. Universal Business Actions

Every business action in Jolinx maps to one of these core actions. The same engine handles all of them — the product type, unit, and business context determine the behavior.

| Action | Description | Examples |
|--------|-------------|----------|
| **Sell** | A product or service leaves the business | Retail sale, wholesale delivery, service charge |
| **Buy / Receive** | A product or service enters the business | Purchase from supplier, goods received, stock intake |
| **Move** | Something changes location or ownership internally | Stock transfer between branches, cash moved to safe |
| **Pay / Receive Money** | Money flows in or out | Customer payment, supplier payment, expense |
| **Owe / Credit** | A debt is created or settled | Credit sale, debt payment, supplier credit |
| **Transform** | A product is split, combined, or modified | Break-bulk (carton → pieces), bundle creation, recipe use |
| **Adjust** | A correction or change is recorded | Stock correction, price update, return |

### One Action, Many Effects

A single `SELL` action triggers:

```
SELL 6 WATER BOTTLES
      │
      ├── Sale Created
      ├── Stock Movement: -6
      ├── Payment: +3,000
      ├── Cash Balance: +3,000
      ├── Revenue: +3,000
      ├── Customer Ledger: if credit → +3,000
      ├── Activity Feed: Sale completed
      └── Audit Trail: Who sold, when, where
```

No separate module for inventory. No separate module for payments. No separate module for customer accounts. One action → one source of truth → multiple automatic effects.

---

## 2. Universal Business Objects

These are the core nouns of the system. Every business type uses them, but the details vary.

| Object | What it holds |
|--------|---------------|
| **Product** | Name, category, selling units, purchase units, stock unit, pricing |
| **Unit** | Piece, carton, bag, meter, kg — with conversion rules |
| **Stock** | Quantity, location, batch, expiry (if applicable) |
| **Money** | Cash, mobile money, bank — with balances and movements |
| **Customer** | Name, phone (optional), credit balance, purchase history |
| **Supplier** | Name, phone, products supplied, debt owed |
| **Sale** | What was sold, to whom, how, when, for how much |
| **Purchase** | What was bought, from whom, how, when, for how much |
| **Account** | Ledger entries for customers, suppliers, cash, bank |

### Product + Selling Units + Conversion Rules

One business item can have many ways of being sold:

| Business | Parent Unit | Selling Unit | Conversion |
|----------|-------------|--------------|------------|
| Maji | Crate (24) | Bottle | 1 crate = 24 bottles |
| Sabuni | Whole bar | Piece | 1 bar = 10 pieces |
| Cement | Bag | Kg | 1 bag = 50 kg |
| Sugar | Sack | Kg | 1 sack = 100 kg |
| Hardware | Box of screws | Single screw | 1 box = 100 pieces |
| Fabric | Roll | Meter | 1 roll = 50 meters |
| Chicken | Whole chicken | Pieces | 1 chicken = 12 pieces |
| Drinks | Carton | Bottle | 1 carton = 12 bottles |

The system supports multiple unit contexts:

- **Purchase unit** — how you buy from suppliers
- **Stock unit** — how you track inventory
- **Selling unit** — how you sell to customers
- **Pricing unit** — how prices are set
- **Reporting unit** — how reports display

---

## 3. Business Types

Jolinx serves different businesses with the same engine, adapting behavior based on type.

| Business Type | Key Differences |
|---------------|-----------------|
| **Mangi / Kibanda** | Many small sales, cash, low-value items, limited time |
| **Mama wa Duka** | Retail, neighbor credit, reja reja products |
| **Grocery / Mini Market** | Many products, expiry tracking, fast stock turnover |
| **Hardware** | Different units, heavy items, negotiated prices, credit |
| **Wholesaler** | Cartons + pieces, bulk pricing, supplier debt |
| **Pharmacy** | Batch, expiry, controlled stock, compliance |
| **Restaurant** | Ingredients, recipes, wastage, table orders |
| **Salon / Barber** | Services, appointments, products |
| **Mobile Money Agent** | Cash float, deposits, withdrawals, commissions |
| **Boutique** | Sizes, colors, variants, returns |
| **Spare Parts** | Compatibility, part numbers, slow-moving stock |
| **Hotel** | Rooms, bookings, services, deposits |
| **Workshop** | Jobs, parts, labor, customer balances |
| **Small Manufacturer** | Raw materials → finished goods |
| **Large Distributor** | Warehouses, branches, sales teams, approvals |

### Common Pattern

All businesses follow one fundamental flow:

```
Something comes in → Something happens → Something goes out → Money is affected → Someone needs to know
```

The Business OS handles this pattern. The business type determines the details.

---

## 4. Business Levels

Jolinx grows with the business. Complexity is unlocked progressively, not forced upfront.

| Level | What They Need | Typical User |
|-------|----------------|--------------|
| **Small** | Sell, Buy, Stock, Credit, Cash, Simple report | Mangi, mama wa duka |
| **Middle** | Multiple users, Supplier management, Purchase orders, Stock transfers, Pricing, Expenses, Reports, Credit limits | Shop owner, hardware, grocery |
| **Large** | Branches, Warehouses, Approvals, Roles, Audit, Financial controls, Consolidated reports, Advanced inventory, Integration, Compliance | Distributor, multi-branch business |

### Progressive Complexity

The system starts with what the business needs today:

```
Day 1:     Uza → Cash → Done
Week 1:    Add products, track stock
Month 1:   Add credit, supplier purchases
Month 6:   Multiple users, reports
Year 1:    Branches, approvals, advanced controls
```

Small business is never exposed to 50 modules on day one.

---

## 5. Anti-Bureaucracy Rules

These are the things the seller should **never** be forced to do.

### Never Force

- ❌ Create a product before making a quick sale
- ❌ Fill 10 fields to record one transaction
- ❌ Open 5 separate modules to record one action
- ❌ Enter customer phone number, email, address, and date of birth for a cash sale
- ❌ Understand accounting terminology to use the system
- ❌ Manually calculate change, stock remaining, or debt balances
- ❌ Enter the same data twice in different places
- ❌ Wait for internet to complete a sale
- ❌ Learn software concepts before doing business

### Always Provide

- ✅ Record what happened, not paperwork
- ✅ One action → all records update automatically
- ✅ Smart defaults that reduce decisions
- ✅ Human language, not software jargon
- ✅ Numbers over text (6 → 3,000 → 5,000 → 2,000)
- ✅ Icons + words, not icons alone
- ✅ Offline-first capability
- ✅ Exception handling for real business situations

---

## 6. UX Principles

### 1. Action-First, Not Form-First

Bad:
```
Create Sale → Add Customer → Add Product → Select Unit → Enter Quantity → Select Payment → Submit
```

Good:
```
Uza → [product] → [quantity] → [payment] → Done
```

The system asks only what it needs, when it needs it.

### 2. One Screen, One Decision

Never show 20 options at once. Show one question at a time:

```
Unauza nini?
     ↓
Unauza kiasi gani?
     ↓
Umelipwa vipi?
     ↓
Done.
```

This is progressive disclosure — complexity appears only when needed.

### 3. Use Familiar Language

| Technical Term | Seller Language |
|----------------|-----------------|
| Product Variant | Aina / Size |
| Unit of Measure | Kipimo |
| Stock Movement | Mwendo wa bidhaa |
| Customer Account | Daftari la mteja |
| Accounts Receivable | Madeni ya wateja |
| Purchase Order | Oda ya kununua |
| Goods Receipt | Bidhaa zilizopokelewa |
| Inventory Adjustment | Rekebisha stock |
| Conversion | Gawanya / Badilisha |
| Credit Sale | Kopesha |
| Hold Cart | Subiri |
| Resume Cart | Endelea |

Backend maintains technical precision. Frontend uses human language.

### 4. Use Numbers More Than Text

Mfanyabiashara understands:

```
6 → 3,000 → 5,000 → 2,000
```

This is the language of business. Not paragraphs.

### 5. Icons + Words, Not Icons Alone

- "Kopesha" is better than a wallet icon alone
- "Katakata" is better than a scissors icon alone
- "Subiri" is better than a pause icon alone

Icons support understanding. They don't replace it.

### 6. Don't Force Registration for Every Action

Customer says: "Nipe razor blade moja."

Bad: "Create product first."

Good: Quick Sale → 300 → Done

Later, optionally: "Unataka kuihifadhi kama bidhaa ya kudumu?"

Optional setup, not a blocker.

### 7. Don't Force Customer Profiles

Cash sale: No profile needed.

Credit sale: Needs ledger entry.

For credit: "Baba Kigo → 300 → Kopesha" — that's enough to start.

---

## 7. Domain Architecture

### Anti-Bureaucracy Engine

```
                    JOLINX BUSINESS OS
                           │
             ┌─────────────┴─────────────┐
             │                           │
       EXPERIENCE LAYER             BUSINESS ENGINE
             │                           │
      ┌──────┼──────┐            ┌───────┼────────┐
      │      │      │            │       │        │
    Quick  Business Control     Sales  Inventory Finance
    Mode    Mode    Mode         │       │        │
      │      │      │            │       │        │
      └──────┴──────┴────────────┴───────┴────────┘
                           │
                    BUSINESS MEMORY
                           │
                    PostgreSQL
```

### Critical Rule: UI Does Not Build Business Logic

Flutter sends actions:
```
"I want to sell this product."
```

Backend processes actions:
```
"I received a sale action. I will update stock, payment, debt, and history."
```

This keeps the system secure, consistent, and scalable.

### Three Modes

| Mode | For | Features |
|------|-----|----------|
| **Quick Mode** | Mangi, kibanda, mama wa duka, busy cashier | Big buttons, few fields, quick quantity, quick payment, quick credit |
| **Business Mode** | Shop owner, hardware, grocery, restaurant, wholesaler | Products, purchases, stock, customers, suppliers, reports, staff |
| **Control Mode** | Multi-branch, warehouses, managers, accountants | Permissions, workflows, audit, budgets, consolidation, advanced reporting |

One engine. Different views based on business type, user role, scale, and needs.

---

## 8. Offline & Security Principles

### Offline-First (Not Optional)

For many African businesses, internet is not guaranteed.

**Must work offline:**
- Sale saved locally
- Stock reduced locally
- Receipt generated locally
- Credit recorded locally
- Held cart saved locally
- Sync happens later
- Conflicts handled safely

**Exception: Mobile money**

The system can record: "Customer selected Airtel Money."

It must NOT say: "Payment successful."

Until payment confirmation is received.

Offline-first ≠ fake payment confirmation.

### Security Underneath

The business owner sees simplicity. The system enforces discipline:

- Stock cannot go negative without reason
- Same sale cannot be recorded twice
- Who changed a price is tracked
- Who gave product without payment is logged
- Customer debt is always accurate
- Expected cash vs actual cash is reconciled
- Product split from whole is tracked
- Mobile money transaction completion is verified
- Supplier payment status is accurate
- Branch stock transfers are logged

> Simple outside. Serious inside.

---

## 9. Smart Defaults

The system reduces decisions without hiding important controls.

### Product Setup

Instead of 15 fields, ask 4:

1. Jina la bidhaa?
2. Unauza kwa bei gani?
3. Una stock ngapi?
4. Unauza kwa Mche au Kipande?

System fills the rest:

| Field | Default |
|-------|---------|
| Warehouse | Main Store |
| Selling unit | Piece |
| Price list | Retail |
| Payment method | Cash |
| Customer | Walk-in Customer |

### Defaults Are Not Assumptions

Important settings require explicit configuration:

- Tax rules
- Credit limits
- Conversion rates
- Cost method
- Permissions
- Financial settings

Smart defaults = fewer decisions. Not fewer controls.

---

## 10. Exception Handling

Real business is not a straight line. The system handles exceptions gracefully.

### Core Exceptions

| Exception | System Response |
|-----------|-----------------|
| Hold / Resume | Save cart, continue later |
| Return / Refund | Record return, adjust stock, refund payment |
| Exchange | Swap product, adjust difference |
| Partial Payment | Record amount paid, track remaining |
| Credit Sale | Create debt, track balance |
| Partial Credit Payment | Reduce debt, record payment |
| Discount | Apply discount, record reason |
| Open Price | Let seller enter price |
| Quick Sale | Bypass product setup |
| Break-Bulk | Split whole into pieces |
| Stock Adjustment | Correct stock with reason |
| Supplier Return | Return to supplier, adjust stock |
| Customer Return | Accept return, adjust stock |
| Cancelled Sale | Void transaction, restore stock |
| Offline Sale | Save locally, sync later |
| Pending Payment | Track incomplete payment |

### The Anti-Bureaucracy Response

Bad system: "Huwezi kufanya hivyo."

Good system: "Sawa. Hebu tufanye kwa njia sahihi."

---

## 11. Business Memory

The system is not just a data entry tool. It remembers the business.

### Example Queries

> "Yule supplier wa soda alinipa bei gani wiki iliyopita?"

Response: "Ulinunua crate ya soda kwa 18,000 TSh tarehe 2 Septemba."

> "Baba Kigo ana deni kiasi gani?"

Response: "300 TSh."

> "Sabuni ya Jamaa imebaki kiasi gani?"

Response: "9 Miche na 3 Vipande."

> "Nani alitoa stock hii?"

Response: "Cashier A, tarehe 5 Septemba."

### What Makes This Possible

- Events table (every action recorded)
- Ledger entries (every financial movement)
- Stock movements (every quantity change)
- Audit trail (who did what, when, where)

---

## 12. MVP Scope — What We Build First

Based on the Anti-Bureaucracy principles, the MVP focuses on:

### Core Actions (Must Have)

1. **Quick Sale** — Sell product, record payment, update stock
2. **Credit Sale** — Sell on credit, track customer debt
3. **Receive Payment** — Record customer debt payment
4. **Purchase** — Buy from supplier, record stock received
5. **Stock View** — See current stock levels
6. **Basic Report** — Daily sales, stock summary

### Core Objects (Must Have)

1. Product (name, price, stock, unit)
2. Customer (name, phone — optional)
3. Supplier (name, phone)
4. Sale record
5. Purchase record
6. Stock movement
7. Cash ledger

### Core UX (Must Have)

1. One-tap quick sale
2. Smart defaults everywhere
3. Human language (Kiswahili)
4. Offline-first
5. Simple reports with numbers

---

## 13. Future Expansion — What We Leave for Later

These are important but not MVP:

| Feature | Why Later |
|---------|-----------|
| Multi-branch | Requires approval workflows |
| Warehouse management | Requires location tracking |
| Advanced accounting | Requires chart of accounts |
| Barcode scanning | Requires product setup |
| Recipe management | Requires transformation engine |
| Batch/expiry tracking | Requires batch system |
| Mobile money integration | Requires payment provider |
| AI insights | Requires data accumulation |
| Multi-currency | Requires exchange rate system |
| API integrations | Requires stable API surface |

---

## 14. The 10 Principles

1. **Action-first** — Record what happened, not paperwork.
2. **One business engine** — Same core logic for small, middle, and large businesses.
3. **Progressive complexity** — Start simple; unlock complexity as the business grows.
4. **Human language** — Use the words people already use in their business.
5. **Smart defaults** — Reduce decisions without hiding important controls.
6. **Flexible selling** — Whole, piece, open price, quick sale, credit, returns.
7. **Business memory** — Every important action becomes useful history.
8. **Offline-first** — Business continues even when the network does not.
9. **Serious controls** — Security, audit, permissions, and financial correctness stay underneath.
10. **Grow without changing systems** — A kibanda can become a shop, wholesaler, or multi-branch business without starting over.

---

## 15. The Real Mission

Jolinx is not POS software.

> "We make business management simple enough for anyone, while giving every business the power to grow."

Kwa Kiswahili:

> "Tunafanya uendeshaji wa biashara uwe rahisi kwa kila mtu, huku tukipa kila biashara uwezo wa kukua."

Kwa African context:

> "Mfumo wa biashara unaoelewa jinsi watu wanavyofanya biashara halisi — kwa urahisi, kwa usalama, na bila bureaucracy isiyo ya lazima."

---

*This document is the guiding vision for Jolinx Business OS. All implementation decisions should align with these principles.*
