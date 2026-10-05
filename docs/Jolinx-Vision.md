# Jolinx Business OS — Vision & Feature Roadmap

> "Jolinx — simamia biashara yako yote sehemu moja."
>
> Every sale creates a trace. Every shilling has a story. Every stock movement has a reason.
> And the owner can understand the business without being physically present.

---

## 1. Identity

Jolinx is **not a POS**. It is a **Business Operating System** for Tanzanian and East
African small and growing businesses.

The POS is one part. The real product is:

```
Sales + Stock + Money + Customers + Staff + Branches + Business Intelligence
```

### What makes it different

- Built **from the reality of African businesses** (cash + mobile money, credit, stock
  between locations, owners not always at the shop, intermittent internet, informal
  workflows)
- **Not** a Western ERP translated into Swahili
- Architecture scales from one shop → wholesaler → multi-branch business

---

## 2. Current State — What Exists

### Foundation (Strong)

| Layer | Status | Details |
|-------|--------|---------|
| Auth & RBAC | ✅ Done | JWT + refresh, permissions, tenant isolation |
| Organizations & Branches | ✅ Done | Multi-branch, branch-scoped operations |
| Product Catalog | ✅ Done | Products, variants, categories, brands, units |
| Inventory | ✅ Done | Warehouses, stock locations, movements, balances |
| Pricing Engine | ✅ Done | Price lists, per-branch/type pricing, resolution |
| Sales POS | ✅ Done | Full sale flow, stock debit, idempotency, offline |
| Tax Engine | ✅ Done | `TZ_DUAL_VAT`, strategy pattern, deferred to provider |
| Accounting | ✅ Done | Chart of accounts, journal entries, trial balance |
| Reporting | ✅ Done | Tax summary, sales summary, top products, CSV export |
| Offline-First | ✅ Done | 72h offline window, sync engine, conflict handling |
| Dashboard (Backend) | ✅ Done | Summary KPIs, low-stock, recent activity |

### Partial (Backend exists, UI incomplete)

| Feature | What's Done | What's Missing |
|---------|-------------|----------------|
| Credit System | `PaymentMethod.Credit` enum, customer entity | No balance tracking UI, no "who owes me?" screen |
| Stock Story | `LowStockQuery` backend | No "days left" calc, no sales velocity, no reorder alerts |
| Tax Integration | `TaxEngine`, `FiscalStatus` enum | No TRA API, fiscal receipts are placeholders |

### Not Done

| Feature | Status |
|---------|--------|
| Cash & Money Accountability | No implementation |
| Owner Mode | No implementation |
| AI Business Assistant | No implementation |
| WhatsApp Integration | No implementation |

---

## 3. Priority Roadmap

### 🔴 P0 — Cash & Money Accountability

**The most important missing feature.**

The owner's primary question: **"Fedha yangu iko wapi?"** (Where is my money?)

#### Cash Accountability

```
MORNING
  Opening cash: TSh 100,000

DURING THE DAY
  Cash sales       +600,000
  M-Pesa sales     +350,000
  Airtel Money     +150,000
  Credit sales     +100,000
  ─────────────────────────
  TOTAL SALES    1,200,000

  Business expense   -30,000
  Cash withdrawal    -50,000

CLOSING
  Expected cash:  620,000
  Actual cash:    605,000
  ⚠️ DIFFERENCE:  -15,000
```

#### Money Accounts (Not just payment methods)

Treat Cash, M-Pesa, Airtel, Bank as **business money accounts**:

```
BUSINESS MONEY
  Cash           TSh   620,000
  M-Pesa         TSh 1,240,000
  Airtel Money   TSh   320,000
  Bank           TSh 2,450,000
```

Transactions move money between accounts:

```
Customer pays M-Pesa → M-Pesa +20,000
Transfer M-Pesa → Bank → M-Pesa -500,000, Bank +500,000
```

---

### 🔴 P0 — Credit / Customer Balances

Critical for local commerce. Turn `PaymentMethod.Credit` into a proper receivables system.

```
CUSTOMER: Juma Traders

Outstanding:     TSh 450,000
Credit limit:    TSh 1,000,000
Last payment:    TSh 100,000

TRANSACTION HISTORY
  +150,000   Sale
  -100,000   Payment
  +250,000   Sale
  -50,000    Payment
  ─────────────────
   450,000   Balance
```

Owner can ask: **"Nani ananidai?"** (Who owes me?)

---

### 🟠 P1 — Owner Mode

Not another complicated dashboard. Answers five questions:

```
LEO BIASHARA YAKO

1. Mauzo:          TSh 1,240,000
2. Fedha iliyopokelewa:
   Cash            620,000
   M-Pesa          350,000
   Airtel          150,000
3. Stock:           183 items sold
                    12 low-stock items
4. Credit:          7 customers, TSh 420,000 outstanding
5. AttENTION:
   ⚠️ Cash variance: 15,000
   ⚠️ 5 products nearly out
   ⚠️ TSh 120,000 overdue credit
```

---

### 🟠 P1 — Stock Story

Simple mathematics, not complex AI prediction:

```
COCA-COLA

Current stock:     30
Last 5 days sold:  10, 8, 12, 10, 9
Average/day:       9.8

Estimated days left: 3.06

⚠️ Coca-Cola inaweza kuisha ndani ya siku 3.
```

---

### 🟡 P2 — Business Insights

**"Why did my money change?"**

Every important number should be explainable:

```
CASH DECREASED BY TSh 80,000

  TSh 50,000   Cash withdrawal
  TSh 20,000   Transport expense
  TSh 10,000   Other expense
```

```
STOCK DECREASED BY TSh 450,000

  Sales             380,000
  Damaged stock      40,000
  Stock adjustment   30,000
```

---

### 🟡 P2 — Expenses

Complete the money picture with expense tracking and categorization.

---

### 🟢 P3 — AI Business Assistant

Only after good business data exists.

```
Q: "Kwa nini mauzo yameshuka?"

A: Mauzo yameshuka 14%.

   Sababu kuu:
   1. Coca-Cola       ↓ 24%
   2. Rice            ↓ 18%
   3. Branch A        ↓ 20%
   4. Stock-outs: 5 products
   5. Credit sales    ↑ 31%
```

---

### 🟢 P3 — WhatsApp Integration

Business queries via WhatsApp:

```
Q: "Jolinx, mauzo ya leo?"

A: Mauzo ya leo:
   TSh 2,340,000
   Cash: 1,120,000
   M-Pesa: 820,000
   Credit: 400,000
```

---

### 🔵 Later — TRA Integration

Deferred capability. Keep `TaxEngine` infrastructure but don't connect to TRA until
authorized provider/API is available.

```
Jolinx
  ├── Business Engine
  ├── Inventory
  ├── Sales
  ├── Payments
  └── Fiscal Integration (future)
         │
    Authorized Provider
         │
        TRA
```

---

## 4. Architectural Principles

### Money is a first-class concept

- Every payment method is a **money account** with a balance
- Transactions move money between accounts
- Cash opening/closing is a core workflow
- Variance detection is automatic

### Every number is explainable

- Sales can be drilled into (by product, by branch, by time)
- Stock changes have reasons (sale, damage, adjustment, transfer)
- Cash movements are traced (sale, expense, withdrawal, transfer)
- The owner can always ask "why?"

### Business events create a timeline

- Every important action creates a **business event**
- Events are part of the **business memory**
- The timeline shows what happened, when, and why

### Credit is real commerce

- Customer balances update in real-time
- Payment history is visible
- Credit limits are enforceable
- Overdue tracking is automatic

---

## 5. Feature Implementation Status

| # | Feature | Backend | Flutter UI | Status |
|---|---------|---------|------------|--------|
| 1 | Cash Accountability | ❌ | ❌ | Not Started |
| 2 | Money Accounts | ❌ | ❌ | Not Started |
| 3 | Credit System | ⚠️ Partial | ❌ | Partial |
| 4 | Owner Mode | ❌ | ❌ | Not Started |
| 5 | Stock Story | ⚠️ Partial | ❌ | Partial |
| 6 | Business Insights | ❌ | ❌ | Not Started |
| 7 | Expenses | ⚠️ Partial | ⚠️ Partial | Partial |
| 8 | AI Assistant | ❌ | ❌ | Not Started |
| 9 | WhatsApp | ❌ | ❌ | Not Started |
| 10 | TRA Integration | ⚠️ Infrastructure | ❌ | Deferred |

---

## 6. What NOT to Build

- ❌ Complex dashboards with colors and charts (keep it simple)
- ❌ AI chatbots nobody needs (build after data exists)
- ❌ Western ERP patterns (build from African business reality)
- ❌ TRA integration before authorized provider exists
- ❌ Feature-rich screens (every screen earns its place)

---

## 7. The Big Promise

> **"Internet ikikatika, biashara haikomi."**
> (When internet cuts, business continues.)

> **"Kila bei ina stori. Kila shilingi ina mahali."**
> (Every price has a story. Every shilling has a place.)

> **"Simamia biashara yako popote ulipo."**
> (Manage your business wherever you are.)
