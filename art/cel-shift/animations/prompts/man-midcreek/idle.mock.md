---
name: man-midcreek-idle-animation
size: 1536x1024
quality: high
---

Edit image 1 into a TRUE PIXEL ART animated sprite sheet for the SAME character.
Image 1 is the approved character IDENTITY, pixel-art STYLE and PALETTE reference.
Replace its single pose with a complete 6-frame IDLE animation.
Keep the same face, hair, hard hat, clothing, compact adult RPG proportions,
dark stepped pixel contours, small square color clusters and shaded material ramps.
Never switch to smooth cel illustration, vector art, a 3D render or painted concept art.

MAN: clean-shaven, short dark hair below blue hard hat; long slate sleeves to wrists, roomy straight blue jeans. No beard or moustache.
Both: blue hard hat/ear defenders, lime hi-vis vest, orange trim, broad silver
bands, slate shirt, blue denim, brown boots and tool belt. Outfit and character
size must remain IDENTICAL across frames.
NORMAL REAL-WORLD technician: ordinary hand tools only. NO sword, shield, rack panel, magic, spell, glowing trail or combat armor.

EXACT GRID: 3 columns by 2 rows, read left-to-right then top-to-bottom.
Exactly 6 figures, one per equal 512x512 cell. No drawn grid, numbers or labels.
Each cell uses local coordinates: body centered near x=256, BOOT CONTACT BASELINE
y=448, standing figure including hat approximately 270 pixels tall. All painted
pixels, including effects/tools/hair, must remain inside x=64..448 and y=96..480.
Character anatomy is drawn at the SAME scale in every frame; don't resize each pose
to fill the cell. Foot position may change through stride but the floor is fixed.
Camera/facing stays consistent. Right-facing profile for locomotion; do not
alternate front and back views or rotate the character through the cycle.

FRAME BREAKDOWN:
Small breathing loop, hands relaxed or resting near tool belt. Six phases: neutral, inhale begins, chest rises, inhale peak, exhale, near-neutral returning seamlessly to first. Keep planted feet absolutely stationary.

Draw every individual phase as distinct authored pixel artwork. In-between frames
must actually move the knees, ankles, elbows and hands through the action; do not
copy the same standing pose across the sheet. Keep body volume and costume stable.
No motion blur; changing limb silhouettes must carry the motion.

Use actual TRANSPARENT RGBA output. Alpha zero around every figure and in limb
gaps. Do not draw a checkerboard, white/beige backdrop, ground shadow, scenery,
captions, logos, watermark, duplicate extras or opaque frame cards.
