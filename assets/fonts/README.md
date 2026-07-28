# Bundled fonts

The `.ttf` files are committed, so a fresh clone builds without extra steps.
To regenerate them from upstream:

```bash
./tool/fetch_fonts.sh
```

## Provenance

The committed files were produced from the `@fontsource/*` v4 npm packages
(`<family>-all-<weight>-normal.woff`), losslessly rewrapped from WOFF to TTF
with `fontTools`. The `-all-` variants are the unsubsetted fonts, which matters
here: the per-language subsets omit `ğ Ğ ş Ş İ`, so Turkish UI strings would
have rendered with fallback glyphs. Every character used in `lib/` was verified
present in Anton, Barlow Condensed and Nunito.

`Outfit-Black.ttf` covers only ASCII, which is fine — it draws the single
letter `S` behind the money symbol in `MoneySymbolPainter` and nothing else.

## Why they are bundled

The app previously used the `google_fonts` package, which downloads font files
from the network on first run. On a fresh install the download had not finished
yet, so Flutter fell back to the platform default font and heavy weights
(`w800` / `w900`) rendered noticeably thinner — then "snapped" back to bold once
the download landed and was cached. Shipping the files inside the app removes
the network dependency: correct weights on the first frame, offline.

## Expected files

| File | Family | Weight |
| --- | --- | --- |
| `Anton-Regular.ttf` | Anton | 400 |
| `BarlowCondensed-Medium.ttf` | BarlowCondensed | 500 |
| `BarlowCondensed-SemiBold.ttf` | BarlowCondensed | 600 |
| `BarlowCondensed-Bold.ttf` | BarlowCondensed | 700 |
| `BarlowCondensed-ExtraBold.ttf` | BarlowCondensed | 800 |
| `BarlowCondensed-Black.ttf` | BarlowCondensed | 900 |
| `Nunito-SemiBold.ttf` | Nunito | 600 |
| `Nunito-ExtraBold.ttf` | Nunito | 800 |
| `Outfit-Black.ttf` | Outfit | 900 |

All are SIL Open Font License 1.1.
