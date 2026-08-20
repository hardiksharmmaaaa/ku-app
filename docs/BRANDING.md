# KU Branding Guide — Smart Attendance Onboarding App

Manual: **D-007** · Last updated: 20 August 2026

Khalifa University's smart-attendance app implements the **blue + white** brand theme using the **official KU logo** and brand palette.

---

## 1. Official Sources

- Official logo archive: `https://www.ku.ac.ae/media/visual-identity-and-branding-guidelines`
  (Download "Official Logos" → `KU_Logo-1-1.zip`)
- Brand guidelines: `KU_Guidelines_2020_V7.pdf` (same page)
- Contact: KU **Communications and Business Development** for approved exports and co-branding rules.

> ⚠️ The logo currently shipped is the official university export. Before any public release, confirm with KU Comms that the file/context is approved for an iOS application.

---

## 2. Color Palette

Colors were **sampled from the official KU logo asset** to guarantee accuracy.

| Role | Name | Hex | Usage |
|---|---|---|---|
| Primary brand blue | KU Blue | `#1C4F9D` | CTAs, brand elements, app icon background |
| Deep navy | KU Blue Deep | `#123B8A` | Gradients (`heroGradient`), focus rings |
| Ice-blue tint | KU Blue Soft | `#EBF6FC` | Light screen backgrounds |
| White | KU White | `#FFFFFF` | Surfaces, text on brand blue |
| Body text | KU Text | `#1D1D23` | Readable text on light surfaces |

**Rules**
- Blue is the dominant brand color; white carries content.
- Text on KU Blue uses white (or the white logo).
- Text on white/soft surfaces uses KU Text, never pure black.
- No accent colors (gold/sand) yet — keeping a strict blue+white theme per project decision. Revisit with brand guidance if needed.

---

## 3. Logo Assets

| Asset | File | When to use |
|---|---|---|
| `KULogo` | `Assets.xcassets/KULogo.imageset` | Official blue/black logo on white/light surfaces |
| `KULogoWhite` | `Assets.xcassets/KULogoWhite.imageset` | White knock-out on brand-blue surfaces (splash, dark headers) |

**Rules**
- Never stretch or recolor the logo.
- Keep generous clear space (≈ height of the wordmark) around it.
- Minimum width ≈ 120 pt on-screen.
- Do not place on busy imagery.

> ⚠️ **Verification pending**: the current `KULogoWhite` is a white knock-out **derived** from the official logo. Have KU Comms confirm the white variant is approved before shipping to store.

---

## 4. App Icon

- 1024×1024, generated from official logo: **KU Blue tile + white official wordmark**.
- Sits in `AppIcon.appiconset`.
- Single-icon set reused for all iOS icon slots (1x/2x/3x auto-scales).

---

## 5. Typography

Type uses the system **rounded** design (`SF Pro Rounded` classes) via `KUTheme`:

| Style | Font | Use |
|---|---|---|
| displayFont | `largeTitle` bold rounded | Success screen headline |
| titleFont | `title2` semibold rounded | Screen titles, KU wordmark |
| bodyFont | `body` rounded | Body, buttons |
| captionFont | `caption` rounded | Helper/legal caption text |

> Optional: if KU specifies a licensed brand font (e.g., custom family), replace the system choices in `KUTheme.swift` and bundle the font files.

---

## 6. Localization

- English first (`developmentRegion = en`, string catalogs enabled).
- Arabic planned: `Localizable.strings` + `.environment(\.layoutDirection, .rightToLeft)`.
- Keep all user-facing strings out of view code; route through localized strings from day one so RTL bakes in cleanly.

---

## 7. Do / Don't

| ✅ Do | ❌ Don't |
|---|---|
| Use official logo files | Re-type or redraw "Khalifa University" |
| Use KU Blue `#1C4F9D` as primary | Add gold/sand/other accent colors without approval |
| White text/logo on brand blue | Place logo on low-contrast backgrounds |
| Keep clear space around logo | Stretch, rotate, or shadow the logo |
| Use rounded system typography | Use decorative third-party fonts |
| Run RTL checks after Arabic lands | Ship biometric text without consent copy |

---

## 8. Asset Fast-Reference

| Asset | Location |
|---|---|
| KU Blue `.colorset` | `Assets.xcassets/Colors/KU Blue.colorset` |
| KU Blue Deep `.colorset` | `Assets.xcassets/Colors/KU Blue Deep.colorset` |
| KU Blue Soft `.colorset` | `Assets.xcassets/Colors/KU Blue Soft.colorset` |
| KU White / KU Text `.colorset` | `Assets.xcassets/Colors/` |
| Official logo (dark) | `Assets.xcassets/KULogo.imageset` |
| White logo | `Assets.xcassets/KULogoWhite.imageset` |
| App icon | `Assets.xcassets/AppIcon.appiconset` |
| Theme code | `ku-onboarding/KUTheme.swift` |