#!/usr/bin/env bash
#
# Downloads the bundled font files declared in pubspec.yaml.
#
# The app used to pull these from the network at runtime via the `google_fonts`
# package, which made heavy weights render with the thin platform fallback on a
# fresh install until the download finished. The fonts are now shipped inside
# the app, so they have to exist on disk before `flutter build`.
#
# Run once after cloning:  ./tool/fetch_fonts.sh
# All fonts are SIL Open Font License 1.1.

set -euo pipefail

DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/fonts"
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"

mkdir -p "$DEST"

# Some families keep static instances in a `static/` subfolder, others at the
# family root. Try each candidate and keep the first that resolves.
fetch() {
  local out="$1"; shift
  if [[ -s "$DEST/$out" ]]; then
    echo "  = $out (already present)"
    return 0
  fi
  for url in "$@"; do
    if curl -fsSL "$url" -o "$DEST/$out" 2>/dev/null && [[ -s "$DEST/$out" ]]; then
      echo "  + $out"
      return 0
    fi
  done
  rm -f "$DEST/$out"
  echo "  ! FAILED: $out" >&2
  echo "    Download it manually from https://fonts.google.com and place it at" >&2
  echo "    $DEST/$out" >&2
  return 1
}

echo "Downloading fonts into $DEST"
failed=0

fetch "Anton-Regular.ttf" \
  "$BASE/anton/Anton-Regular.ttf" \
  "$BASE/anton/static/Anton-Regular.ttf" || failed=1

for w in Medium SemiBold Bold ExtraBold Black; do
  fetch "BarlowCondensed-$w.ttf" \
    "$BASE/barlowcondensed/BarlowCondensed-$w.ttf" \
    "$BASE/barlowcondensed/static/BarlowCondensed-$w.ttf" || failed=1
done

for w in SemiBold ExtraBold; do
  fetch "Nunito-$w.ttf" \
    "$BASE/nunito/static/Nunito-$w.ttf" \
    "$BASE/nunito/Nunito-$w.ttf" || failed=1
done

fetch "Outfit-Black.ttf" \
  "$BASE/outfit/static/Outfit-Black.ttf" \
  "$BASE/outfit/Outfit-Black.ttf" || failed=1

echo
if [[ $failed -eq 0 ]]; then
  echo "All fonts present:"
  ls -1 "$DEST"
  echo
  echo "Next: flutter pub get && flutter run"
else
  echo "Some fonts are missing - see the errors above." >&2
  echo "pubspec.yaml expects these exact filenames in assets/fonts/:" >&2
  echo "  Anton-Regular.ttf" >&2
  echo "  BarlowCondensed-{Medium,SemiBold,Bold,ExtraBold,Black}.ttf" >&2
  echo "  Nunito-{SemiBold,ExtraBold}.ttf" >&2
  echo "  Outfit-Black.ttf" >&2
  exit 1
fi
