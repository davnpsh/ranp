#!/usr/bin/env bash
# 
# Send to a physical printer a random xkcd.
# https://github.com/davnpsh/ranp
# 
# Author: daru <me@davnpsh.dev>
# Date: January 10, 2026
# License: MIT

SPINNER_PID=
FONT="Noto Sans"
DEPENDENCIES=(curl jq xelatex pandoc lp)
XKCD_NUMBER=
XKCD_TITLE=
XKCD_IMG_URL=
XKCD_URL=
IMG_PATH=
MD_PATH=
PDF_PATH=

set -euo pipefail

check_deps()
{
    for cmd in "${DEPENDENCIES[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || {
            echo "$cmd is required" >&2
            exit 1
        }
    done
}

usage()
{
	cat <<-EOF
	Usage: $(basename "$0") [options]
    
	Send to a physical printer a random xkcd.
    
	Options
	  -h          print this message and exit
	EOF
}

cleanup()
{
	if [[ -n $SPINNER_PID ]]; then
		kill "$SPINNER_PID"
	fi
}

log()
{
	local chars c
	
	chars=('\' '|' '/' '-')
	
	while true; do
		for c in "${chars[@]}"; do
			printf ' [%s] \r' "$c"
			sleep .2
		done
	done
}

pick_random()
{
    local latest comic_json
    
    echo "Picking random xkcd..."
    
    latest=$(curl -s https://xkcd.com/info.0.json | jq -r '.num')
    XKCD_NUMBER=$((RANDOM % latest + 1))
    comic_json=$(curl -s "https://xkcd.com/${XKCD_NUMBER}/info.0.json")
    
    XKCD_TITLE=$(echo "$comic_json" | jq -r '.safe_title')
    XKCD_IMG_URL=$(echo "$comic_json" | jq -r '.img')
    XKCD_URL="https://xkcd.com/$XKCD_NUMBER/"
}

generate_document()
{
    local original_filename new_filename
    
    echo "Generating printable document..."
    
    original_filename=$(basename -- "$XKCD_IMG_URL")
    new_filename="xkcd-$XKCD_NUMBER"
    
    IMG_PATH="/tmp/$new_filename.${original_filename##*.}"
    MD_PATH="/tmp/$new_filename.md"
    PDF_PATH="/tmp/$new_filename.pdf"
    
    curl -s -L -o "$IMG_PATH" "$XKCD_IMG_URL"
    
    cat > "$MD_PATH" <<-EOF
	# $XKCD_TITLE
    
	![]($IMG_PATH)
    
	$XKCD_URL
	EOF
	
	echo "\pagenumbering{gobble}" > /tmp/no-page-number.tex

    pandoc "$MD_PATH" -o "$PDF_PATH" --pdf-engine=xelatex -V mainfont="$FONT" -H /tmp/no-page-number.tex
}

print()
{
    echo "Sending to printer..."
    
    lp "$PDF_PATH" > /dev/null
}

main()
{
	local opt
	while getopts 'dht:' opt; do
		case "$opt" in
			h) usage; return 0;;
			*) usage >&2; return 1;;
		esac
	done
	
	trap cleanup EXIT
	
	log &
	SPINNER_PID=$!
	
	check_deps
	pick_random
	generate_document
	print
	
	echo "Done!"
}

main "$@"