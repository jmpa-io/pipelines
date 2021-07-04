#!/usr/bin/env bash
# generates a README.md, from the found template.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(sed find)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# vars.
repo="$(basename "$PWD")" \
    || die "failed to get repository name"
repo="${repo^^}" # uppercase
repo="${repo,,}" # lowercase

# retrieve template.
file=".github/README.md.template"
[[ -f "$file" ]] \
  || die "missing $file"
template=$(cat "$file") \
  || die "failed to read $file"

# add repository name.
if [[ $template == *"%NAME%"* ]]; then
  template="${template/\%NAME\%/$repo}"
fi

# retrieve GitHub token.
token=$(aws ssm get-parameter --name "/tokens/github" \
  --query "Parameter.Value" --output text --with-decryption) \
  || die "failed to retrieve GitHub token from paramstore"

# retrieve GitHub repository description.
resp=$(curl -s "https://api.github.com/repos/jmpa-oss/$repo" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: bearer $token") \
  || die "failed to retrieve $repo repository info"
desc=$(<<< "$resp" jq -r '.description') \
  || die "failed to parse $repo repository info"
[[ $desc == "null" ]] && { desc="TODO"; }

# add GitHub description.
if [[ $template == *"%DESCRIPTION%"* ]]; then
  template="${template/\%DESCRIPTION\%/$desc}"
fi

# retrieve workflows.
workflows=$(find .github/workflows -type f -name '*.yml')
workflows=$(<<< "$workflows" sort --ignore-case) # sort alphabetically.

# add workflow badges.
pattern="%BADGES%"
if [[ $template == *"$pattern"* ]]; then
  # retrieve workflows.
  if [[ -z $workflows ]]; then
      # hide pattern in template; nothing to do.
      template=$(<<< "$template" sed "/${pattern}/,+1 d")
  else
      # generate badge urls.
      out=""
      for workflow in $workflows; do
        workflow="${workflow/\.github\/workflows\//}"
        name="${workflow/\.yml/}"
        [[ -z "$out" ]] || { out+="\n"; }
        out+="[![$name](https://github.com/jmpa-oss/$repo/actions/workflows/$workflow/badge.svg)](https://github.com/jmpa-oss/$repo/actions/workflows/$workflow)"
      done
      # update template.
      template="${template/\%BADGES\%/$out}"
  fi
fi

# add workflows table.
pattern="%WORKFLOWS_TABLE%"
if [[ $template == *$pattern* ]]; then
  if [[ -z $workflows ]]; then
    template=$(<<< "$template" sed "/$pattern/,+1 d")
  else
    # generate table.
    out="## workflows\n\n"
    out+="workflow|description\n"
    out+="---|---\n"
    for workflow in $workflows; do
      name="${workflow/\.github\/workflows\//}"
      name="${name/\.yml/}"

      # read workflow.
      data=$(cat "$workflow") \
        || die "failed to read $workflow"

      # extract workflow description.
      desc=$(<<< "$data" sed -n '/run\:$/,/runs-on\:/{/runs-on\:/!p;}')
      desc=${desc/run\:/}
      desc=${desc/name\:/}
      desc=$(<<< "$desc" awk '{$1=$1};1')
      desc=$(<<< "$desc" tr -d '\n')

      # generate row.
      out+="[$name]($workflow)|$desc\n"
    done
    # update template.
    template="${template/\%WORKFLOWS_TABLE\%/$out}"
  fi
fi

# update README.md with changes.
echo -e "$template" > README.md \
  || die "failed to update README.md"
