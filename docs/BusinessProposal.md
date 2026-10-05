# Jolinx Business OS — Investor Pitch

**Series A: $500K–$2M**

*Confidential — For Prospective Investors Only*

---

## Executive Summary

**Jolinx Business OS** is a Business Operating System built for the 45+ million small and medium enterprises (SMEs) in East Africa. We replace spreadsheets, paper records, and fragmented tools with a single offline-first platform that works without internet, speaks Swahili natively, and handles local payment methods (M-Pesa, Airtel Money, Tigo Pesa) as first-class citizens.

**What we are:** A platform, not a single ERP. Industry-specific modules (retail, wholesale, agriculture, school, hospital, hotel) grow on top of a shared engine — auth, RBAC, audit, events, workflows, sync, and a plugin system.

**What exists today:** A production-grade backend (.NET 10 + PostgreSQL) and Flutter mobile/desktop/web client with 858+ passing tests. Core modules live: authentication, organizations, branches, roles & permissions, product catalog, inventory, pricing engine, sales POS, tax engine, accounting, reporting, offline-first sync, and a dashboard.

**The ask:** $500K–$2M Series A to complete the commercial engine (credit, cash accountability, owner mode), expand to Kenya and Uganda, and onboard 1,000 paying businesses within 18 months.

---

## 1. Problem

### The Reality of African SMEs

| Pain Point | Current Workaround | Cost to Business |
|-----------|-------------------|-----------------|
| No internet at POS | Cash-only, no records | Lost sales, no audit trail |
| Mobile money everywhere | Manual reconciliation | Errors, fraud, time waste |
| Local tax compliance (TRA/KRA) | Accountant + paper receipts | Penalties, compliance cost |
| Multi-location inventory | Phone calls, WhatsApp | Stockouts, overstock |
| Owner not at the shop | Trust-based, no visibility | Theft, mismanagement |
| Expensive ERPs (Odoo, SAP) | Spreadsheets | No growth, no analytics |

**45M+ SMEs in East Africa.** 98% run on paper, spreadsheets, or nothing. Existing solutions (Odoo, Zoho, SAP B1) assume constant internet, single currency, Western tax rules, and English-only interfaces. They are too expensive ($50–$500/mo per user), too complex (weeks to onboard), and too fragile (offline = dead).

### Why Now?

1. **Mobile money penetration:** 70%+ of Tanzanians use M-Pesa; 80%+ in Kenya. Digital payments create the data layer.
2. **Tax digitization:** TRA (Tanzania), KRA (Kenya) mandate e-receipts and digital invoicing. Businesses need compliant systems.
3. **Post-COVID digital shift:** SMEs that survived moved to digital tools. Those that didn't are rebuilding.
4. **Smartphone adoption:** 40M+ affordable Android devices in East Africa by 2025.

---

## 2. Solution

### Jolinx Business OS — "Simamia biashara yako yote sehemu moja"

> Manage your entire business in one place.

```
┌─────────────────────────────────────────────────┐
│           Jolinx Business OS (Platform)          │
│  Auth · RBAC · Audit · Events · Sync · Plugins  │
├─────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │  Sales  │ │ Stock   │ │ Money   │           │
│  │  + POS  │ │ + Ware  │ │ + Credit│           │
│  └─────────┘ └─────────┘ └─────────┘           │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Account │ │ Reports │ │  CRM    │           │
│  └─────────┘ └─────────┘ └─────────┘           │
│  ┌─────────────────────────────────────┐        │
│  │  Industry Modules (Plugin System)   │        │
│  │  Agriculture · School · Hospital    │        │
│  │  Hotel · Logistics · Wholesale      │        │
│  └─────────────────────────────────────┘        │
└─────────────────────────────────────────────────┘
         │              │              │
     Android         Desktop          Web
     (POS)        (Multi-branch)   (Management)
```

### Core Capabilities (Live Today)

| Capability | Status | Details |
|-----------|--------|---------|
| **Offline-First POS** | ✅ Production | 72-hour offline window, idempotent sync, conflict resolution |
| **Mobile Money** | ✅ Production | M-Pesa, Airtel Money, Tigo Pesa, Mixx, HaloPesa as first-class |
| **Local Tax Engine** | ✅ Production | Dual VAT (18%/16%), strategy pattern, extensible per country |
| **Swahili UI** | ✅ Production | First-class, not translated afterthought |
| **Multi-Branch** | ✅ Production | Branch-scoped inventory, pricing, permissions |
| **Role-Based Access** | ✅ Production | Granular permissions, per-branch, per-module |
| **Audit Trail** | ✅ Production | Every mutation logged, traceable, searchable |
| **Accounting** | ✅ Production | Chart of accounts, journal entries, trial balance |
| **Reporting** | ✅ Production | Tax summary, sales summary, top products, CSV export |

### What Makes Jolinx Different

| Feature | Odoo / Zoho | SAP B1 / Dynamics | **Jolinx** |
|---------|-------------|-------------------|-----------|
| Offline POS | Weak / None | Requires internet | **Core design, 72h offline** |
| Mobile money | Add-on | Not supported | **First-class, auto-reconciliation** |
| Local tax (TRA/KRA) | Generic | Manual config | **Built-in, versioned, country-specific** |
| Swahili interface | Partial | None | **Native, not translated** |
| Onboarding time | 2–4 weeks | 2–6 months | **< 10 minutes** |
| Pricing | $50–$500/user/mo | $100+/user/mo | **Per-branch, affordable** |
| Plugin ecosystem | Mature but Western | Enterprise only | **Built-in from day one** |

---

## 3. Market Opportunity

### Total Addressable Market (TAM)

| Region | SMEs | Digital-ready | Jolinx TAM |
|--------|------|---------------|------------|
| Tanzania | 5M+ | 1.5M | $1.8B |
| Kenya | 7.5M+ | 2.5M | $3.0B |
| Uganda | 4M+ | 1.0M | $1.2B |
| **East Africa** | **16.5M+** | **5M** | **$6.0B** |
| Sub-Saharan Africa | 45M+ | 12M | **$14.4B** |

*Assumes $30/mo avg. revenue per business × 12 months*

### Serviceable Addressable Market (SAM) — Year 3

**Target:** 10,000 paying businesses × $360/yr = **$3.6M ARR**

### Serviceable Obtainable Market (SOM) — Year 1

**Target:** 1,000 paying businesses × $360/yr = **$360K ARR**

### Market Growth Drivers

1. **Tanzania e-receipt mandate (2024+):** Every business needs compliant POS
2. **Kenya KRA e-invoicing:** 500K+ businesses must digitize
3. **African Continental Free Trade Area (AfCFTA):** Cross-border commerce needs multi-currency, multi-tax systems
4. **SME digitization funds:** Government programs in Tanzania, Kenya, Uganda subsidize tech adoption

---

## 4. Business Model

### Revenue Streams

| Stream | Description | Year 1 | Year 3 |
|--------|-------------|--------|--------|
| **SaaS Subscriptions** | Per-branch monthly/annual plans | $250K | $2.5M |
| **Transaction Fees** | 0.5–1% on mobile money payments processed | $50K | $800K |
| **Plugin Marketplace** | 15–30% commission on third-party modules | $10K | $300K |
| **Enterprise / Self-Hosted** | On-premise deployments for larger chains | $50K | $500K |
| **Total** | | **$360K** | **$4.1M** |

### Pricing Tiers

| Plan | Monthly | Annual | Includes |
|------|---------|--------|----------|
| **Starter** (1 branch) | $20/mo | $200/yr | POS, inventory, 1 user, basic reports |
| **Growth** (3 branches) | $50/mo | $500/yr | + accounting, credit, 5 users, advanced reports |
| **Pro** (10 branches) | $150/mo | $1,500/yr | + multi-branch, roles, audit, 20 users |
| **Enterprise** | Custom | Custom | + self-hosted, API, custom integrations |

*Per-branch pricing aligns with how East African businesses structure operations.*

### Unit Economics (Target Year 1)

| Metric | Value |
|--------|-------|
| Average Revenue Per Account (ARPA) | $30/mo |
| Customer Acquisition Cost (CAC) | $50 |
| Lifetime Value (LTV) | $1,080 (36-mo avg.) |
| LTV:CAC Ratio | 21.6x |
| Gross Margin | 85% |
| Monthly Churn | < 5% |

---

## 5. Competitive Landscape

### Direct Competitors

| Competitor | Strengths | Weaknesses | Our Advantage |
|-----------|-----------|------------|---------------|
| **Odoo** | Mature, global, modular | Complex, expensive, no offline, no mobile money | Simplicity, offline, local payments |
| **Zoho** | Affordable, cloud-native | No offline, generic tax, no Swahili | Offline-first, country-specific |
| **SAP Business One** | Enterprise-grade | Very expensive, complex, no mobile money | SME-focused, mobile money native |
| **Kahawa** (local) | Local POS | No accounting, no inventory, no multi-branch | Full business OS, not just POS |
| **Tally** (India) | Strong accounting | No POS, no offline, no African localization | POS + accounting + offline |

### Our Moat

1. **Platform architecture:** Plugin system creates an ecosystem, not just a product
2. **Offline-first design:** Deep technical moat — competitors bolt on offline; we architect from it
3. **Local tax engine:** Versioned, country-specific. Adding Kenya = new tax module, not core rewrite
4. **Mobile money as first-class:** Auto-reconciliation, not an add-on integration
5. **Community & network effects:** Third-party modules, local language support, partner ecosystem

---

## 6. Traction & Milestones

### What's Built (100% Technical, 0% Go-to-Market)

| Milestone | Date | Status |
|-----------|------|--------|
| Backend architecture (modular monolith) | Aug 2026 | ✅ Complete |
| Auth + RBAC + multi-tenancy | Aug 2026 | ✅ Complete |
| Product catalog + inventory + pricing | Aug 2026 | ✅ Complete |
| Sales POS (online + offline) | Aug 2026 | ✅ Complete |
| Tax engine (Tanzania dual VAT) | Aug 2026 | ✅ Complete |
| Accounting (chart of accounts, journal entries) | Aug 2026 | ✅ Complete |
| Reporting (tax, sales, top products) | Aug 2026 | ✅ Complete |
| Offline-first sync (72h window) | Aug 2026 | ✅ Complete |
| Flutter mobile + desktop + web client | Aug 2026 | ✅ Complete |
| 858+ tests (unit + integration) | Sep 2026 | ✅ Passing |

### What's Next (Series A funded)

| Milestone | Timeline | Investment |
|-----------|----------|------------|
| Credit system + customer balances | Month 1–2 | $80K |
| Cash accountability + money accounts | Month 2–3 | $80K |
| Owner mode (5-question dashboard) | Month 3–4 | $60K |
| Kenya tax module (KRA e-invoicing) | Month 4–6 | $100K |
| Go-to-market: Dar es Salaam pilot | Month 3–6 | $150K |
| Mobile money integration (Daraja API) | Month 4–6 | $80K |
| Plugin system v1 | Month 6–9 | $120K |
| Scale: 1,000 paying customers | Month 6–18 | $330K |

---

## 7. Go-to-Market Strategy

### Phase 1: Dar es Salaam Pilot (Months 1–6)

**Target:** 100 retail/wholesale shops in Dar es Salaam

| Channel | Strategy | Budget |
|---------|----------|--------|
| **Direct sales** | 2 field reps visiting shops daily | $3,000/mo |
| **Trade associations** | Partner with Dar es Salaam traders' association | $1,000 |
| **M-Pesa agent network** | Co-marketing with M-Pesa agents (200K+ agents) | $2,000 |
| **Instagram/TikTok** | Swahili demo videos, shop owner testimonials | $1,500/mo |
| **Referral program** | 1 month free for each referral | $500/mo |

**Pilot KPIs:**
- 100 shops onboarded
- 80%+ retention after 3 months
- NPS > 50
- Average 15 sales/day per shop on the platform

### Phase 2: Tanzania National (Months 6–12)

- Expand to Arusha, Mwanza, Mbeya, Zanzibar
- Partner with banks (CRDB, NMB) for SME lending + Jolinx data
- TRA compliance certification → mandatory e-receipt positioning
- Target: 500 paying businesses

### Phase 3: Kenya + Uganda (Months 12–18)

- Kenya: KRA e-invoicing integration, M-Pesa Daraja API
- Uganda: URSB compliance, Mobile Money integration
- Partner with Safaricom (Kenya), MTN (Uganda)
- Target: 1,000 paying businesses across 3 countries

### Customer Acquisition Channels

```
┌──────────────────────────────────────────┐
│         Customer Acquisition              │
├──────────────────────────────────────────┤
│ 1. Direct Sales (field reps)      40%    │
│ 2. Partnerships (banks, telcos)   25%    │
│ 3. Referrals (existing customers) 20%    │
│ 4. Digital Marketing (social)     15%    │
└──────────────────────────────────────────┘
```

---

## 8. Financial Projections

### Revenue Forecast (3-Year)

| | Year 1 | Year 2 | Year 3 |
|---|--------|--------|--------|
| **Paying businesses** | 1,000 | 4,000 | 10,000 |
| **ARPA (annual)** | $360 | $420 | $480 |
| **SaaS Revenue** | $360K | $1.68M | $4.8M |
| **Transaction Fees** | $50K | $300K | $1.2M |
| **Plugin Marketplace** | $0 | $50K | $300K |
| **Enterprise** | $0 | $100K | $500K |
| **Total Revenue** | **$410K** | **$2.13M** | **$6.8M** |

### Cost Structure (Year 1)

| Category | Amount | % of Revenue |
|----------|--------|-------------|
| Engineering (2 devs) | $120K | 29% |
| Cloud infrastructure | $24K | 6% |
| Sales & marketing | $96K | 23% |
| Operations | $36K | 9% |
| **Total Costs** | **$276K** | **67%** |
| **Net Income** | **$134K** | **33%** |

### Key Metrics Trajectory

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| ARR | $410K | $2.13M | $6.8M |
| Gross Margin | 82% | 85% | 88% |
| Burn Rate | $23K/mo | Profitable | Profitable |
| Cash Runway | 18+ months | N/A | N/A |

---

## 9. Team

### Founder

**[Your Name]** — Founder & CTO

- Full-stack engineer: .NET backend + Flutter mobile/desktop
- Built the entire platform solo in 2 months (597 backend tests + 261 Flutter tests)
- Deep understanding of East African SME operations
- Technical decisions: modular monolith, event-driven architecture, CQRS, offline-first sync

### Hiring Plan (Post-Series A)

| Role | When | Cost |
|------|------|------|
| Sales Lead (Dar es Salaam) | Month 1 | $1,500/mo |
| Field Sales Rep × 2 | Month 2 | $800/mo each |
| Flutter Developer | Month 3 | $2,000/mo |
| Customer Success | Month 4 | $1,000/mo |
| Kenya Country Manager | Month 12 | $2,500/mo |

---

## 10. The Ask

### Series A: $500K–$2M

| Use of Funds | Amount | % |
|-------------|--------|---|
| **Product Development** | $250K | 30% |
| Credit, cash accountability, owner mode | | |
| Kenya/Uganda tax modules | | |
| Plugin system v1 | | |
| **Go-to-Market** | $300K | 36% |
| Sales team (Dar es Salaam) | | |
| Marketing & partnerships | | |
| M-Pesa/Daraja integration | | |
| **Infrastructure** | $80K | 10% |
| Cloud scaling, CDN, monitoring | | |
| **Operations** | $100K | 12% |
| Legal, accounting, office | | |
| **Reserve** | $70K | 8% |
| Buffer for opportunities | | |

### Milestone-Based Funding

| Milestone | Investment | Deliverable |
|-----------|------------|-------------|
| **M1:** Credit + Cash + Owner Mode | $250K | Product complete, ready for market |
| **M2:** 100 paying customers (Dar) | $250K | Product-market fit validated |
| **M3:** 500 paying customers (TZ) | $500K | National scale |
| **M4:** 1,000 paying customers (3 countries) | $500K–$1M | Regional expansion |

### Return Scenario

At 10,000 customers (Year 3):
- **Revenue:** $6.8M
- **Valuation (10x revenue):** $68M
- **Investor return (Series A at $10M pre-money):** 6.8x

---

## 11. Why Now? Why Us?

### Market Timing

1. **TRA e-receipt mandate:** 5M Tanzanian businesses must comply — Jolinx is the affordable option
2. **Kenya KRA digitization:** 500K+ businesses need compliant POS — we expand with tax module
3. **SME digitization funds:** Government subsidies for tech adoption create free distribution
4. **Mobile money maturity:** 70%+ penetration creates the data layer for financial services

### Why Us?

1. **Built by an African, for African businesses** — not a Western product translated
2. **Technical moat:** 858+ tests, production-grade architecture, offline-first by design
3. **Speed:** Entire platform built in 2 months by one engineer — imagine what a team can do
4. **Local knowledge:** Swahili-first, mobile money native, understands shop owner workflows

---

## 12. Appendix

### Technical Architecture (Summary)

```
┌─────────────────────────────────────────────────┐
│  Backend: .NET 10 + PostgreSQL + Redis           │
│  Architecture: Modular Monolith + CQRS + Events  │
│  Auth: JWT + refresh + RBAC + Audit              │
│  Offline: Drift (SQLite) + Idempotent Sync       │
├─────────────────────────────────────────────────┤
│  Client: Flutter (Android + iOS + Desktop + Web) │
│  State: Riverpod + go_router                     │
│  Offline: SQLCipher encrypted local DB           │
└─────────────────────────────────────────────────┘
```

### Test Coverage

| Layer | Tests | Status |
|-------|-------|--------|
| Backend Unit | 415 | ✅ All passing |
| Backend Integration | 182 | ✅ All passing |
| Flutter | 261 | ✅ All passing |
| **Total** | **858** | ✅ **All green** |

### Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Modular monolith (not microservices) | Solo dev, faster iteration, simpler ops |
| PostgreSQL (not MySQL) | JSONB, row-level security, ACID |
| Flutter (not React Native) | One codebase, offline-first, desktop support |
| Event-driven + outbox | Reliable delivery, module decoupling |
| Shared-DB multi-tenancy | Simple, cost-effective, escape hatch exists |
| CQRS (MediatR) | Clean separation, testability |

### Documentation

- Architecture: `docs/Architecture.md`
- Tech Stack: `docs/TechStack.md`
- Vision: `docs/Vision.md`
- Roadmap: `docs/roadmap.md`
- Business OS Vision: `docs/Jolinx-Vision.md`

---

**Contact:**

[Your Name]
[Your Email]
[Your Phone]
[Your Location]

---

*This document is confidential and intended solely for the use of prospective investors. All financial projections are forward-looking estimates and not guarantees of future performance.*
