# frozen_string_literal: true

require "timecop"

RSpec.describe EpathwayScraper do
  describe "Scraper" do
    def test_scraper(authority)
      results = VCR.use_cassette(authority) do
        Timecop.freeze(Date.new(2019, 5, 15)) do
          results = []

          EpathwayScraper.scrape_authority(authority) do |record|
            results << record
          end

          results.sort_by { |r| r["council_reference"] }
        end
      end

      expected = if File.exist?("fixtures/expected/#{authority}.yml")
                   YAML.safe_load(File.read("fixtures/expected/#{authority}.yml"))
                 else
                   []
                 end

      if results != expected
        # Overwrite expected so that we can compare with version control
        # (and maybe commit if it is correct)
        File.open("fixtures/expected/#{authority}.yml", "w") do |f|
          f.write(results.to_yaml)
        end
      end

      expect(results).to eq expected
    end

    EpathwayScraper::AUTHORITIES.each_key do |authority|
      it authority do
        test_scraper(authority)
      end
    end
  end
end
