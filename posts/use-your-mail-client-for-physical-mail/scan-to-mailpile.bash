#!/bin/bash

if ! [[ $# -ge 1 ]]; then
    echo 'Usage: scan-to-mailpile ...FILES' >&2

    exit
fi

if ! type_output="$(type readlink mktemp pdftotext tesseract mail mimetype basename cat 2>&1)"; then
    printf 'scan-to-mailpile: Some required commands are missing, lookup results:\n%s\n' \
           "$type_output" >&2
    exit 1
fi

tmpdir=$(mktemp -d) || exit $?

printf -v trap 'rm -vr %q' "$tmpdir"
trap "$trap" EXIT

printf 'Changing directory: '
pushd "$tmpdir" || exit $?

declare -a file_args=()

{
    for file in "$@"; do
        file="$(readlink -f "$file")" || exit $?

        # Note: pdftotext will not work for scanned documents, so those should just be
        # saved as image files before feeding them to this script.
        ##
        # It will however work fine for other types of PDFs.
        if [[ "$file" == *.pdf ]]; then
            pdftotext "$file" /dev/fd/1 || exit $?
        else
            tesseract "$file" stdout  || exit $?
        fi

        mime="$(mimetype -b "$file")" || exit $?

        attachment_args+=(--content-type="$mime" --attach="$file")
    done
} > ./outfile.txt

cat ./outfile.txt

file1="$(basename "$1")"

read -i "${file1%.*}" -rep 'What should the subject of the email be? ' subject

mail --subject="$subject" \
     "${attachment_args[@]}" \
     --content-type="text/plain" \
     --content-filename="content.txt" \
     user@example.com < ./outfile.txt

popd
