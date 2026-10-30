"""Small publication-hygiene checks. Does not audit secrets or Git history."""

import configparser
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def main():
    errors = []
    required = [
        "README.md", "README.ru.md", "LICENSE", "NOTICE.md", "SECURITY.md",
        "docs/BUILDING.md", "docs/PUBLISHING.md", "docs/SCRATCH_CARDS.md",
        "build-system/public-development.example.json",
    ]
    for name in required:
        if not (ROOT / name).is_file():
            errors.append(f"Missing publication file: {name}")

    raw = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
    )
    candidates = set(raw.decode().rstrip("\0").split("\0")) - {""}
    private_files = {".env", "build-system/local_configuration.json"}
    for name in sorted(candidates):
        if name in private_files or name.startswith(("local/", "private/", "codesigning/")):
            errors.append(f"Personal file would be published: {name}")
        path = ROOT / name
        if not path.is_symlink() and path.is_file() and path.stat().st_size >= 100 * 1024 * 1024:
            errors.append(f"File is at least 100 MiB: {name}")

    modules = configparser.ConfigParser()
    modules.read(ROOT / ".gitmodules")
    for section in modules.sections():
        url = modules.get(section, "url", fallback="")
        if not url.startswith("https://github.com/"):
            errors.append(f"Submodule needs an absolute public HTTPS URL: {section}")

    example = ROOT / "build-system/public-development.example.json"
    if example.is_file():
        config = json.loads(example.read_text())
        for key in ("api_id", "api_hash", "team_id"):
            if not str(config.get(key, "")).startswith("YOUR_"):
                errors.append(f"Public configuration must contain a placeholder for {key}")
        if config.get("bundle_id") != "com.example.scratchcards":
            errors.append("Public configuration must use the example bundle id")

    for name in ("README.md", "README.ru.md", "NOTICE.md"):
        path = ROOT / name
        if path.is_file() and "https://t.me/meeckhaill" not in path.read_text():
            errors.append(f"Missing feature-author attribution: {name}")

    html = ROOT / "prototypes/party-cover/index.html"
    if html.is_file() and "data:image/png;base64," in html.read_text():
        errors.append("Public HTML lab embeds local PNG exports; run its default build.py")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("PASS: publication metadata, author credit, public submodule URLs, example configuration and file hygiene")
    print("Scope: working tree/candidate files only; not a credential or history audit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
