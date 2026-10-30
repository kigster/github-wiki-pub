# frozen_string_literal: true

# A miniature wiki export with one of everything the cleaner rewrites.
module WikiHtml
  DOCUMENT = <<~HTML
    <html>
    <head>
    <title>Wiki</title>
    </head>
    <body class="html-doc">
    <p class="page" id="Home"></p><h1>Home</h1>
    <!-- generated-by: bin/wiki-gen -->
    <h1 id="home">Home</h1>
    <blockquote>
    <p>[!NOTE]
    <strong>Generated page</strong> — do not edit.</p>
    </blockquote>
    <blockquote>
    <p>[!CAUTION]
    Mind the gap.</p>
    </blockquote>
    <blockquote>
    <p>An ordinary quote.</p>
    </blockquote>
    <pre class="hljs"><span class="hljs-symbol">flowchart</span> LR
        A --&gt; B</pre>
    <pre class="hljs">---
    config:
      theme: 'base'
    title: Deploy
    ---
    flowchart TD
        X --&gt; Y</pre>
    <pre class="hljs">---
    name: skill-name
    ---</pre>
    <pre class="hljs">puts "hello"</pre>
    </body>
    </html>
  HTML
end
