#!/usr/bin/env bash
# uploads the dist directory to an expected S3 bucket in the authed AWS account.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps
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

# does the dist directory exist?
path="dist"
[[ -d "$path" ]] \
  || die "missing $path"

# retrieve stack name.
stack="$(basename "$PWD")" \
  || die "failed to get repository name"
stack="${stack//\./-}"

# get bucket.
bucket=$(aws cloudformation describe-stacks --stack-name "$stack" \
  --query "Stacks[].Outputs[?OutputKey=='Bucket'].OutputValue" --output text) \
  || die "failed to get bucket name for $stack"

# upload to s3.
echo "##[group]Uploading $path to S3"
aws s3 sync --delete --exact-timestamps "$path" "s3://$bucket" \
  || die "failed to sync $path to $bucket"
echo "##[endgroup]"
