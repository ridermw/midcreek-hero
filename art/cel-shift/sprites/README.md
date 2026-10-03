# Cel Shift pixel sprites

Four pixel-art variants based on the RPG pose reference, with Cel Shift
character identities and workwear. `midcreek-concept` remains read-only.

![Comparison preview](preview.png)

The checkerboard above belongs only to the comparison preview. The actual
sprite sheets and individual PNGs have real transparency.

| Character | Normal: real maintenance tools | Hybrid: industrial fantasy |
|---|---|---|
| Man | [Sheet](sheets/man-midcreek.png) | [Sheet](sheets/man-hybrid.png) |
| Woman | [Sheet](sheets/woman-midcreek.png) | [Sheet](sheets/woman-hybrid.png) |

Normal poses are ready, working reach, multimeter testing, braced reaction,
running, and signaling. No blades, shields, spell effects, or attack trails.
Hybrid poses retain the reference's slash, effect gesture, block and triumph.
The hybrid source artwork was retained when the normal variants were revised.

## Exports

- Four RGBA sheets: 1248x208, six 208x208 cells per sheet.
- [24 individual PNGs](individual/), with a shared pivot at (104, 184).
- Binary alpha (0 or 255); a shared palette of at most 96 opaque colors.
- [Manifest](manifest.json) records frames, pivots, source hashes and palette.
- Nearest-neighbor sampling; six distinct action poses, not continuous animation.
- Concepts only: no engine integration or animation-cycle validation claimed.

`generated/` preserves the 1536x512 MockUI source renders and sanitized metadata.
Those raw images contain soft partial-alpha halos; use `sheets/` or
`individual/`, not the raw generation output, for sprites.

Rebuild with Pillow installed:

```sh
python art/cel-shift/sprites/prepare.py
```

The exporter separates connected components without slicing overlapping
effects, thresholds alpha at 128, samples at half resolution using nearest
neighbor, maps to a shared palette without dithering, and packs fixed cells.

## Provenance

Generated with MockUI, Sunburst, high quality, strict prompt screening and
native transparent-background output. Prompts are in `prompts/`.
The pose/style reference is the OpenAI gallery image at
`https://developers.openai.com/images/image-gallery-sunburst/sprites.webp`;
its top row was cropped to `(0, 0, 1536, 334)` for reference only.
Character identity references came from `midcreek-concept`:
`themes/cel-shift/masters/character-{man,woman}/01-sheet.png`, cropped to
`(24, 20, 226, 353)`. Those source images are not redistributed here.
The female hybrid also used the male hybrid with alpha thresholded at 128
as a style reference. Normal variants were edited from their hybrid counterpart.
Metadata preserves input hashes and generation prompts; local account names
and absolute filesystem paths are removed for public distribution.
No third-party license grant is implied for the external reference images.
