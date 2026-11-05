#!/usr/bin/env bash

set -uo pipefail

for pdf in *.pdf; do
	suffix="${pdf##*.}"
	filename="${pdf%.*}.txt"
	pdftotext "$pdf" "$filename"
done

