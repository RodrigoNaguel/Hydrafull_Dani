# HydraFuel Watch Face - Codex Instructions

## SOURCE OF TRUTH

`reference.png` is the authoritative visual reference for this project.

The rendered Garmin watch face MUST match `reference.png` as closely as technically possible.

REFERENCE IMAGE WINS over the current implementation.

DO NOT redesign.
DO NOT reinterpret.
DO NOT "improve" the composition.
DO NOT invent another layout.

## CURRENT TARGET

For now, optimize and validate the visual layout specifically for:

GARMIN FORERUNNER 970

Do not attempt a broad multi-device redesign during this task.

Other devices will be handled later.

## FUNCTIONAL SAFETY

This task is VISUAL ONLY.

Unless explicitly requested, NEVER change:

- hydration calculations
- metric calculations
- heart rate logic
- calories logic
- temperature logic
- battery logic
- activity data
- settings
- storage
- background services
- notifications
- application lifecycle
- configurable widget behavior

Do not perform unrelated refactors.

## BEFORE EDITING

Before changing code:

1. Read this entire AGENTS.md.
2. Inspect `reference.png`.
3. Inspect all relevant source files.
4. Run `git status`.
5. Run `git diff`.
6. Identify existing layout regressions.
7. Only then edit the minimum necessary code.

Do not rewrite the whole application.

# DISPLAY

Always use the Garmin display dimensions:

```monkeyc
var w = dc.getWidth();
var h = dc.getHeight();
var cx = w / 2;
var cy = h / 2;

The large black region outside the watch in CIQ Simulator is NOT part of the display.

Never calculate layout from simulator window dimensions.

CIRCULAR SAFE AREA

The watch display is ROUND.

Important UI must remain comfortably inside the circular screen.

Nothing important should touch the bezel.

Do not treat the screen like a rectangular mobile UI.

REQUIRED VISUAL STRUCTURE

The layout must preserve exactly these regions:

LEFT
|
DIVIDER BANDS
|
CLOCK / TOP INFO
|
HYDRATION

with GOAL information at bottom-right.

LEFT - 3 CONFIGURABLE WIDGETS

Exactly THREE circular configurable widgets.

They must:

be on the left
have identical diameter
be vertically aligned
have equal vertical spacing
contain icon + value + unit
never overlap divider bands
never overlap the clock
never touch the bezel

Initial normalized anchors for Forerunner 970:

X ≈ 0.27 * width

Y1 ≈ 0.31 * height
Y2 ≈ 0.50 * height
Y3 ≈ 0.69 * height

Use the reference image to fine tune.

DIVIDER BANDS

The purple/pink vertical bands ARE INTENTIONAL.

DO NOT REMOVE THEM.

They are a design feature, not accidental separator lines.

They must look like reference.png:

grouped together
wide enough to look intentional
violet/purple/pink
located between left widgets and clock
subtle purple mist behind them
behind foreground information
never overlapping clock digits

Approximate region:

X ≈ 0.43 - 0.47 * width

DO NOT turn them into random 1px vertical lines.

CLOCK

The clock is the visual focal point.

It belongs CENTER-RIGHT, not in the center-left.

Structure:

12
54

Hour:

very large
solid pink/magenta

Minutes:

very large
outlined violet/light style

Hour and minute form ONE coherent visual block.

Do not position them independently with arbitrary coordinates.

Approximate horizontal region:

X ≈ 0.53 - 0.68 * width

The clock must visually resemble the reference image.

TOP INFO

Battery and date sit ABOVE the main clock.

Order:

Battery
Date
Clock

Battery and date are secondary information.

They must not become larger or more visually dominant than the clock.

RIGHT - HYDRATION

Hydration is permanently on the right.

Structure:

small blue water drop

500
ml

The blue drop is a SMALL icon.

It must NEVER become huge.

It must remain clearly separated from clock digits.

Approximate region:

X ≈ 0.78 * width

Use reference.png for final placement.

BOTTOM RIGHT - GOAL

Bottom-right contains:

goal percentage
curved progress arc

The percentage must remain readable.

The arc follows the lower-right circular edge of the display.

It must:

remain inside the bezel
not overlap other content
visually resemble reference.png
PURPLE MIST

The subtle purple mist behind the center divider is intentional.

It must remain SUBTLE.

It must:

stay behind foreground elements
not cover text
not create rectangular artifacts
not create random noise across the screen
COLORS

Preserve the design palette:

Background = black
Primary = pink/magenta
Secondary = violet/purple
Text = white
Hydration = blue

Do not introduce unrelated colors.

SCALING

CRITICAL:

DO NOT use one global scaleFactor blindly for the entire UI.

Do not multiply fonts, icons, offsets, strokes and spacing by one universal value.

Treat independently:

positions
font sizes
widget radius
icon sizes
divider widths
divider spacing
arc radius
stroke widths
mist dimensions

Use normalized anchors for positioning and tune each visual group independently.

DRAW ORDER

Preferred order:

black background
subtle purple mist
divider bands
decorative/progress arc
left widget circles
widget contents
battery/date
main clock
hydration
goal percentage

Background graphics must never cover foreground text.

REGRESSION RULE

When fixing one visual component, do NOT modify unrelated components.

If hydration is wrong:
fix hydration.

Do not simultaneously redesign the clock, widgets and divider.

Make small deterministic changes.

DO NOT

Never:

redesign the watch face
center everything
compress everything into the left side
enlarge hydration arbitrarily
remove divider bands
turn divider bands into thin random lines
overlap divider with clock
overlap hydration with clock
move clock far left
touch the bezel with important content
perform broad refactors during layout work
modify business logic during visual work
claim success based only on compilation
BUILD

After visual modifications:

build the Connect IQ project
fix all compilation errors
test with Forerunner 970 when possible
inspect the resulting render
compare it to reference.png

Compilation success alone does NOT mean the task is complete.

ACCEPTANCE CRITERIA

The task is complete ONLY when:

exactly 3 circular widgets appear on the left
widgets have equal size
widgets have equal vertical spacing
divider bands appear between widgets and clock
divider bands resemble reference.png
bands do not overlap clock digits
purple mist remains subtle
battery is above date
battery/date are above clock
clock is center-right
hour is large and pink
minutes are large and outlined
clock is the focal point
hydration is on the right
hydration drop is small and blue
hydration value and ml are readable
goal percentage is bottom-right
progress arc follows the lower-right edge
important content stays inside the circular safe area
no accidental lines appear
no elements are compressed into one side
overall composition clearly resembles reference.png

If the rendered output does not clearly resemble reference.png:

THE TASK IS NOT COMPLETE.




