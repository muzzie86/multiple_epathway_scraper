# frozen_string_literal: true

module EpathwayScraper
  # Helper methods for getting stuff out of tables in epathway
  module Table
    # Also include the urls of links (these are returned as relative urls)
    def self.extract_table_data_and_urls(table)
      headings = table.at("tr.ContentPanelHeading").search("th").map(&:inner_text)
      table.search("tr.ContentPanel, tr.AlternateContentPanel").map do |tr|
        content = tr.search("td").map(&:inner_text)
        url = tr.at("a")["href"] if tr.at("a")
        r = {}
        content.each_with_index do |value, index|
          r[headings[index]] = value
        end
        { content: r, url: url }
      end
    end
  end
end
