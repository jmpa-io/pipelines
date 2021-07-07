#!/usr/bin/env bash
# updates child repositories using this template, using a repository_dispatch event.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
diejq() { echo "$1" >&2; jq '.' <<< "$2"; exit "${3:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(aws curl jq)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# check auth.
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# retrieve GitHub token.
token=$(aws ssm get-parameter --name "/tokens/github" \
  --query "Parameter.Value" --output text --with-decryption) \
  || die "failed to retrieve GitHub token from paramstore"

# retrieve repository name.
name=$(basename "$PWD") \
  || die "failed to get repository name"

# retrieve repositories using this template.
repos=()
cursor=null
while :; do

  # https://docs.github.com/en/free-pro-team@latest/graphql/overview/explorer
  # shellcheck disable=SC2162
  read -d '' q <<@
query (\$c: String) {
  organization(login: "jmpa-oss") {
    repositories(after: \$c, first: 100) {
      pageInfo {
        endCursor
        hasNextPage
      }
      edges {
        node {
          name
          templateRepository {
            name
          }
        }
      }
    }
  }
}
@

  # clean query.
  q=$(echo "${q//\"/\\\"}" | tr -d '\n' | tr -s ' ')

  # retrieve data.
  resp=$(curl -s "https://api.github.com/graphql" \
    -H "Content-Type: application/json" \
    -H "Authorization: bearer $token" \
    -d "{\"query\": \"$q\", \"variables\": { \"c\": $cursor}}") \
    || die "failed curl to retrieve repository list"

  # check for errors.
  err=$(<<< "$resp" jq '.errors') \
    || die "failed to parse error from repository list"
  [[ "$err" != null ]] \
    && diejq "error returned when retrieving repository list:" "$err"

  # parse data.
  data=$(<<<"$resp" jq '.data.organization.repositories') \
    || die "failed to parse repositories from repository list"
  raw=$(<<<"$data" jq -r --arg name "$name" \
    '.edges[].node | select(.templateRepository.name==$name) | .name') \
    || die "failed to parse repository name from repository list"
  for r in $raw; do
    repos+=("$r")
  done

  # paginate?
  hasNextPage=$(<<<"$data" jq -r '.pageInfo.hasNextPage') \
    || die "failed to parse hasNextPage from repository list"
  [[ $hasNextPage == "false" ]] && { break; }
  cursor=$(<<<"$data" jq -r '.pageInfo.endCursor') \
    || die "failed to parse endCursor from repository list"
  # quoting cursor here, since GitHub GraphQL doesn't
  # seem to support "null" as a value in the request.
  cursor="\"$cursor\""
done

# fail early on no child repositories.
[[ ${#repos[@]} -eq 0 ]] \
  && die "no repositories found using '$name' template" 0

# create a repository_dispatch event for each child repository.
# https://docs.github.com/en/free-pro-team@latest/rest/reference/repos#create-a-repository-dispatch-event
for repo in "${repos[@]}"; do
  echo "##[group]Posting dispatch event to $repo"
  curl -s "https://api.github.com/repos/jmpa-oss/$repo/dispatches" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: bearer $token" \
    -d "{\"event_type\": \"update\"}" \
    || die "failed curl to post repository_dispatch event to $repo"
  [[ $(<<< "$resp" jq -r '.message') == "Not Found" ]] && \
    diejq "error returned when sending out repository_dispatch to $repo:" "$resp"
  echo "##[endgroup]"
done
