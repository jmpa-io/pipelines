#!/usr/bin/env bash
# invalidates files in the CloudFront cache, for the repostitory this script is
# execututed in - best to be run in a website repository.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(aws)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  s=""; [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# check auth.
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# vars.
repo="$(basename "$PWD")" \
  || die "failed to get repository name"

# get distribution id.
data=$(aws cloudfront list-distributions --query 'DistributionList.Items[]') \
  || die "failed to list cloudfront distributions"
distributionId=$(<<< "$data" jq -r --arg name "$repo" '.[] | select(.Comment==$name) | .Id') \
  || die "failed to parse response from listing cloudfront distbutions"
[[ -z "$distributionId" ]] \
  && die "failed to find distribution id for $repo"

# invalidate distribution.
aws cloudfront create-invalidation \
  --distribution-id "$distributionId" \
  --paths "/*" \
  || die "failed to create cloudfront invalidation"
