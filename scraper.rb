require 'epathway_scraper'

# TODO: If scraping on one authority fails then don't stop for other authorities
# but still raise an error at the end

EpathwayScraper::AUTHORITIES.keys.each do |authority_label|
  puts "\nScraping authority #{authority_label}..."
  EpathwayScraper.scrape_authority(authority_label) do |record|
    record["authority_label"] = authority_label.to_s

    EpathwayScraper.log(record)
    ScraperWiki.save_sqlite(["authority_label", "council_reference"], record)
  end
end
