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
repo=$(basename "$PWD") \
  || die "failed to get repo name"
stack="$repo-$name"

# check auth.
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# retrieve repository topics.
topics=$(bin/00-list-repository-topics.sh "$GITHUB_REPOSITORY") \
  || die "failed to list repository topics"

# setup parameter overrides.
overrides=("Repository=$repo")

# add website parameters.
if [[ $topics == *website* ]]; then

  # list all domains.
  data=$(aws route53domains list-domains --region us-east-1) \
    || die "failed to list route53 domains"
  domains=$(<<< "$data" jq -r '.Domains[].DomainName') \
    || die "failed to parse response from listing route53 domains"

  # determine which domain.
  domain=""
  for d in $domains; do
    [[ $repo == *$d ]] && { domain=$d; break; }
  done
  [[ -z "$domain" ]] \
    && die "failed to determine which domain $repo belongs to"

  # determine hosted zone id from domain.
  hostedZoneId=$(aws route53 list-hosted-zones-by-name \
    --query "HostedZones[?Name=='$domain.'].Id" \
    --output text) \
    || die "failed to get hosted zone id for $domain"
  hostedZoneId=${hostedZoneId/\/hostedzone\//} # remove prefix.
  [[ -z "$hostedZoneId" ]] \
    && die "failed to determine a hostedZoneId that belongs to $domain"

  # determine certificate arn from domain.
  certs=$(aws acm list-certificates --region us-east-1) \
    || die "failed to list acm certificates"
  cert=$(<<<"$certs" jq -r --arg domain "$domain" \
    '.CertificateSummaryList[] | select(.DomainName==$domain) | .CertificateArn') \
    || die "failed to parse acm certificates response"
  [[ -z "$cert" ]] \
    && die "failed to determine a cert that belongs to $domain"

  # add overrides.
  overrides+=("Domain=$domain")
  overrides+=("HostedZoneId=$hostedZoneId")
  overrides+=("AcmCertificateArn=$cert")
fi

# deploy stack.
echo "##[group]Deploying $template"
echo aws cloudformation deploy \
  --region "$AWS_DEFAULT_REGION" \
  --template-file "$template" \
  --stack-name "$stack" \
  --tags repository="$repo" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides "${overrides[*]}" \
    || die "failed to deploy $stack"
echo "##[endgroup]"
