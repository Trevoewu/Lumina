"""Preserve script contents while supporting CocoaPods' string-only parser."""
import json
from pathlib import Path
import re

project = Path(__file__).resolve().parents[1] / 'Runner.xcodeproj/project.pbxproj'
original = project.read_text()


def as_string(match):
    lines = [json.loads(line.strip().removesuffix(','))
             for line in match.group(1).splitlines() if line.strip()]
    return 'shellScript = ' + json.dumps('\n'.join(lines)) + ';'

updated, count = re.subn(r'shellScript = \(\n(.*?)\n\s*\);', as_string,
                         original, flags=re.S)
if count:
    project.write_text(updated)
print(f'Normalized {count} Xcode script arrays for CocoaPods.')
