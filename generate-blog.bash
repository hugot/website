#!/bin/bash
##
# Generate html page with blog article excerpts from ./posts.txt.  Post file names should
# be added to ./posts.txt in the exact order that they are supposed to appear on the blog
# page.

# Check if required executables can be found
if ! type readlink dirname html2text mv cat cksum base64; then
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

print-blog-html-top() {
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
        <div style="display: flex; flex-direction: horizontal;">
            <a href="index.html">Home</a>
            <span style="margin-left: 1em; margin-right: 1em;">|</span>
            <a href="feed.xml">RSS Feed</a>
        </div>
        <h1>Blog</h1>
'
}

print-blog-html-bottom() {
    echo '    </body>
    </html>'
}

# Note: pubDate and lastBuildDate are both set to the current time.
print-blog-rss-top() {
    cat <<EOF
<?xml version="1.0"?>
<rss version="2.0">
   <channel>
      <title>Hugot Blog</title>
      <link>https://hugot.nl/blog.html</link>
      <description>Hugo's personal blog</description>
      <language>en-us</language>
      <pubDate>$(date)</pubDate>
      <lastBuildDate>$(date)</lastBuildDate>
      <docs>http://blogs.law.harvard.edu/tech/rss</docs>
      <generator>Hugo's Custom Bash Script</generator>
      <managingEditor>social@hugot.nl</managingEditor>
      <webMaster>infra@hugot.nl</webMaster>
EOF
}

print-blog-rss-bottom() {
    echo '</channel>
</rss>'
}

el() {
    format_string="$1"
    shift

    printf "<$format_string>" "$@"
}

el-close() {
    echo "</$1>"
}

el-enclose() {
    element_name="$1"
    shift

    printf '%s' "<$element_name>"
    printf '%s' "$@"
    printf '%s' "</$element_name>"
}

site_url="https://hugot.nl"

blog_html="$here/blog.html"
new_html="$blog_html.new"

blog_rss="$here/feed.xml"
new_rss="$blog_rss.new"

print-blog-html-top > "$new_html"
print-blog-rss-top > "$new_rss"

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

    post_dir="$(dirname "$post_html")" || exit $?
    pubdate_file="$post_dir/publish_date.txt"

    # Determine a publishing date for the post
    if [[ -f "$pubdate_file" ]]; then
        read -r pubdate < "$pubdate_file"
    else
        pubdate="$(date)"
        echo "$pubdate" > "$pubdate_file"
    fi

    {
        el div

        el 'a href="%s"' "$href"
        printf '<h2 style="margin-bottom: 0.1em;">%s</h2>' "$title"
        el-close a

        printf '<i style="font-size: 0.8em;">%s</i>' "$pubdate"

        el 'p style="margin-top: 0.5em;"'
        printf '%s ... <a href="%s">Continue reading</a>' "$excerpt" "$href"
        el-close p

        el-close div

        el hr
    } >> "$new_html"

    {
        el item
        el-enclose title "$title"
        el-enclose link "$site_url/$href"
        el-enclose description "$excerpt"
        el-enclose pubDate "$pubdate"

        echo "<guid isPermaLink=\"false\">$title$(base64 <(cksum <<<"$text"))</guid>"

        el-close item
    } >> "$new_rss"
done < "$posts_file"

print-blog-html-bottom >> "$new_html"
print-blog-rss-bottom >> "$new_rss"

mv -v "$new_html" "$blog_html" || exit $?
mv -v "$new_rss" "$blog_rss" || exit $?

echo 'SUCCESS!'
