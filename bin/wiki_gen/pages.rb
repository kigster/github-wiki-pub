# frozen_string_literal: true

#
# bin/wiki_gen/pages.rb — the page hierarchy and renderers for bin/wiki-gen.
#
# `SECTIONS` is the wiki's information architecture. Each section is one page
# and claims documents by path or glob; every claimed document becomes a child
# page lifted whole from its source. A section claims a document only if no
# earlier section did, so order is priority. Adding a file under a globbed
# directory needs no change here.
#
# Everything a renderer emits must be traceable: lifted from a document,
# scanned out of the tree, or a short orientation sentence that only restates
# what the linked sources say. Where sources disagree, say so on the
# Documentation Drift page rather than picking a winner.
#

module WikiGen
  class Generator
    # Directories never lifted from: history, dependencies, build output.
    EXCLUDE = %r{(\A|/)(node_modules|target|archive|\.git)/}

    # Title overrides for documents whose own H1 is ambiguous out of context.
    # `%s` is replaced by the document's H1.
    TITLES = {
      'README.md' => 'Github Wiki Publisher',
      'CLAUDE.md' => 'Working in this Repository',
      '.plans/BACKLOG.md' => 'Plans Backlog',
      '.plans/{0-9}*/*.md' => 'Plan: %s'
    }.freeze

    SECTIONS = [
      { title: 'Github Wiki Publisher',
        purpose: 'What Github Wiki Publisher is, how the repository is laid out, and the rules for working in it.',
        render: :overview_body,
        docs: %w[README.md CLAUDE.md] },
      { title: 'Backlog',
        purpose: 'Decided work that is not built yet.',
        source: '.plans/BACKLOG.md', },
      {
        title: 'Plan: %s',
        purpose: 'Feature request history and current status.',
        source: '.plans/{0-9}*/*.md',
        docs: %w[.plans/{0-9}*/*.md]
      }
    ].freeze

    def build_pages
      @claimed = {}
      @used_titles = Set.new(SECTIONS.map { |s| s[:title] } + ['Home', 'Documentation Drift', 'Other Documents'])
      SECTIONS.each { |sec| build_section(sec) }
      build_other_documents
      drift = page('Documentation Drift', purpose: DRIFT_PURPOSE) { '' }
      page_home
      page_sidebar
      page_footer
      resolve_lifts
      drift.body = drift_body
      drift.sources = sources('README.md', 'CLAUDE.md')
    end

    # ── sections ────────────────────────────────────────────────────────────

    def build_section(sec)
      own = sec[:source] && claim([sec[:source]]).first
      docs = claim(Array(sec[:docs]))
      titles = docs.to_h { |path| [path, doc_title(path)] }

      body = +''
      body << send(sec[:render]) if sec[:render]
      body << "#{lift_document(own)}\n\n<sub>Lifted verbatim from #{src(own)}.</sub>\n" if own
      body << children_table(docs, titles) unless docs.empty?
      page(sec[:title], purpose: sec[:purpose], source: own, sources: sources(own, *docs)) { body }

      docs.each { |path| doc_page(path, titles[path], parent: sec[:title]) }
    end

    # Every current document under docs/ that no section claimed. It still
    # gets a page, so nothing is dropped, and Documentation Drift names it.
    def build_other_documents
      @unclaimed = current_docs.reject { |p| @claimed.key?(repo.canonical(p)) }
      return if @unclaimed.empty?

      docs = claim(@unclaimed)
      titles = docs.to_h { |path| [path, doc_title(path)] }
      page('Other Documents',
           purpose: 'Documents under docs/ that no section of this wiki claims yet.',
           sources: sources(*docs)) do
        "These documents are current but have no home in `SECTIONS` in #{src('bin/wiki_gen/pages.rb')}. " \
          "Add a path or glob to the section they belong to.\n\n#{children_table(docs, titles)}"
      end
      docs.each { |path| doc_page(path, titles[path], parent: 'Other Documents') }
    end

    # Current documentation: docs/**, minus the archives and any superseded
    # language revision (only the one `docs/language/current` points at counts).
    def current_docs
      current = repo.canonical('docs/language/current')
      repo.glob('docs/**/*.md').reject do |p|
        p.match?(EXCLUDE) ||
          (p.start_with?('docs/language/v') && !repo.canonical(p).start_with?("#{current}/"))
      end
    end

    # Expand +patterns+ to files not yet claimed by an earlier section,
    # de-duplicated through symlinks, in pattern order.
    def claim(patterns)
      patterns.flat_map { |pat| pat.match?(/[*?\[{]/) ? repo.glob(pat) : [pat] }
              .select { |p| repo.file?(p) && !p.match?(EXCLUDE) }
              .each_with_object([]) do |p, out|
                key = repo.canonical(p)
                next if @claimed.key?(key)

                @claimed[key] = p
                out << p
              end
    end

    def doc_title(path)
      h1 = doc(path).title || File.basename(path, '.md').tr('-_', '  ').capitalize
      title = TITLES[path] ? TITLES[path].sub('%s', h1) : h1
      title = title.delete('`')
      title = "#{title} (#{File.dirname(path)})" if @used_titles.include?(title)
      @used_titles << title
      title
    end

    def doc_page(path, title, parent:)
      fm = doc(path).front_matter
      purpose = fm['note'] && Text.first_sentence(fm['note'], limit: 400, floor: 400).gsub('\\|', '|')
      page(title, parent: parent, purpose: purpose, source: path, sources: [src(path)]) do
        "#{lift_document(path)}\n\n<sub>Lifted verbatim from #{src(path)}.</sub>\n"
      end
    end

    def children_table(docs, titles)
      rows = docs.map { |p| [link(titles[p]), summary(p), src(p, label: p)] }
      "\n## Pages in this section\n\n#{table(['Page', 'What it covers', 'Source'], rows)}"
    end

    # One line describing a document: its front-matter `note`, else its first
    # prose paragraph.
    def summary(path)
      d = doc(path)
      note = d.front_matter['note']
      return Text.first_sentence(note, limit: 200) if note

      para = d.body_without_title.split(/\n\s*\n/).find do |chunk|
        s = chunk.strip
        !s.empty? && !s.start_with?('#', '|', '```', '<', '[!', '![', '>', '---', '- ', '* ', '1.') &&
          !s.match?(/\A\[!\[/)
      end
      Text.first_sentence(para.to_s.gsub(/\[([^\]]+)\]\([^)]*\)/, '\1'), limit: 200)
    end

    # ── section bodies ──────────────────────────────────────────────────────

    def overview_body
      "Github Wiki Publisher turns a GitHub markdown wiki into one readable HTML document. " \
        "How the repository is laid out, and the rules for working in it, are the pages in this section, " \
        "lifted from #{src('README.md')} and #{src('CLAUDE.md')}.\n"
    end

    # ────────────────────────────────────────────────────────────────────────
    # Home, sidebar, footer
    # ────────────────────────────────────────────────────────────────────────

    def page_home
      top = SECTIONS.map { |s| s[:title] }
      top << 'Other Documents' if @pages.any? { |p| p.title == 'Other Documents' }
      top << 'Documentation Drift'
      body = +''
      body << "This wiki is generated from the repository. Every page names the files it was derived " \
              "from; if a page looks wrong, the fix belongs in the source file, not here.\n\n"
      body << "## Start here\n\n"
      body << table(['Section', 'What is in it'],
                    top.map { |t| [link(t), @pages.find { |p| p.title == t }&.purpose.to_s] })
      body << "\n## Regenerating this wiki\n\n"
      body << "```bash\nbin/wiki-gen           # rewrite wiki/\nbin/wiki-gen --check   # fail if wiki/ is stale\n```\n"

      page('Home', sources: sources('README.md', 'CLAUDE.md')) { body }
    end

    def page_sidebar
      lines = "#{MARKER}\n\n### Github Wiki Publisher\n\n- #{link('Home')}\n"
      tops = @pages.reject(&:parent).reject { |p| %w[Home _Sidebar _Footer].include?(p.title) }
      tops.each do |p|
        lines << "- #{link(p.title)}\n"
        @pages.select { |c| c.parent == p.title }.each { |c| lines << "  - [#{c.title}](#{page_href(c, nil)})\n" }
      end
      @pages << Page.new(title: '_Sidebar', slug: '_Sidebar', body: lines, sources: [])
    end

    def page_footer
      body = "#{MARKER}\n\nGenerated by `wiki-gen` on #{Date.today.iso8601}. Do not edit wiki pages by hand.\n"
      @pages << Page.new(title: '_Footer', slug: '_Footer', body: body, sources: [])
    end

    # ────────────────────────────────────────────────────────────────────────
    # Documentation drift
    # ────────────────────────────────────────────────────────────────────────

    DRIFT_PURPOSE = 'Places where a document names something the tree does not hold. Recorded, not resolved.'

    # Built after every lift is resolved, because broken links are only known
    # once the links have been rewritten.
    def drift_body
      body = +"Every check below is mechanical and re-runs on each generation. Fix the source file " \
              "and the entry disappears.\n\n"

      body << "## Links to files not in the tree\n\n"
      rows = @broken_links.uniq.sort.map { |from, href| [src(from), "`#{href}`"] }
      body << table(['Document', 'Link'], rows)

      body << "\n## Documents with no section\n\n"
      body << if @unclaimed.empty?
                "_None — every current document under `docs/` has a home._\n"
              else
                ["Listed under #{link('Other Documents')} until a section in `SECTIONS`",
                 "claims them:\n\n#{@unclaimed.map { |p| "- #{src(p)}" }.join("\n")} + \n"].join
              end
      body
    end
  end
end
