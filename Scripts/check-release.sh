#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

release_files=("${(@f)$(git ls-files | rg -v '^Scripts/check-release\.sh$')}")

if rg -n -i \
  'hamza|linglink|studio-hamza|agent_shared_workspace|/Users/|/home/Hamza|DLA-730|certificate root' \
  -- "${release_files[@]}"; then
  print -u2 -- "Release check failed: private operational identifier found."
  exit 1
fi

if rg -n \
  'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*[^<[:space:]]{8,}' \
  -- "${release_files[@]}"; then
  print -u2 -- "Release check failed: possible secret found."
  exit 1
fi

if git ls-files | rg -i '(^|/)(\.env|.*\.(p12|pfx|pem|key|mobileprovision|sqlite|db|cookie))$'; then
  print -u2 -- "Release check failed: forbidden sensitive file type found."
  exit 1
fi

if git ls-files -s | awk '$1 == "120000" { print $4 }' | rg .; then
  print -u2 -- "Release check failed: symlink found."
  exit 1
fi

if rg -n 'URLSession|NSURLSession|CFNetwork|Network\.framework|socket\(|connect\(' Sources; then
  print -u2 -- "Release check failed: unexpected network API found."
  exit 1
fi

swift test
swift build -c release
plutil -lint Info.plist

print -- "release_check=passed"
