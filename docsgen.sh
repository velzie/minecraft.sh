#!/bin/bash
{

  cat<<EOF
# Documentation
  

# List of methods and hooks
auto-generated from comments by ./docsgen.sh
EOF

while read line; do
  if [[ "$line" =~ \#\#\# ]]; then
    desc="${line:4}${IFS}"
    while read line && [[ "$line" =~ \#\#\# ]]; do
      desc+="${line:4}${IFS}"
    done

    example=""
    while true; do
      if [[ "$line" =~ ^[^#]*\(\) ]]; then
        arguments=$toadd
        command=$BASH_REMATCH
        break
      else
        example+="$toadd$IFS"
        toadd=${line:2}
      fi
      read line
    done
    echo "## $command"
    echo -n "$desc"
    if [ ! -z "$arguments" ]; then
        echo "### arguments"
        echo "\`$arguments\`"
    fi
    if [ ! -z "$example" ]; then
      example=${example//\$0/${command/\(\)/}}
      echo "### example"
      echo -n "\`\`\`"
      echo -n "$example"
      echo "\`\`\`"
    fi
    arguments=""
    toadd=""
    echo
  fi
done<<<$(cat src/*.sh)

}>docs.md
