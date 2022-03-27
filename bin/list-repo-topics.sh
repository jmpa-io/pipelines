#!/usr/bin/env bash
# lists all topics for a given GitHub repository in a given org.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
usage() { echo "usage: $0 <org/repo>"; exit 64; }
diejq() { echo "$1:" >&2; jq '.' <<< "$2"; exit "${3:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(curl)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  s=""; [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# check args.
repo="$1"
[[ -z "$repo" ]] && usage

# get token.
token="$GITHUB_TOKEN"
[[ -z "$GITHUB_ACTION" ]] && {
  token=$(aws ssm get-parameter --name "/tokens/github" \
  --query "Parameter.Value" --output text \
  --with-decryption 2>/dev/null)
}
[[ -z "$token" ]] && die "missing token"

# retrieve topics.
resp=$(curl -s "https://api.github.com/repos/$repo/topics" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: bearer $token") \
  || die "failed curl to retrieve repository topics for $repo"
[[ $(<<< $resp jq '.message') != null ]] \
  && diejq "failed to retrieve repository topics for $repo" "$resp"

# parse topics.
topics=$(<<< "$resp" jq -r '.names | @csv' | tr -d '"' 2>/dev/null) \
  || die "failed to parse response from retrieving repository topics for $repo"
echo "$topics"