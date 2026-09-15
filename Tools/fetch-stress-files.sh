#!/bin/zsh
# Downloads known-troublesome SVGs (W3C 1.1 test suite, resvg edge cases) into TestFiles/stress/
# and generates hostile / malformed / sizing / performance cases locally.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)/TestFiles/stress"; mkdir -p "$DIR"; cd "$DIR"
R=https://raw.githubusercontent.com/linebender/resvg/main/crates/resvg/tests/tests
W=https://www.w3.org/Graphics/SVG/Test/20110816/svg
f() { curl -sfL -A "SVGViewer-tests" "$1" -o "$2" && printf "%-44s %7s\n" "$2" "$(stat -f%z "$2")" || echo "FAILED $2"; }
for n in attribute-value-via-ENTITY-reference elements-via-ENTITY-reference-1 deeply-nested-svg negative-size no-size zero-size not-UTF-8-encoding mixed-namespaces xmlns-validation viewBox-not-at-zero-pos preserveAspectRatio=none proportional-viewBox nested-svg-with-relative-width-and-height rect-inside-a-non-SVG-element no-children; do f "$R/structure/svg/$n.svg" "resvg-$n.svg"; done
f "$R/structure/style/external-CSS.svg" resvg-external-css.svg
f "$R/structure/image/external-png.svg" resvg-external-png.svg
f "$R/structure/image/embedded-svg.svg" resvg-embedded-svg.svg
f "$R/structure/use/self-recursive.svg" resvg-use-self-recursive.svg
f "$R/painting/marker/with-viewBox-1.svg" resvg-marker.svg
f "$R/masking/mask/recursive-on-child.svg" resvg-mask-recursive.svg
f "$R/masking/clipPath/self-recursive.svg" resvg-clip-self-recursive.svg
f "$R/filters/filter/huge-region.svg" resvg-filter-huge-region.svg
f "$R/text/text/bidi-reordering.svg" resvg-text-bidi.svg
f "$R/text/textPath/complex.svg" resvg-textpath.svg
for n in filters-composite-02-b filters-turb-01-f filters-light-01-f masking-path-04-b masking-intro-01-f painting-marker-01-f pservers-grad-13-b pservers-pattern-01-b fonts-elem-01-t text-tspan-01-b text-align-05-b animate-elem-02-t struct-use-01-t struct-symbol-01-b struct-image-04-t coords-trans-01-b color-prop-03-t render-elems-03-t script-handle-01-b interact-cursor-01-f; do f "$W/$n.svg" "w3c-$n.svg"; done
python3 "$(dirname "$0")/make-stress-files.py" "$DIR"
