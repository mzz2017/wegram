"""Check recorded sim-use observations; this does not generate touch events."""
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else "build-input")
cases = {
    "touch": [(0, "light", False), (1, "dark", False), (2, "system", False),
              (3, "light", False), (4, "system", False), (4, "system", False),
              (5, "light", False), (5, "light", True), (5, "light", True), (5, "light", True)],
    "fixed": [(0, "light", False), (0, "light", True), (0, "light", True),
              (0, "light", True), (0, "light", False), (1, "dark", False), (2, "light", False)],
}
checks = 0
for series, expectations in cases.items():
    for index, expected in enumerate(expectations):
        path = root / f"wegram-dark-mode-{series}-{index:02}.json"
        data = json.loads(path.read_text())["data"]
        assert data["appPackage"] == "app.wegram.settingstesthost", path
        entries = {entry["uniqueId"]: entry for entry in data["entries"] if "uniqueId" in entry}
        status = entries["Fixture.Status"]["label"]
        match = re.search(r"events=(\d+)\s+mode=(\w+)\s+•\s+locked=(true|false)", status)
        assert match, (path, status)
        actual = (int(match[1]), match[2], match[3] == "true")
        assert actual == expected, (path, actual, expected)
        switch = entries["Wegram.Settings.FollowSystem"]
        assert switch["frame"]["width"] == 51 and switch["frame"]["height"] == 44, path
        assert switch["value"] == ("已开启" if expected[1] == "system" else "已关闭"), path
        assert ("disabled" in switch["states"]) == expected[2], path
        for identifier in ["Wegram.Settings.LightMode", "Wegram.Settings.DarkMode"]:
            if expected[1] == "system":
                assert identifier not in entries, path
            elif series == "fixed":
                assert ("disabled" in entries[identifier]["states"]) == expected[2], (path, identifier)
        checks += 1
print(f"{checks} recorded fixture observations passed: touch/drag/cancel counts and corrected disabled AX states")
