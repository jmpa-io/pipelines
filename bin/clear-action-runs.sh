#!/usr/bin/env bash
# clears all GitHub Action runs for a given GitHub repository.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
usage() { echo "usage: $0 <org/repo>"; exit 64; }

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

# retrieve GitHub token.
token="$GITHUB_TOKEN"
if [[ -z "$token" && -z "$GITHUB_ACTION" ]]; then
  aws sts get-caller-identity &>/dev/null \
    || die "unable to connect to AWS; are you authed?"
  token=$(aws ssm get-parameter --name "/tokens/github" \
    --query "Parameter.Value" --output text \
    --with-decryption 2>/dev/null) \
    || die "failed to get GitHub token from paramstore"
fi
[[ -z "$token" ]] \
  && die "missing \$GITHUB_TOKEN"

# retrieve ALL action runs.
resp=$(curl -s "https://api.github.com/repos/$repo/actions/runs" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: bearer $token") \
  || die "failed curl to retrieve $repo action runs"
ids=$(<<< "$resp" jq '.workflow_runs[].id') \
  || die "failed to parse response when retrieving $repo action runs"

# clear ALL workflow runs.
for id in $ids; do
  curl -X DELETE -s "https://api.github.com/repos/$repo/actions/runs/$id" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: bearer $token" \
    || die "failed curl to delete $repo action run $id"
done

# # clear ALL workflows runs extra.
# for a in $(curl -s "https://api.github.com/repos/$repo/actions/runs"|jq -r .workflow_runs[].id); do
#   curl   -X DELETE   -H "Accept: application/vnd.github.v3+json"  \
#   -H "Authorization: token TOKEN " \
#   "https://api.github.com/repos/OWNER/REPO/actions/runs/$a";
# done

# # list workflows.
# resp=$(curl -s "https://api.github.com/repos/$repo/actions/workflows" \
#   -H "Accept: application/vnd.github.v3+json" \
#   -H "Authorization: bearer $token") \
#   || die "failed curl to retrieve $repo workflows"
# ids=$(<<< "$resp" jq -r '.workflows[].id') \
#   || die "failed to parse response when retrieving $repo workflows"

# # clear workflow runs.
# for id in $ids; do
#   resp=$(curl -s "https://api.github.com/repos/$repo/actions/workflows/$id/runs" \
#     -H "Accept: application/vnd.github.v3+json" \
#     -H "Authorization: bearer $token") \
#     || die "failed curl to retrieve $repo workflow $id"
#   runIds=$(<<< "$resp" jq '.workflow_runs[].id') \
#     || die "failed to parse response when retrieving $repo workflow $id"
#   for runId in $runIds; do
#     curl -X DELETE -s "https://api.github.com/repos/$repo/actions/runs/$runId" \
#       -H "Accept: application/vnd.github.v3+json" \
#       -H "Authorization: bearer $token" \
#       || die "failed curl to delete $repo workflow $id run $runId"
#   done
# done
