# frozen_string_literal: true

require "timecop"

RSpec.describe EpathwayScraper do
  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  describe ".save" do
    let(:record) { { "foo" => 1, "council_reference" => "ABC", "address" => "here" } }

    it "should save a record to the local sqlite database" do
      EpathwayScraper.save(record)
      expect(ScraperWiki.select("* from data")).to eq [record]
    end
  end

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

    EpathwayScraper::AUTHORITIES.keys.each do |authority|
      it authority do
        test_scraper(authority)
      end
    end
  end
end
