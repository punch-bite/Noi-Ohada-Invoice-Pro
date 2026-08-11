---
name: L'Éclat de l'OHADA
colors:
  surface: '#fcf8ff'
  surface-dim: '#dcd8e4'
  surface-bright: '#fcf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f2fe'
  surface-container: '#f0ecf8'
  surface-container-high: '#eae6f3'
  surface-container-highest: '#e4e1ed'
  on-surface: '#1b1b23'
  on-surface-variant: '#464554'
  inverse-surface: '#302f39'
  inverse-on-surface: '#f3effb'
  outline: '#777586'
  outline-variant: '#c7c4d7'
  surface-tint: '#5148d7'
  primary: '#2a14b4'
  on-primary: '#ffffff'
  primary-container: '#4338ca'
  on-primary-container: '#c1beff'
  inverse-primary: '#c3c0ff'
  secondary: '#712ae2'
  on-secondary: '#ffffff'
  secondary-container: '#8a4cfc'
  on-secondary-container: '#fffbff'
  tertiary: '#692400'
  on-tertiary: '#ffffff'
  tertiary-container: '#8f3400'
  on-tertiary-container: '#ffb393'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e3dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#100069'
  on-primary-fixed-variant: '#372abf'
  secondary-fixed: '#eaddff'
  secondary-fixed-dim: '#d2bbff'
  on-secondary-fixed: '#25005a'
  on-secondary-fixed-variant: '#5a00c6'
  tertiary-fixed: '#ffdbcd'
  tertiary-fixed-dim: '#ffb597'
  on-tertiary-fixed: '#360f00'
  on-tertiary-fixed-variant: '#7d2d00'
  background: '#fcf8ff'
  on-background: '#1b1b23'
  surface-variant: '#e4e1ed'
typography:
  headline-xl:
    fontFamily: Roboto Flex
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Roboto Flex
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Roboto Flex
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  title-md:
    fontFamily: Roboto Flex
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Roboto Flex
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Roboto Flex
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Roboto Flex
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 24px
  gutter: 16px
  card-gap: 20px
---

## Brand & Style
This design system balances the rigorous structural requirements of OHADA accounting standards with a forward-thinking, high-end SaaS aesthetic. The personality is authoritative yet approachable, positioning the software as a premier financial tool for the modern African enterprise.

The visual style is **Modern Premium Glassmorphism** with a strong **Material 3** structural foundation. It utilizes translucent surfaces, soft background blurs, and vibrant atmospheric lighting to create a sense of depth and lightness. The interface avoids the heavy, spreadsheet-driven fatigue of traditional accounting software, instead offering a "luminous" workspace that feels both technologically advanced and physically tangible.

## Colors
The palette is built on a "Luminous Indigo" foundation. The primary colors transition from Indigo to Violet, creating dynamic gradients that signify action and vitality. 

- **Primary & Secondary:** Used for high-emphasis actions and brand elements. In Dark Mode, these shift to higher-vibrancy variants (#7C6CF0 and #9A7BFF) to maintain accessible contrast against deep surfaces.
- **Accent (Gold):** Specifically reserved for "Premium" features, subscription prompts, and critical financial highlights.
- **Backgrounds:** The "GlassScaffold" uses a diagonal gradient transition from `#EDE9FE` to `#FDF2F8`. Implement radial halos in the background: Indigo at the top-right and Pink/Violet at the bottom-left to provide depth behind the translucent glass layers.

## Typography
The system uses **Roboto Flex** for its exceptional readability in data-heavy environments and its ability to scale weight precisely.

- **Headlines:** Use heavy weights (700-800) for "Montant Total" and "Numéro de Facture" to ensure clear information hierarchy.
- **Body:** Standard weights (400) for descriptive text and OHADA compliance notes.
- **Labels:** Semi-bold (600) with slight letter spacing for table headers and metadata categories.
- **Language:** All typography must support French character sets (accents, cedillas).

## Layout & Spacing
This system follows a **12-column fluid grid** for desktop and a **single-column stack** for mobile. 

- **Margins:** Use a base 8pt grid system. Page margins are set to 24px on desktop and 16px on mobile.
- **Rhythm:** Vertical spacing between cards and sections should be generous (20px to 32px) to allow the background gradients to breathe through the translucent layers.
- **Compliance Layout:** Financial tables must remain horizontal even on smaller tablets; use "overflow-x: auto" for invoice line items to maintain the OHADA-required table structure.

## Elevation & Depth
Depth is achieved through **Backdrop Filtering** and **Tonal Layering** rather than traditional heavy shadows.

- **Glass Effect:** Apply a `backdrop-filter: blur(12px)` to all card surfaces.
- **Edge Highlighting:** Instead of a full border, use a top-weighted border gradient (white at 0.6 opacity) to simulate light hitting the top edge of the glass.
- **Shadows:** Use extremely diffused, low-opacity shadows (e.g., `0 8px 32px rgba(0,0,0,0.05)`) to lift cards off the gradient background without muddying the colors.

## Shapes
The shape language is sophisticated and approachable. 

- **Cards:** Standardized at a 20px corner radius to emphasize the "soft glass" aesthetic.
- **Buttons & Inputs:** Use a 14px radius (Large) to create a distinct interactive language that feels modern and premium.
- **Status Indicators:** Use smaller 8px radii for badges to distinguish them from larger interactive elements.

## Components

- **GradientButton:** Primary actions (e.g., "Émettre la facture"). Full width, 14px rounded, with a linear gradient from Indigo (#4338CA) to Violet (#7C3AED). On hover, increase the vibrance or add a subtle glow.
- **GlassCard:** The primary container. Must have a 0.6 opacity white border and a 20px radius. Ensure the backdrop blur is sufficient to keep text legible over the background halos.
- **Status Badges:** Use a "tinted glass" approach. Success (Green) should be a 15% opacity green background with 100% opacity text.
- **Premium Badge:** Dedicated "Or" style. Background: `#E9B949` at 0.18 opacity. Text: `#B48A1B` (Dark Gold) accompanied by a 12px Star icon.
- **Input Fields:** Semi-transparent white backgrounds (0.4 opacity) with a 1px solid border that darkens on focus. Use "Floating Labels" (Material 3) to keep forms compact.
- **OHADA Table:** A clean, glass-based table for billing items. Alternate row colors using 5% opacity indigo to guide the eye without breaking the glass effect.