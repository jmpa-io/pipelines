#!/usr/bin/env bash
# deploys a cloudformation stack, based on the given template.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
usage() { echo "usage: $0 <template-name>"; exit 64; }

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

# check args.
name="$1"
[[ -z "$name" ]] && usage
if [[ $name == cf/*.yml ]]; then
  name=${name/cf\//}
  name=${name/\.yml/}
fi

# check template.
template="cf/$name.yml"
[[ -f "$template" ]] || \
  die "missing $template"

# vars.
project=$(basename "$PWD") \
  || die "failed to get project name"
stack="$project-$name"

# check auth.
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# retrieve repository topics.
topics=$(bin/00-list-repository-topics.sh "$GITHUB_REPOSITORY") \
  || die "failed to list repository topics"

echo "$topics"
exit 0

# deploy stack.
echo "##[group]Deploying $template"
aws cloudformation deploy \
  --region "$AWS_DEFAULT_REGION" \
  --template-file "$template" \
  --stack-name "$stack" \
  --tags project="$project" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
    || die "failed to deploy $stack"
echo "##[endgroup]"
