#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

release_files=("${(@f)$(git ls-files | grep -Ev '^Scripts/check-release\.sh$')}")

if grep -EInI \
  'hamza|linglink|studio-hamza|agent_shared_workspace|/Users/|/home/Hamza|DLA-730|certificate root' \
  -- "${release_files[@]}"; then
  print -u2 -- "Release check failed: private operational identifier found."
  exit 1
fi

if grep -EInI \
  'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----' \
  -- "${release_files[@]}"; then
  print -u2 -- "Release check failed: possible secret found."
  exit 1
fi

if grep -EInIi \
  '(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*[^<[:space:]]{8,}' \
  -- "${release_files[@]}"; then
  print -u2 -- "Release check failed: possible credential assignment found."
  exit 1
fi

if git ls-files | grep -Eiq '(^|/)(\.env|.*\.(p12|pfx|pem|key|mobileprovision|sqlite|db|cookie))$'; then
  print -u2 -- "Release check failed: forbidden sensitive file type found."
  exit 1
fi

if [[ -n "$(git ls-files -s | awk '$1 == "120000" { print $4 }')" ]]; then
  print -u2 -- "Release check failed: symlink found."
  exit 1
fi

if grep -EInI 'URLSession|NSURLSession|CFNetwork|Network\.framework|socket\(|connect\(' Sources/*/*.swift; then
  print -u2 -- "Release check failed: unexpected network API found."
  exit 1
fi

swift test
swift build -c release
plutil -lint Info.plist

print -- "release_check=passed"
