#!/usr/bin/env bash
# generates a README.md, using a README.md template.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }
usage() { echo "usage: $0 <org>"; exit 64; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(curl sed find awk sort)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  s=""; [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# check args.
org="$1"
[[ -z "$org" ]] && usage

# vars.
path="$PWD"
[[ -n "$GITHUB_REPOSITORY" ]] && { path="$GITHUB_REPOSITORY"; }
name="$(basename "$path")" \
  || die "failed to get repository name"
name="${name^^}" # uppercase.
name="${name,,}" # lowercase.
repo="$org/$name"

# check auth, if able.
if [[ -z "$GITHUB_ACTION" ]]; then
  aws sts get-caller-identity &>/dev/null \
    || die "unable to connect to AWS; are you authed?"
fi

# retrieve template.
file="templates/README.md"
[[ -f "$file" ]] \
  || die "missing $file"
template=$(cat "$file") \
  || die "failed to read $file"

# retrieve workflows.
workflows=""
if [[ -d .github/workflows ]]; then
  workflows=$(find .github/workflows -type f -name '*.yml') \
    || die "failed to retrieve workflows"
  workflows=$(<<< "$workflows" sort)
fi

# retrieve scripts.
scripts=""
if [[ -d bin ]]; then
  scripts=$(find bin -mindepth 1 -maxdepth 1 -type f -name '*.sh') \
    || die "failed to retrieve scripts"
  scripts=$(<<< "$scripts" sort)
fi

# retrieve logo.
logo=$(find docs -name 'logo.*' -type f 2>/dev/null)

# retrieve GitHub token.
token="$GITHUB_TOKEN"
if [[ -z "$GITHUB_ACTION" ]]; then
  token=$(aws ssm get-parameter --name "/tokens/github" \
    --query "Parameter.Value" --output text \
    --with-decryption 2>/dev/null) \
    || die "failed to get GitHub API token from paramstore"
fi
[[ -z "$token" ]] \
  && die "missing \$GITHUB_TOKEN"

# retrieve GitHub repository description.
resp=$(curl -s "https://api.github.com/repos/$repo" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: bearer $token") \
  || die "failed to retrieve $repo data"
desc=$(<<< "$resp" jq -r '.description') \
  || die "failed to parse $repo data"
[[ $desc == "null" ]] && { desc="TODO"; }

# ---

# add workflow badges.
pattern="%BADGES%"; out="";
if [[ $template == *"$pattern"* ]]; then
  if [[ -z $workflows ]]; then
    template=$(<<< "$template" sed "/$pattern/,+1 d" 2>/dev/null)
  else
    for workflow in $workflows; do
      workflow="${workflow/\.github\/workflows\//}"
      [[ "$name" == "roots" && "${workflow:0:1}" != "." ]] \
        && { continue; } # skip workflows that are called from other repos.
      [[ -n "$out" ]] && { out+="\n"; }
      out+="[![$workflow](https://github.com/$repo/actions/workflows/$workflow/badge.svg)](https://github.com/$repo/actions/workflows/$workflow)"
    done
    pattern="${pattern//\%/\\\%}"
    template="${template//$pattern/$out}"
  fi
fi

# add logo.
pattern="%LOGO%"; out="";
if [[ $template == *"$pattern"* ]]; then
  if [[ -z "$logo" ]]; then
    template=$(<<< "$template" sed "/$pattern/,+1 d" 2>/dev/null)
  else
    out="<p align=\"center\">\n  <img src=\"$logo\"/>\n</p>"
    pattern="${pattern//\%/\\\%}"
    template="${template//$pattern/$out}"
  fi
fi

# add name.
pattern="%NAME%"; out="";
if [[ $template == *"$pattern"* ]]; then
  out="# \`$name\`"
  template="${template//$pattern/$out}"
fi

# add description, truncated to 80 chars.
pattern="%DESCRIPTION%"; out="";
if [[ $template == *"$pattern"* ]]; then
  pattern="${pattern//\%/\\\%}"
  out=$(<<<"$desc" fold -sw 80) \
    || die "failed to fold description"
  # shellcheck disable=2001
  out=$(<<< "$out" sed 's/^/+ /') \
    || die "failed to prepend pluses to description"
  out=$(<<< "$out" awk '{$1=$1};1') \
    || die "failed to remove trailing whitespace from description"
  template="${template//$pattern/$out}"
fi

# add scripts table.
pattern="%SCRIPTS_TABLE%"; out="";
if [[ $template == *"$pattern"* ]]; then
  if [[ -z "$scripts" ]]; then
    template=$(<<< "$template" sed "/$pattern/,+1 d" 2>/dev/null)
  else
    out="## \`Scripts\`\n\n"
    out+="Here is a list of scripts in this repository:\n\n"
    out+="Script|Description\n"
    out+=":---|:---\n"
    for script in $scripts; do
        comments=$(head -n4 "$script") \
          || die "failed to read description for $script"
        count=0; desc="";
        while read -r line; do
          if [[ "$count" -gt 0 ]]; then
            [[ "$line" == "" ]] && { break; }                   # break as soon as there is an empty line.
            [[ "$line" == *"# SKIP"* ]] && { desc=""; break; }  # break as soon as a skip is found.
            [[ "${line:0:1}" != "#" ]] && { continue; }
            [[ "$line" == *"NOTE:"* || "$line" == *"PLEASE NOTE:"* ]] && { continue; }
            [[ "$line" == "#" ]] && { continue; }
            [[ "$desc" != "" ]] && { desc+=" "; }
            desc+="${line/\#\ /}"
          fi
          (( count++ ))
        done <<< "$comments"
        script="${script//\.\//}"
        out+="[$script]($script) | ${desc^}\n"
    done
    pattern="${pattern//\%/\\\%}"
    template="${template//$pattern/$out}"
  fi
fi

# add 'how to use template', if repo is a template repo.
pattern="%HOW_TO_USE_TEMPLATE%"; out="";
if [[ $template == *"$pattern"* ]]; then
  read -r -d '' out <<EOF
## 🧠 How do I use this template?

1. Using a <kbd>terminal</kbd>, download the child repository locally.

2. From the root of that child repository, run:
\`\`\`bash
git remote add template https://github.com/$repo.git
git fetch template
git merge template/main --allow-unrelated-histories
# then fix any merge conflicts as required & 'git push' when ready.
\`\`\`
EOF
  pattern="${pattern//\%/\\\%}"
  if [[ $repo != *"-template"* ]]; then
    template=$(<<< "$template" sed "/$pattern/,+1 d")
  else
    template="${template//$pattern/$out}"
  fi
fi

# update README.md with changes.
out="README.md"
echo "##[group]Updating $out"
echo -e "$template" > "$out" \
  || die "failed to update $out"
echo "##[endgroup]"
