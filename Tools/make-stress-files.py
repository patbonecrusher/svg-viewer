#!/usr/bin/env python3
"""Generates hostile, malformed, sizing and performance SVGs for viewer robustness testing."""
import pathlib
import random
import sys

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "TestFiles/stress")
out.mkdir(parents=True, exist_ok=True)
w = lambda n, s: (out / n).write_text(s)
wb = lambda n, b: (out / n).write_bytes(b)
SVG = 'xmlns="http://www.w3.org/2000/svg"'

# --- hostile: must not hang, execute, leak styles, or touch the network
ents = ' <!ENTITY a "' + "a" * 64 + '">\n'
for prev, cur in zip("abcdef", "bcdefg"):
    ents += f' <!ENTITY {cur} "' + f"&{prev};" * 10 + '">\n'
w("hostile-billion-laughs.svg", f'<?xml version="1.0"?>\n<!DOCTYPE svg [\n{ents}]>\n'
  f'<svg {SVG} width="200" height="100"><text x="10" y="50">&g;</text><rect width="50" height="50" fill="red"/></svg>')
w("hostile-xxe.svg", f'<?xml version="1.0"?>\n<!DOCTYPE svg [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>\n'
  f'<svg {SVG} width="400" height="100"><text x="10" y="50" font-size="10">&xxe;</text><rect width="40" height="40" fill="green"/></svg>')
w("hostile-script.svg", f'''<svg {SVG} width="200" height="100" onload="document.body.style.background='red'">
<script>document.body.style.background='red'; document.title='pwned';</script>
<rect width="200" height="100" fill="green" onclick="this.setAttribute('fill','red')"/>
<a href="javascript:alert(1)"><text x="20" y="55" fill="white">click me</text></a></svg>''')
w("hostile-external-refs.svg", f'''<svg {SVG} xmlns:xlink="http://www.w3.org/1999/xlink" width="300" height="150">
<image href="https://upload.wikimedia.org/wikipedia/commons/0/02/SVG_logo.svg" width="100" height="100"/>
<image xlink:href="file:///System/Library/CoreServices/DefaultDesktop.heic" x="100" width="100" height="100"/>
<use href="https://example.com/x.svg#frag"/>
<style>@import url("https://example.com/x.css"); @font-face{{font-family:X;src:url(https://example.com/f.woff)}}</style>
<rect y="110" width="300" height="40" fill="green"/><text x="10" y="135" fill="white">only this rect+text should render</text></svg>''')
w("hostile-css-leak.svg", f'''<svg {SVG} width="200" height="100">
<style>body{{background:red !important}} html{{background:red}} #stage{{display:none}} svg{{width:9999px !important}}</style>
<rect width="200" height="100" fill="green"/></svg>''')

# --- malformed
w("malformed-no-xmlns.svg", '<svg width="200" height="100"><rect width="200" height="100" fill="green"/></svg>')
w("malformed-unclosed.svg", f'<svg {SVG} width="200" height="100"><g><rect width="200" height="100" fill="green"><text x="10" y="50">unclosed</svg>')
w("malformed-not-svg.svg", '<html><body><p>this is html, not svg</p></body></html>')
w("malformed-empty.svg", '')
w("malformed-garbage.svg", 'hello world this is not xml at all <<<<')
w("malformed-two-roots.svg", f'<svg {SVG} width="100" height="100"><rect width="100" height="100" fill="green"/></svg><svg {SVG}><rect width="100" height="100" fill="red"/></svg>')
w("malformed-bom-utf8.svg", f'﻿<svg {SVG} width="200" height="100"><rect width="200" height="100" fill="green"/></svg>')
wb("malformed-utf16.svg", f'<?xml version="1.0" encoding="UTF-16"?><svg {SVG} width="200" height="100"><rect width="200" height="100" fill="green"/><text x="10" y="50">UTF-16 ✓</text></svg>'.encode("utf-16"))
wb("malformed-latin1.svg", f'<?xml version="1.0" encoding="ISO-8859-1"?><svg {SVG} width="300" height="100"><rect width="300" height="100" fill="green"/><text x="10" y="50" fill="white">Café crème - été</text></svg>'.encode("latin-1"))

# --- sizing
w("size-percent-only.svg", f'<svg {SVG} width="100%" height="100%"><circle cx="50" cy="50" r="40" fill="green"/></svg>')
w("size-percent-with-viewbox.svg", f'<svg {SVG} width="100%" height="100%" viewBox="0 0 200 100"><rect width="200" height="100" fill="green"/></svg>')
w("size-mm-units.svg", f'<svg {SVG} width="210mm" height="297mm" viewBox="0 0 210 297"><rect width="210" height="297" fill="#eee"/><text x="20" y="40" font-size="14">A4 in mm</text></svg>')
w("size-em-units.svg", f'<svg {SVG} width="20em" height="10em" viewBox="0 0 200 100"><rect width="200" height="100" fill="green"/></svg>')
w("size-huge-viewbox.svg", f'<svg {SVG} viewBox="0 0 1000000 500000"><rect width="1000000" height="500000" fill="green"/><circle cx="500000" cy="250000" r="200000" fill="white"/></svg>')
w("size-tiny.svg", f'<svg {SVG} width="1" height="1"><rect width="1" height="1" fill="green"/></svg>')
w("size-huge-px.svg", f'<svg {SVG} width="100000" height="100000"><rect width="100000" height="100000" fill="green"/></svg>')
w("size-negative-viewbox-origin.svg", f'<svg {SVG} viewBox="-100 -50 200 100"><rect x="-100" y="-50" width="200" height="100" fill="green"/><circle r="30" fill="white"/></svg>')
w("size-fractional.svg", f'<svg {SVG} width="123.456" height="78.9"><rect width="123.456" height="78.9" fill="green"/></svg>')
w("size-exponent.svg", f'<svg {SVG} width="2e2" height="1e2"><rect width="2e2" height="1e2" fill="green"/></svg>')
w("size-nothing-getbbox.svg", f'<svg {SVG}><rect x="50" y="20" width="300" height="150" fill="green"/></svg>')

# --- performance
random.seed(1)
paths = "".join(f'<path d="M{random.randint(0,2000)} {random.randint(0,2000)} l{random.randint(-50,50)} {random.randint(-50,50)} l{random.randint(-50,50)} {random.randint(-50,50)}z" fill="hsl({i%360},70%,50%)" opacity=".7"/>' for i in range(50000))
w("perf-50k-paths.svg", f'<svg {SVG} viewBox="0 0 2000 2000">{paths}</svg>')
w("perf-deep-nesting-5000.svg", f'<svg {SVG} width="100" height="100">' + "<g>" * 5000 + '<rect width="100" height="100" fill="green"/>' + "</g>" * 5000 + '</svg>')
w("perf-heavy-filters.svg", f'<svg {SVG} viewBox="0 0 800 800"><defs><filter id="f"><feTurbulence baseFrequency=".01" numOctaves="8"/><feGaussianBlur stdDeviation="20"/><feColorMatrix type="hueRotate" values="90"/><feMorphology radius="5"/></filter></defs>'
  + "".join(f'<rect x="{(i%10)*80}" y="{(i//10)*80}" width="80" height="80" filter="url(#f)"/>' for i in range(100)) + '</svg>')
big = "M" + " ".join(f"{random.random()*1000:.3f},{random.random()*1000:.3f}" for _ in range(300000))
w("perf-one-giant-path.svg", f'<svg {SVG} viewBox="0 0 1000 1000"><path d="{big}" fill="none" stroke="green" stroke-width=".2"/></svg>')
print(f"wrote stress files to {out}")
