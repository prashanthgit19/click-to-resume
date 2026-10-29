#!/usr/bin/env python3
"""Fix XcodeGen's serialized SystemCapabilities value.

XcodeGen currently writes the App Groups capability as a quoted string:
    SystemCapabilities = "[...]";
Xcode expects a dictionary. This script converts that line to the proper
pbxproj structure so the Xcode UI keeps the capability.
"""

import sys
from pathlib import Path


def fix(path: Path) -> int:
    lines = path.read_text().splitlines()
    output = []
    changed = 0

    for line in lines:
        if (
            line.lstrip().startswith('SystemCapabilities = "')
            and "ApplicationGroups" in line
        ):
            indent = line[: len(line) - len(line.lstrip())]
            output.extend(
                [
                    f"{indent}SystemCapabilities = {{",
                    f"{indent}\tcom.apple.ApplicationGroups = {{",
                    f"{indent}\t\tenabled = 1;",
                    f"{indent}\t}};",
                    f"{indent}}};",
                ]
            )
            changed += 1
        else:
            output.append(line)

    if changed:
        path.write_text("\n".join(output) + "\n")

    return changed


def main() -> None:
    path = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path("DevSessions.xcodeproj/project.pbxproj")
    )
    changed = fix(path)
    if changed:
        print(f"Fixed App Groups capability metadata in {path}")
    else:
        print(f"App Groups capability metadata already valid in {path}")


if __name__ == "__main__":
    main()
