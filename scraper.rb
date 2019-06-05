require 'epathway_scraper'

exceptions = []
EpathwayScraper::AUTHORITIES.keys.each do |authority_label|
  puts "\nScraping authority #{authority_label}..."
  begin
    EpathwayScraper.scrape_authority(authority_label) do |record|
      record["authority_label"] = authority_label.to_s

      EpathwayScraper.log(record)
      ScraperWiki.save_sqlite(["authority_label", "council_reference"], record)
    end
  rescue StandardError => e
    STDERR.puts "#{authority_label}: ERROR: #{e}"
    STDERR.puts e.backtrace
    exceptions << e
  end
end

unless exceptions.empty?
  raise "There were earlier errors. See output for details"
end
