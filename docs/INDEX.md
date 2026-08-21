# Document Index — KU Smart Attendance Onboarding App

Single source of truth for every document in this project. Keep this table current whenever a document is added, changed, or deprecated.

Last updated: 21 August 2026

---

## Document Tracker

| ID | Document | Path | Type | Owner | Status |
|---|---|---|---|---|---|
| D-001 | Master Development Plan | [`/docs.md`](../docs.md) | Plan | Lead Dev | ✅ Current |
| D-002 | Document Index *(this file)* | [`docs/INDEX.md`](INDEX.md) | Tracking | Lead Dev | ✅ Current |
| D-003 | Build & Run Manual | [`docs/MANUAL.md`](MANUAL.md) | Manual | Dev/QA | ✅ Current |
| D-004 | Architecture Notes | [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Design | Lead Dev | ✅ Current |
| D-005 | Backend / Recognition Pipeline | [`docs/BACKEND.md`](BACKEND.md) | Design | Backend Dev | ✅ Current |
| D-006 | Privacy & Compliance | [`docs/PRIVACY.md`](PRIVACY.md) | Policy | Lead Dev + KU Legal | ⚠️ Needs review |
| D-007 | KU Branding Guide | [`docs/BRANDING.md`](BRANDING.md) | Brand | Lead Dev | ✅ Current |
| D-008 | API Contract | [`docs/API.md`](API.md) | Contract | Backend Dev | ⚠️ Needs review |
| D-009 | UX / Wireframes | [`docs/UX.md`](UX.md) | Design | Product | ✅ Current |
| D-010 | Test Plan | [`docs/TESTING.md`](TESTING.md) | QA | QA | ✅ Current |
| D-011 | Supabase Backend Plan | [`docs/SUPABASE.md`](SUPABASE.md) | Design/Plan | Lead Dev | 🕓 In implementation |

Legend: ✅ Current · 🕓 Planned · ⚠️ Needs review · 🗄️ Archived

---

## Asset Registry

| Asset | Location | Notes |
|---|---|---|
| KU Blue color set | `ku-onboarding/Assets.xcassets/Colors/KU Blue.colorset` | `#1C4F9D` |
| KU Blue Deep | `.../Colors/KU Blue Deep.colorset` | `#123B8A` gradients |
| KU Blue Soft | `.../Colors/KU Blue Soft.colorset` | `#EBF6FC` surfaces |
| KU White | `.../Colors/KU White.colorset` | `#FFFFFF` |
| KU Text | `.../Colors/KU Text.colorset` | `#1D1D23` |
| Official KU logo (dark) | `Assets.xcassets/KULogo.imageset` | 1x/2x/3x official logo |
| KU logo white knock-out | `Assets.xcassets/KULogoWhite.imageset` | for brand-blue surfaces |
| App icon | `Assets.xcassets/AppIcon.appiconset` | 1024×1024 KU-blue + wordmark |
| Theme code | `ku-onboarding/KUTheme.swift` | colors, fonts, gradients |

---

## Process

1. **Before writing a doc**: create a row here with a new `D-###` ID and status `🕓 Planned`.
2. **When a doc lands**: flip status to `✅ Current` and update "Last updated".
3. **Deprecating a doc**: set status `🗄️ Archived`, add reason in Git history.
4. Manual (D-003) must be updated for every change to build/run/test steps.