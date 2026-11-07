"""Remove Xcode-only preview declarations from the pinned KeyboardShortcuts checkout.

This changes no runtime code. SwiftPM restores the upstream file on fresh resolution;
build.sh reapplies the patch. Keep this narrowly scoped to the known 2.2.4 source.
"""
from pathlib import Path
import re

path = Path('.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Recorder.swift')
source = path.read_text()
patched, count = re.subn(r'\n#Preview \{\n[^}]*\n\}\n', '\n', source)
if count not in (0, 3):
    raise SystemExit('Unexpected KeyboardShortcuts previews; review the CLT patch.')
if count:
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(patched)

# SwiftPM executable resource lookup otherwise requires an unsigned app-root bundle.
utilities = path.with_name('Utilities.swift')
source = utilities.read_text()
patched = source.replace('bundle: .module,', 'bundle: (Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("KeyboardShortcuts_KeyboardShortcuts.bundle")) } ?? .module),')
if patched != source:
    utilities.chmod(utilities.stat().st_mode | 0o200)
    utilities.write_text(patched)
