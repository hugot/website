#!/bin/bash
##
# Generate html page with blog article excerpts from ./posts.txt.  Post file names should
# be added to ./posts.txt in the exact order that they are supposed to appear on the blog
# page.

# Check if required executables can be found
if ! output="$(type readlink dirname html2text mv cat cksum base64 pup 2>&1)"; then
    echo 'One or more required executables are not present. Generation cancelled' >&2
    echo "'type' output: $output" >&2
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

link-back-to-root() {
    declare root="$1" directory="$2"

    directory="${directory#$root}"
    directory="${directory%/}"

    declare link=''
    while read -rd '/' slug; do
        link="${link}../"
    done <<<"$directory"

    echo "$link"
}


escape-html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

html-to-text() {
    html2text -nobs -style compact "$@"
}

timestamp() {
    date +'%s'
}

rfc-822-date-time() {
    LC_ALL=C date "$@" --rfc-email
}

print-html-top() {
    declare title="$1" root="$2" directory="$3"

    declare backlink=''
    backlink="$(link-back-to-root "$root" "$directory")" || return $?

    cat <<EOF
<!DOCTYPE HTML>
<html>
 <head>
  <title>${title}</title>
  <link rel="stylesheet" type="text/css" href="${backlink}style.css">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
 </head>
 <body>
  <nav>
   <div class="navitem"><a href="${backlink}index.html">Home</a></div>
   <div class="navitem"><a href="${backlink}blog.html">Blog</a></div>
   <div class="navitem"><a href="${backlink}feed.xml">RSS Feed</a></div>
  </nav>
   <main>
    <article>
EOF
}

print-html-bottom() {
    echo '</main>
   </article>
  </body>
</html>'
}


print-post-html-bottom() {
    declare publish_date="$1" last_edit_date="$2"

    cat <<EOF
    <section class="publish-date">
     <i>First published: ${publish_date}</i><br>
     <i>Last edited: ${last_edit_date}</i>
    </section>
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
    declare root="$1" source_dir="$2" publish_dir="$3" contents="$4" title="$5"

    declare pubdate_file="$source_dir/publish_date.txt" \
            checksum_file="$source_dir/last_checksum.txt" \
            last_edit_file="$source_dir/last_edit_date.txt" \
            current_checksum=''

    current_checksum="$(cksum <<<"$contents")"
    declare checksum='' pubdate='' last_edit_date=''

    # Determine a publishing date for the post
    if [[ -f "$pubdate_file" ]]; then
        read -r pubdate < "$pubdate_file"
    else
        pubdate="$(timestamp)"
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
        last_edit_date="$(timestamp)"

        echo "$last_edit_date" > "$last_edit_file"
        echo "$current_checksum" > "$checksum_file"
    fi

    if [[ -z $last_edit_date ]]; then
        last_edit_date="$pubdate"
    fi

    # Convert publishing date to be conform RFC 822
    pubdate="$(rfc-822-date-time --date="@$pubdate")" || return $?
    last_edit_date="$(rfc-822-date-time --date="@$last_edit_date")" || return $?

    declare index_file="$publish_dir/index.html"
    if [[ "$checksum" != "$current_checksum" ]] || ! [[ -f "$index_file" ]]; then
        printf 'Publishing to %s\n' "$index_file" >&2
        mkdir -p "$publish_dir" || return $?

        print-html-top "$title" "$root" "$publish_dir" > "$index_file"
        printf '%s\n' "$contents" >> "$index_file"
        print-post-html-bottom "$pubdate" "$last_edit_date" >> "$index_file"
    fi

    if [[ -d "$source_dir/assets" ]]; then
        cp -rv "$source_dir/assets" "$publish_dir/"
    fi
}

publish_dir="$here/publish"

site_url="https://hugot.nl"

blog_html="$publish_dir/blog.html"
new_html="$blog_html.new"

blog_rss="$publish_dir/feed.xml"
new_rss="$blog_rss.new"

mkdir -p "$publish_dir" || exit $?

print-html-top 'Blog' "$publish_dir" "$publish_dir" > "$new_html"
print-blog-rss-top > "$new_rss"

while read -r post_html_path; do
    # Convert the post's html to text to make it easier to use the blog's text
    text="$(html-to-text "$post_html_path" | escape-html)" || exit $?

    # The title should be on the 2nd line of text, right after the link to the
    # homepage. This is a bit inflexible but it will do for now.
    title="$(head -n 1 <<<"$text" | tr -d '*')" || exit $?

    # Use the first 5 lines after the title as post excerpt.
    excerpt="$(tail -n +2 <<<"$text" | head -n 5)" || exit $?

    read -rd '' post_html < "$post_html_path" || true
    # Escape just the article element for use in the RSS feed article description.
    # This way the entire article can be read from an RSS reader.
    article_html="$(escape-html <<<"$post_html")"

    # Escape the post html file name to safely use it in the generated html.
    href="$(escape-html <<<"$post_html_path")" || exit $?

    post_dir="$(dirname "$post_html_path")" || exit $?
    post_publish_dir="$publish_dir/posts/$(basename "$post_dir")" || exit $?

    publish-html "$publish_dir" "$post_dir" "$post_publish_dir" "$post_html" "$title" || exit $?

    {
        el 'div class="blog-feed-item"'
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

print-html-bottom >> "$new_html"
print-blog-rss-bottom >> "$new_rss"

mv -v "$new_html" "$blog_html" || exit $?
mv -v "$new_rss" "$blog_rss" || exit $?

cp -v "$here/style.css" "$publish_dir/style.css" || exit $?

read -rd '' index_html < "$here/index/index.html" || true
publish-html "$publish_dir" "$here/index" "$publish_dir" "$index_html" "Hugo's Homepage"

for project_dir in "$here/projects"/*; do
    project_name="$(basename "$project_dir")" || exit $?

    text="$(html-to-text "$project_dir/index.html" | escape-html)" || exit $?
    title="$(head -n 1 <<<"$text" | tr -d '*')" || exit $?

    read -rd '' project_html < "$project_dir/index.html" || true

    publish-html "$publish_dir" \
                 "$project_dir" \
                 "$publish_dir/projects/$project_name" \
                 "$project_html" \
                 "$title"
done

publish-html "$publish_dir" \
             "$here/curriculum-vitae" \
             "$publish_dir/curriculum-vitae" \
             "$(cat "$here/curriculum-vitae/index.html")" \
             'Curriculum Vitae'

cp -rv "$here/assets" "$publish_dir/assets" || exit $?

echo 'SUCCESS!'
