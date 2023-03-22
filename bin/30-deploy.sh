#!/usr/bin/env bash
# deploys the given cloudformation template to the authed AWS account.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
usage() { echo "usage: $0 <templates-to-deploy>"; exit 64; }

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
templates=$*
[[ -z "$templates" ]] && usage

# vars.
repo=$(basename "$PWD") \
  || die "failed to get repository name"
fullRepo="$GITHUB_REPOSITORY"
[[ -z "$fullRepo" ]] \
  && die "missing \$GITHUB_REPOSITORY"

# check auth.
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# retrieve repository topics.
topics=$(bin/list-repository-topics.sh "$fullRepo") \
  || die "failed to list repository topics"

# validate given templates.
templatesToDeploy=(); missing=()
for t in $templates; do

  # extract template name, if given in a path format.
  if [[ $t == cf/*/template.yml ]]; then
    t=${t//cf\//}              # remove cf prefix.
    t=${t//\/template\.yml/}   # remove /template.yml suffix.
  fi

  # does the template file actually exist?
  template="cf/$t/template.yml"
  [[ -f "$template" ]] \
    || { missing+=("$template"); continue; }

  # setup package file.
  package="cf/$t/package.yml"

  # determine name of the service.
  name="$t"
  name="${name//00-/}"

  # append.
  templatesToDeploy+=("$name,$template,$package")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  s=""; [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing template${s}: ${missing[*]}"
fi

# deploy templates.
for t in "${templatesToDeploy[@]}"; do
  name=$(<<< "$t" cut -d',' -f1)
  template=$(<<< "$t" cut -d',' -f2)
  package=$(<<< "$t" cut -d',' -f3)

  # decide stack name.
  stack="$repo-$name"
  if [[ "$topics" == *website* && "$stack" == *website* ]]; then
    stack="$repo"
  fi
  stack="${stack//\./\-}"

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
      && die "failed to determine a hostedZoneId for $domain"

    # determine certificate arn from domain.
    certs=$(aws acm list-certificates --region us-east-1) \
      || die "failed to list acm certificates"
    cert=$(<<<"$certs" jq -r --arg domain "$domain" \
      '.CertificateSummaryList[] | select(.DomainName==$domain) | .CertificateArn') \
      || die "failed to parse acm certificates response"
    [[ -z "$cert" ]] \
      && die "failed to determine a cert for $domain"

    # update domain to be sub-domain, only after determining everything.
    [[ $repo == *$domain && $domain != "$repo" ]] \
      && { domain="$repo"; }

    # add overrides.
    overrides+=("HostedZoneId=$hostedZoneId")
    overrides+=("Domain=$domain")
    overrides+=("AcmCertificateArn=$cert")
  fi

  # add redirect parameters.
  if [[ $topics == *redirect* ]]; then

    # read vars.
    redirectUrl="$REDIRECT_URL"
    redirectProtocol="$REDIRECT_PROTOCOL"
    [[ -z "$redirectUrl" ]] \
      && die "missing \$REDIRECT_URL"
    [[ -z "$redirectProtocol" ]] \
      && die "missing \$REDIRECT_PROTOCOL"

    # add overrides.
    overrides+=("RedirectUrl=$redirectUrl")
    overrides+=("RedirectProtocol=$redirectProtocol")
  fi

  # add lambda parameters.
  if [[ $topics == *lambda* ]]; then

    # retrieve lambda bucket.
    bucket=$(aws ssm get-parameter --name /buckets/lambda \
      --query 'Parameter.Value' --output text --with-decryption) \
      || die "failed to retrieve lambda bucket from paramstore"

    # package template.
    echo "##[group]Packaging $name"
    aws cloudformation package \
      --region "$AWS_DEFAULT_REGION" \
      --template-file "$template" \
      --output-template-file "$package" \
      --s3-prefix "$name" \
      --s3-bucket "$bucket" \
      || die "failed to package $template for $name"
    echo "##[endgroup]"

    # alter path to template.
    template="$package"

    # retrieve hosted zone id.
    domain="jcleal.me"
    hostedZoneId=$(aws route53 list-hosted-zones-by-name \
      --query "HostedZones[?Name=='$domain.'].Id" --output text) \
      || die "failed to determine a hostedZoneId for $domain"
    [[ -z "$hostedZoneId" ]] \
      && die "failed to find a hostedZoneId for $domain"
    hostedZoneId=${hostedZoneId/\/hostedzone\//}

    # determine certificate arn from domain.
    cert=$(aws acm list-certificates \
      --query "CertificateSummaryList[?DomainName=='$domain'].CertificateArn" \
      --output text) \
      || die "failed to determine a certificate arn for $domain"
    [[ -z "$cert" ]] \
      && die "failed to find a certificate for $domain"

    # add overrides.
    overrides+=("HostedZoneId=$hostedZoneId")
    overrides+=("Domain=$domain")
    overrides+=("AcmCertificateArn=$cert")
  fi

  # deploy stack.
  echo "##[group]Deploying $name"
  aws cloudformation deploy \
    --region "$AWS_DEFAULT_REGION" \
    --template-file "$template" \
    --stack-name "$stack" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --parameter-overrides "${overrides[@]}" \
    --tags repository="$repo" \
      || die "failed to deploy $stack"
  echo "##[endgroup]"
done
