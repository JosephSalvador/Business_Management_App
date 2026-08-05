# Vision

> The African alternative to Odoo, Zoho, SAP Business One, and Microsoft Dynamics 365.

## Problem

Small and medium businesses in East Africa (and beyond) run on spreadsheets, paper, and
memory. Off-the-shelf ERPs are either too expensive, too complex, need constant internet,
assume a single-currency/single-tax world, or ignore how these businesses actually operate.

## Product

**Business OS** — a *platform*, not a single ERP. A set of platform capabilities
(auth, tenants, RBAC, audit, events, workflows, reporting, sync, plugins, APIs) that every
future business module reuses. Industry modules (retail, agriculture, hospital, school,
hotel, logistics…) are thin skins over those capabilities.

## What we compete on

| Capability | Incumbents | Business OS |
|---|---|---|
| Offline-first POS | Weak | Core design |
| Mobile money (M-Pesa, Airtel, Tigo, Mixx) | Add-on | First-class via Payment Engine |
| Local tax (TRA, KRA, …) | Generic | Versioned country Tax Engine |
| Swahili + local languages | Partial | First-class |
| Low bandwidth | Poor | Optimized |
| SME pricing | High | Affordable, per-branch |
| Onboarding | Complex | Guided, < 10 min |
| Ecosystem / plugins | Yes (mature) | Plugin system by design from day one |

## Strategy posture

1. **Build the platform first.** Tenants, RBAC, audit, events, workflows, sync, and
   plugins are the moat. Every module that follows is cheap once these exist.
2. **Modular monolith first.** One deployment, vertical-slice modules. Split into
   services only when a module's team/speed/scale demands it.
3. **API-first.** Every feature ships a REST endpoint before a screen. Flutter is a
   client of the API, never the owner of business logic.
4. **Offline-first.** Local-first on the device, reliable idempotent sync, server wins
   on conflict (first version).
5. **Event-driven by default.** Modules never call each other; they raise domain events
   that other modules listen to, persisted through an outbox.
6. **Everything configurable.** Tax rules, numbering, currencies, units, custom fields.
   No hardcoded business rules.

## Success criteria (5-year horizon)

- A retailer, wholesaler, school, clinic, or hotel can run their entire operation on the
  platform without internet at point-of-sale.
- Third-party developers can ship an industry module (Hospital, Hotel, Agriculture) and
  have it appear in the sidebar with inherited permissions, notifications, and reports.
- A new country is supported by adding tax rules and payment adapters — no core code changes.
