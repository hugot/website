#!/bin/bash
##
# Generate html page with blog article excerpts from ./posts.txt.  Post file names should
# be added to ./posts.txt in the exact order that they are supposed to appear on the blog
# page.

# Check if required executables can be found
if ! type readlink dirname html2text mv; then
    echo 'One or more required executables are not present. Generation cancelled' >&2
    exit 1
fi

# Determine script directory (requires GNU readlink)
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

printf 'Changing directory: '
pushd "$here" || exit  $?

posts_file="$here/posts.txt"

if ! [[ -f "$posts_file" ]]; then
    printf 'Posts file "%s" not found. Generation cancelled.\n' "$posts_file" >&2
    exit 1
fi

escape-html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

html-to-text() {
    html2text -nobs -style compact "$@"
}

blog_html="$here/blog.html"

{
    echo '<html>
    <head>
        <title>Blog</title>
        <meta charset="UTF-8">
    </head>

    <style type="text/css">
     html {
         font-family: Helvetica, Arial, sans-serif;
         color: #5b4636;
         background-color: #f4ecd8;
     }

     body {
         padding: 1em;
         margin: auto;
     }

     @media only all and (pointer: coarse), (pointer: none) {
         body {
             font-size: 5.5vmin;
         }
     }

     @media only all and (pointer: fine) {
         body {
             font-size: calc(16px + 0.6vmin);
             min-width: 500px;
             max-width: 50em;
         }
     }
    </style>

    <body>
        <a href="index.html">Home</a>
        <h1>Blog</h1>
'
    while read -r post_html; do
        # Convert the post's html to text to make it easier to use the blog's text
        text="$(html-to-text "$post_html" | escape-html)" || exit $?

        # The title should be on the 2nd line of text, right after the link to the
        # homepage. This is a bit inflexible but it will do for now.
        title="$(tail -n +2 <<<"$text" | head -n 1 | tr -d '*')" || exit $?

        # Use the first 5 lines after the title as post excerpt.
        excerpt="$(tail -n +3 <<<"$text" | head -n 5)" || exit $?

        # Escape the post html file name to safely use it in the generated html.
        href="$(escape-html <<<"$post_html")" || exit $?

        printf '<div><a href="%s"><h2>%s</h2></a><p>%s ... <a href="%s">Continue reading</a></p></div><hr>\n' \
               "$href" \
               "$title" \
               "$excerpt" \
               "$href"
    done < "$posts_file"

    echo '    </body>
</html>'

} > "$blog_html.new"

mv -v "$blog_html.new" "$blog_html" || exit $?

echo 'SUCCESS!'
