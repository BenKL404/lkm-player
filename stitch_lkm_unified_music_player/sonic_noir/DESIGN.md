---
name: Sonic Noir
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#bcc9c7'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#869391'
  outline-variant: '#3d4948'
  surface-tint: '#5dd9d0'
  primary: '#6ee9e0'
  on-primary: '#003734'
  primary-container: '#4ecdc4'
  on-primary-container: '#00544f'
  inverse-primary: '#006a65'
  secondary: '#ffb3b0'
  on-secondary: '#68000f'
  secondary-container: '#901822'
  on-secondary-container: '#ff9e9b'
  tertiary: '#eed65f'
  on-tertiary: '#393000'
  tertiary-container: '#d1ba46'
  on-tertiary-container: '#564a00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#7cf6ec'
  primary-fixed-dim: '#5dd9d0'
  on-primary-fixed: '#00201e'
  on-primary-fixed-variant: '#00504c'
  secondary-fixed: '#ffdad8'
  secondary-fixed-dim: '#ffb3b0'
  on-secondary-fixed: '#410006'
  on-secondary-fixed-variant: '#8c1520'
  tertiary-fixed: '#fbe36a'
  tertiary-fixed-dim: '#dec651'
  on-tertiary-fixed: '#211b00'
  on-tertiary-fixed-variant: '#524600'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  display-lg:
    fontFamily: Lexend
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Lexend
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Lexend
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Lexend
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: Lexend
    fontSize: 12px
    fontWeight: '400'
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
  container-padding: 20px
  stack-gap-lg: 24px
  stack-gap-md: 16px
  stack-gap-sm: 8px
  album-art-size: calc(100vw - 40px)
---

## Brand & Style
The design system is engineered for a premium, high-fidelity mobile audio experience. The brand personality is "Sophisticated Precision"—merging the technical clarity of high-end audio equipment with a modern, immersive digital interface. It targets audiophiles and power users who value deep focus and aesthetic minimalism.

The visual style is a hybrid of **Modern Minimalism** and **Tactile Glassmorphism**. By utilizing a "True Black" foundation, the UI eliminates visual noise, allowing album artistry and vibrant accent colors to command attention. The emotional response is one of calm, rhythmic flow and executive quality.

## Colors
The palette is anchored by a deep `#0A0A0A` neutral, ensuring maximum contrast and battery efficiency on OLED displays. 

- **Primary Teal (#4ECDC4):** Reserved for core playback actions and active states.
- **Variant Accents:** Red, Yellow, Purple, and Orange are used for dynamic categorization (e.g., genre coding or mood-based playlists).
- **Surface Strategy:** Use `#141414` for card backgrounds and elevated containers to provide subtle separation from the true black backdrop without losing the immersive feel.
- **Gradients:** Use 40% opacity linear gradients derived from the primary or secondary colors behind album art to create "auras" of light.

## Typography
This design system utilizes **Lexend** exclusively to leverage its exceptional readability and athletic, modern geometric structure. 

- **Hierarchy:** Use Bold (700) or SemiBold (600) for track titles and navigation headers. Use Regular (400) at 60% opacity for metadata like artist names or album years to maintain a clear information hierarchy.
- **Accessibility:** Label styles use increased letter spacing and uppercase transformations to ensure legibility at small sizes during active movement.

## Layout & Spacing
The layout follows a **Fluid Mobile Grid** with a strict 20px outer margin. 

- **Vertical Rhythm:** A 4px baseline grid governs all spacing. Use 24px gaps between major sections (e.g., "Recently Played" vs "Your Playlists") and 8px gaps for internal element spacing.
- **Immersive Art:** Album covers in the "Now Playing" view should span the full width of the safe area (minus margins) to create a high-impact focal point.
- **Safe Zones:** Ensure all interactive elements (Play/Pause/Skip) are contained within the bottom 40% of the screen for optimal one-handed ergonomic reach.

## Elevation & Depth
Depth is communicated through **Tonal Layering** and **Subtle Blurs** rather than traditional drop shadows.

- **The Z-Axis:** Level 0 is the true black background. Level 1 consists of `#141414` cards. Level 2 (modals/sheets) uses a semi-transparent glass effect (20% white overlay with 20px backdrop blur).
- **Focus States:** Active elements like the currently playing track in a list should use a subtle teal glow (blur: 15px, opacity: 0.1) instead of a border.
- **Overlays:** Use a 60% black-to-transparent vertical gradient at the bottom of the screen to ensure the playback controls remain legible over scrolling content.

## Shapes
The shape language is characterized by **Generous Radii**. 

- **Cards:** All album art and container cards must use a 20px (`rounded-lg` in this system's scale) corner radius to soften the high-contrast aesthetic.
- **Interactive Elements:** Buttons and input fields should utilize the same 20px radius to maintain consistency.
- **Iconography:** Use a 2px stroke weight for outline icons. Icons must have slightly rounded terminals to match the font's geometry.

## Components
- **Primary Play Button:** A large, circular floating action button (FAB) in Teal (#4ECDC4) with a solid white or near-black play icon.
- **Playback Controls:** Use high-contrast white for iconography. The progress bar should be a 4px thick track (Background: #2A2A2A, Active: #4ECDC4).
- **Track Lists:** Clean rows with 16px vertical padding. Use a "Solid Play" icon for streaming tracks and an "Outline Download" icon for local files to differentiate source at a glance.
- **Dynamic Chips:** Small, 12px-radius pills for genres (e.g., "Techno", "Jazz") using the secondary accent colors with 15% background opacity and 100% text opacity.
- **Album Cards:** Feature a subtle 1px inner border (opacity 10%) to define the edges of dark album art against the black background.