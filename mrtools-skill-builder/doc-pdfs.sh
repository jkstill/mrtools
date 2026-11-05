#!/usr/bin/env bash

set -uo pipefail

doclinks=(
https://method-r.com/software/workbench/man/mrkey.pdf
https://method-r.com/software/workbench/man/mrskew.pdf
https://method-r.com/software/workbench/man/mrwhen.pdf
https://method-r.com/software/workbench/man/mr1011.pdf
https://method-r.com/software/workbench/man/mrcrop.pdf
https://method-r.com/software/workbench/man/mrcrop-datetime.pdf
https://method-r.com/software/workbench/man/mrcrop-experience.pdf
https://method-r.com/software/workbench/man/mrcrop-island.pdf
https://method-r.com/software/workbench/man/mrcrop-linerange.pdf
https://method-r.com/software/workbench/man/mrcrop-sqlid.pdf
https://method-r.com/software/workbench/man/mrcrop-transaction.pdf
)

for doclink in ${doclinks[@]}; do
	filename=${doclink##*/}
	curl $doclink -o $filename
done

