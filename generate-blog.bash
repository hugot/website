#!/bin/bash
##
# Generate html page with blog article excerpts from ./posts.txt.  Post file names should
# be added to ./posts.txt in the exact order that they are supposed to appear on the blog
# page.

# Check if required executables can be found
if ! type readlink dirname html2text mv cat cksum base64 pup; then
    echo 'One or more required executables are not present. Generation cancelled' >&2
    echo 'Note: You can install pup with "go get github.com/ericchiang/pup"' >&2
    exit 1
fi

# Determine script directory (requires GNU readlink)
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

printf 'Changing directory: '
pushd "$here" || exit  $?

posts_file="$here/publish.txt"

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
        <link rel="stylesheet" type="text/css" href="style.css">
        <meta charset="UTF-8">
    </head>

    <style type="text/css">
     h2 a {
         color: #5b4636;
         text-decoration: none;
     }

     h2 a:visited {
         color: #5b4636;
         text-decoration: none;
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

rfc-822-date-time() {
    LC_ALL=C date "$@" --rfc-email
}

print-post-html-top() {
    declare title="$1"

    cat <<EOF
<!DOCTYPE HTML>
<html>
 <head>
  <title>${title}</title>
  <link rel="stylesheet" type="text/css" href="../../style.css">
  <meta charset="UTF-8">
 </head>
 <body>
  <div style="display: flex; flex-direction: horizontal;">
   <a href="../../blog.html">Blog</a>
   <span style="margin-left: 1em; margin-right: 1em;">|</span>
   <a href="../../feed.xml">RSS Feed</a>
  </div>
    <article>
EOF
}

print-post-html-bottom() {
    declare publish_date="$1" last_edit_date="$2"

    cat <<EOF
    <span class="publish-date">
     <i>First published: ${publish_date}</i><br>
     <i>Last edited: ${last_edit_date}</i>
    </span>
  </article>
 </body>
</html>
EOF
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
      <pubDate>$(rfc-822-date-time)</pubDate>
      <lastBuildDate>$(rfc-822-date-time)</lastBuildDate>
      <docs>http://blogs.law.harvard.edu/tech/rss</docs>
      <generator>Hugo's Custom Bash Script</generator>
      <managingEditor>social@hugot.nl (Hugot)</managingEditor>
      <webMaster>infra@hugot.nl (Hugot Infra)</webMaster>
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

publish-html() {
    declare source_dir="$1" publish_dir="$2" contents="$3"

    declare pubdate_file="$source_dir/publish_date.txt" \
            checksum_file="$source_dir/last_checksum.txt" \
            last_edit_file="$source_dir/last_edit_date.txt" \
            current_checksum=''

    current_checksum="$(cksum <<<"$contents")"
    declare checksum=''

    # Determine a publishing date for the post
    if [[ -f "$pubdate_file" ]]; then
        read -r pubdate < "$pubdate_file"
    else
        pubdate="$(date)"
        echo "$pubdate" > "$pubdate_file"
    fi

    if [[ -f "$checksum_file" ]]; then
        read -r checksum  < "$checksum_file"
    else
        echo "$current_checksum" > "$checksum_file"
        checksum="$current_checksum"
    fi

    if [[ -f "$last_edit_file" ]]; then
        read -r last_edit_date < "$last_edit_file"
    fi

    if [[ "$checksum" != "$current_checksum" ]]; then
        last_edit_date="$(date)"

        echo "$last_edit_date" > "$last_edit_file"
        echo "$current_checksum" > "$checksum_file"
    fi

    declare pubdate='' last_edit_date=''
    # Convert publishing date to be conform RFC 822
    pubdate="$(rfc-822-date-time --date="$pubdate")" || return $?
    last_edit_date="$(rfc-822-date-time --date="$last_edit_date")" || return $?

    declare index_file="$publish_dir/index.html"
    if [[ "$checksum" != "$current_checksum" ]] || ! [[ -f "$index_file" ]]; then
        printf 'Publishing to %s\n' "$index_file" >&2
        mkdir -p "$publish_dir" || return $?

        print-post-html-top "$title" > "$index_file"
        printf '%s\n' "$contents" >> "$index_file"
        print-post-html-bottom "$pubdate" "$last_edit_date" >> "$index_file"
    fi
}

publish_dir="$here/publish"

site_url="https://hugot.nl"

blog_html="$publish_dir/blog.html"
new_html="$blog_html.new"

blog_rss="$publish_dir/feed.xml"
new_rss="$blog_rss.new"

mkdir -p "$publish_dir" || exit $?

print-blog-html-top > "$new_html"
print-blog-rss-top > "$new_rss"

while read -r post_html_path; do
    # Convert the post's html to text to make it easier to use the blog's text
    text="$(html-to-text "$post_html_path" | escape-html)" || exit $?

    # The title should be on the 2nd line of text, right after the link to the
    # homepage. This is a bit inflexible but it will do for now.
    title="$(head -n 1 <<<"$text" | tr -d '*')" || exit $?

    # Use the first 5 lines after the title as post excerpt.
    excerpt="$(tail -n +2 <<<"$text" | head -n 5)" || exit $?

    # Escape just the article element for use in the RSS feed article description.
    # This way the entire article can be read from an RSS reader.
    article_html="$({ head -n -1 | tail -n +2 | escape-html; } < "$post_html_path")"

    # Escape the post html file name to safely use it in the generated html.
    href="$(escape-html <<<"$post_html_path")" || exit $?

    post_dir="$(dirname "$post_html_path")" || exit $?
    post_publish_dir="$publish_dir/posts/$(basename "$post_dir")" || exit $?
    read -rd '' post_html < "$post_html_path" || true

    publish-html "$post_dir" "$post_publish_dir" "$post_html"

    {
        el div
        printf '<h2 style="margin-bottom: 0.1em;"><a href="%s">%s</a></h2>' "$href" "$title"
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
        el-enclose description "$article_html"
        el-enclose pubDate "$pubdate"

        echo "<guid isPermaLink=\"false\">$title$(base64 <<<"$checksum")</guid>"

        el-close item
    } >> "$new_rss"
done < "$posts_file"

print-blog-html-bottom >> "$new_html"
print-blog-rss-bottom >> "$new_rss"

mv -v "$new_html" "$blog_html" || exit $?
mv -v "$new_rss" "$blog_rss" || exit $?

cp -v "$here/style.css" "$publish_dir/style.css"
cp -v "$here/index.html" "$publish_dir/index.html"

cp -rv "$here/assets" "$publish_dir/assets"

echo 'SUCCESS!'
