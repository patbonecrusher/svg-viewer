#!/bin/zsh
# Downloads real-world SVGs from many generators (Illustrator, Pixelmator, Sketch, Inkscape, Affinity,
# foreignObject, embedded bitmaps, large maps) into TestFiles/ for manual rendering checks.
set -u
mkdir -p "$(dirname "$0")/../TestFiles" && cd "$(dirname "$0")/../TestFiles"
UA="SVGViewer-tests (https://github.com/patbonecrusher/svg-viewer)"
fetch() { curl -sfL -A "$UA" "$1" -o "$2" && printf "%-28s %8s
" "$2" "$(stat -f%z "$2")" || echo "FAILED $2"; }
fetchc() { url=$(curl -sf -A "$UA" "https://commons.wikimedia.org/w/api.php?action=query&titles=File:$1&prop=imageinfo&iiprop=url&format=json" | python3 -c 'import json,sys; p=json.load(sys.stdin)["query"]["pages"]; print(next(iter(p.values())).get("imageinfo",[{}])[0].get("url",""))'); [ -n "$url" ] && fetch "$url" "$2" || echo "FAILED $1"; }
raw=https://raw.githubusercontent.com
fetch $raw/apache/groovy-geb/9c73494607825cd8900d51681919737e17c6fb12/logo.svg illustrator-geb-logo.svg
fetch $raw/browserpass/browserpass-extension/abf70278ada7e770f0091a0296f4dd94650b4dbd/src/icon.svg illustrator-browserpass.svg
fetch $raw/jayleicn/scipy-lecture-notes-zh-CN/cc87204fcc4bd2f4702f7c29c83cb8ed5c94b7d6/euroscipy2010.svg illustrator-euroscipy.svg
fetch $raw/gobuffalo/buffalo/2aa9868365cdcaa28036efd76e7aac4b7df7bbfc/logo.svg illustrator2-buffalo.svg
fetch $raw/remotemobprogramming/mob/6efd2d0d667bd70e46e0a9878d34da075675618d/logo.svg illustrator2-mob.svg
fetch $raw/fabiolb/fabio/2aad4553c7f96011ee39db91896a691ee745cb84/fabio.svg sketch-fabio.svg
fetch $raw/kefirjs/kefir/d1c51fd56bb1997f66faed98c58f1701791ed1ed/Kefir.svg sketch-kefir.svg
fetch $raw/HFO4/gameboy.live/45f030c181c14e4377cc6cd2a7543e3d7e797363/gb.svg inkscape-gameboy.svg
fetch $raw/radareorg/awesome-radare2/ecef0dd431f686a2854e4a55c154043d5211d014/r2.svg inkscape-r2.svg
fetch $raw/woheller69/eggtimer/881bb8810baf05656cc3c28233148c3fdec92592/egg.svg inkscape-egg.svg
fetch "$raw/Mibea/Hatter/e2be38b856d55bfa578a51c5c7c36c41528982e9/Hatter/scalable/apps/Affinity%20Designer.svg" affinity-icon.svg
fetch $raw/iommirocks/iommi/43d732fefaa08d030a244e84e38d3e47ca94d5cb/logo.svg pixelmator-iommi.svg
fetch $raw/nalgeon/redka/d3c353f024704f99c87049251bb987beba62915e/logo.svg pixelmator-redka.svg
fetch $raw/mattallty/Caporal.js/34bf9aa644a59b4ddc6768c00b88de843e08994d/assets/caporal.svg pixelmator-caporal.svg
fetch $raw/KingSora/OverlayScrollbars/dfa819688a529db0085c6416a94e816bfbaeaf29/logo/logo.svg illustrator-embedded-png.svg
fetch $raw/sindresorhus/css-in-readme-like-wat/d123714bbbadaa7ce854759e660eacc7c0629fb1/header.svg foreignobject-header.svg
fetch $raw/rikschennink/fitty/310295262598fc88dfc330c169cb55d20f316b6b/header.svg foreignobject-fitty.svg
fetch https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/ny1.svg w3-ny1.svg
fetch https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/Steps.svg w3-steps.svg
fetch https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/gallardo.svg w3-gallardo.svg
fetch https://upload.wikimedia.org/wikipedia/commons/f/fd/Ghostscript_Tiger.svg tiger.svg
fetch https://upload.wikimedia.org/wikipedia/commons/0/02/SVG_logo.svg svg-logo.svg
fetch https://upload.wikimedia.org/wikipedia/commons/6/6c/Trajans-Column-lower-animated.svg wiki-animated.svg
fetchc Map_of_USA_with_state_names.svg map-usa.svg
fetchc Bitmap_VS_SVG.svg bitmap-vs-svg.svg
fetchc Anatomy_of_the_Human_Ear.svg human-ear.svg
fetchc Flag_of_Canada.svg flag-canada.svg
gzip -kf svg-logo.svg && mv svg-logo.svg.gz svg-logo.svgz
