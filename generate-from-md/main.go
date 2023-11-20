package main

import (
	"html"
	"io"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/gomarkdown/markdown"
	"github.com/gomarkdown/markdown/ast"
	mhtml "github.com/gomarkdown/markdown/html"
)

// an actual rendering of Paragraph is more complicated
func renderCodeBlock(w io.Writer, block *ast.CodeBlock, entering bool) {
	io.WriteString(w, `<div class="code-sample">`)

	lines := strings.Split(string(block.Literal), "\n")
	for _, line := range lines {
		io.WriteString(w, "<pre>"+html.EscapeString(line)+"</pre>")
	}
	io.WriteString(w, "</div>")
}

func codeRenderHook(w io.Writer, node ast.Node, entering bool) (ast.WalkStatus, bool) {
	if block, ok := node.(*ast.CodeBlock); ok {
		renderCodeBlock(w, block, entering)
		return ast.GoToNext, true
	}

	return ast.GoToNext, false
}

func main() {
	opts := mhtml.RendererOptions{
		Flags:          mhtml.CommonFlags,
		RenderNodeHook: codeRenderHook,
	}
	renderer := mhtml.NewRenderer(opts)

	md, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}

	os.Stdout.Write(markdown.ToHTML(md, nil, renderer))
}
