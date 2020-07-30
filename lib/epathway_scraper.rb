# frozen_string_literal: true

require "epathway_scraper/version"
require "epathway_scraper/page/list_select"
require "epathway_scraper/page/search"
require "epathway_scraper/page/index"
require "epathway_scraper/page/date_search"
require "epathway_scraper/authorities"

require "mechanize"
require "scraperwiki"

# Top level module of gem
module EpathwayScraper
  # list: one of :all, :advertising, :last_30_days, :all_this_year
  # state: NSW, VIC or NT, etc...
  def self.scrape(url:, list:, state:, max_pages: nil, force_detail: false,
                  disable_ssl_certificate_check: false)
    base_url = url + "/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP"
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE if disable_ssl_certificate_check

    # Navigate to the correct list
    page = agent.get(base_url)
    page = Page::ListSelect.follow_javascript_redirect(page, agent)

    if list == :all
      Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
    elsif list == :advertising
      Page::ListSelect.select_advertising(page) if Page::ListSelect.on_page?(page)
    elsif list == :last_30_days
      page = Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
      Page::Search.pick(page, :last_30_days, agent)
    # Get all applications lodged this entire year
    elsif list == :all_this_year
      page = Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
      page = Page::Search.click_date_search_tab(page, agent)
      Page::DateSearch.pick_all_year(page, DateTime.now.year)
    else
      raise "Unexpected list: #{list}"
    end

    # Notice how we're skipping the clicking of search
    # even though that's what the user interface is showing next
    Page::Index.scrape_all_index_pages(
      max_pages, base_url, agent, force_detail, state
    ) do |record|
      yield record
    end
  end

  def self.scrape_authority(authority)
    scrape(EpathwayScraper::AUTHORITIES[authority]) do |record|
      # Putting in "ePathway" in the description must be some kind
      # of default for new records. We don't want to include these
      # because they're staggeringly unhelpful to users. Much better
      # to wait until a proper description gets added by the authority
      yield record if record["description"] != "ePathway"
    end
  end

  def self.scrape_and_save_authority(authority)
    scrape_authority(authority) do |record|
      save(record)
    end
  end

  def self.save(record)
    log(record)
    ScraperWiki.save_sqlite(["council_reference"], record)
  end

  def self.log(record)
    puts "Storing #{record['council_reference']} - #{record['address']}"
  end
end
