module MacNotif
  class ChangelogGenerator < Jekyll::Generator
    def generate(site)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "changelog", "index.md")
      changelog = File.read(File.expand_path("../../../CHANGELOG.md", site.source))
      sections = changelog.split(/(?=^## )/)
      page.content = sections.reject do |section|
        section.lines.first&.strip == "## Unreleased"
      end.join
      page.data.merge!(
        "layout" => "default",
        "title" => "Changelog",
        "nav_order" => 5,
        "permalink" => "/changelog/"
      )
      site.pages << page
    end
  end
end
