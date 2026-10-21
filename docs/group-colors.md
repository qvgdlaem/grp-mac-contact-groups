# Numbered group color library

The library is `Sources/GRP/GroupColorLibrary.swift`, in
`GroupColorLibrary.colors`. The eight base swatches are from Masataka Okabe and
Kei Ito's [Color Universal Design palette](https://jfly.uni-koeln.de/color/index.html).
The numbering below is this app's stable public numbering.

| Color number | Name | Original swatch |
| --- | --- | --- |
| 1 | Blue | `#0072B2` |
| 2 | Orange | `#E69F00` |
| 3 | Bluish green | `#009E73` |
| 4 | Reddish purple | `#CC79A7` |
| 5 | Sky blue | `#56B4E9` |
| 6 | Vermilion | `#D55E00` |
| 7 | Yellow | `#F0E442` |
| 8 | Black / neutral | `#000000` |

The exact swatch stays in the library. Small text uses a shade/tint adjusted for
at least 4.5:1 contrast against the actual neutral surface in light/dark appearance;
raw yellow and sky blue are too pale for small text on white. This is a contrast
adaptation of the palette, not a claim that every possible color pair is equally
distinguishable. See [WCAG text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
Names remain visible and a hover/accessibility description identifies the family,
color number and color name. Color is an additional cue, never the only identifier.

## Family rule

Trim leading whitespace and take the first whitespace-separated word. Normalize
Unicode representation and ignore case when comparing family keys. Punctuation
inside the first word remains meaningful; `Foo-Dog` is one word.

| Apple Contacts group | Theoretical family |
| --- | --- |
| Foo | Foo |
| Foo Dog | Foo |
| foo Cat | Foo |
| Bar | Bar |
| Baz Banjo | Baz |
| Baz Guitar | Baz |

Family membership is presentation metadata. It does not create/rename/reparent
native groups, change memberships, or combine cards across accounts. Same-family
groups share a color even across accounts, while card mutation remains account-specific.

## Allocation and persistence

For the initial complete group set, sort normalized family keys and assign each
the least-used available color (ties use the lowest color number). Save family→
number assignments in the app's local UserDefaults. Future groups in a known family
reuse its number. New families take the least-used color; existing assignments
remain unchanged. Filtering/searching/reordering doesn't influence assignments.
Colors are reused once there are more families than entries in the library.

Assignments and sort preference are local to each Mac, not uploaded to GitHub.
Both Macs start with the same mapping for an identical initial group set; differing
local history can produce different mappings. Cross-Mac preference syncing is not
implemented.

## Add another color

1. Append an entry with a new, unused ID (next is 9), a descriptive name and its
   base RGB hex value to `GroupColorLibrary.colors`.
2. Keep existing numbers unchanged. The allocator automatically considers the
   extra entry for new families. No distribution/UI code changes are needed.
3. Run `bash scripts/check.sh`; it verifies family rules, allocation stability,
   library extension and text contrast. Review color-vision distinguishability
   for any added swatches, as extending the palette does not by itself guarantee it.

Existing families retain their assignments after expansion. This preserves
recognition instead of unexpectedly recoloring all labels.
