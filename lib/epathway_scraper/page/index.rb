# frozen_string_literal: true

require "epathway_scraper/table"
require "epathway_scraper/page/detail"

require "English"

module EpathwayScraper
  module Page
    # A list of applications (probably paginated)
    module Index
      def self.extract_total_number_of_pages(page)
        page_label = page.at("#ctl00_MainBodyContent_mPagingControl_pageNumberLabel")
        if page_label.nil?
          # If we can't find the label assume there is only one page of results
          1
        elsif page_label.inner_text =~ /Page \d+ of (\d+)/
          $LAST_MATCH_INFO[1].to_i
        else
          raise "Unexpected form for number of pages"
        end
      end

      def self.find_value_by_key(row, key_matches)
        # Matching using lowercase letters to make things simpler
        r = row[:content].find { |k, _v| key_matches.include?(k.downcase) }
        r[1] if r
      end

      def self.normalise_row_data(row)
        result = {}
        row[:content].each do |key, value|
          result[normalise_key(key, value)] = value
        end
        result
      end

      def self.normalise_key(key, value)
        case key.downcase
        when "app no.", "application", "application no", "application number",
             "number", "our reference"
          :council_reference
        when "application date", "date", "date lodged", "date received",
             "date registered", "lodged", "lodge date"
          :date_received
        # This can be different from the date_received. Weird, huh?
        when "lodgement date"
          :lodgement_date
        when "current status", "status"
          :status
        when "address", "application location", "location", "location address",
             "primary property address", "property address", "site address",
             "site location", "street address"
          :address
        when "suburb", "location suburb"
          :suburb
        when "application description", "application proposal", "description",
             "details of proposal or permit", "proposal",
             "proposed use or development"
          :description
        when "type", "application type", "type of application"
          :type
        when "current decision", "decision (check status)", "decision (if decided)",
             "decision"
          :decision
        # TODO: Year of what exactly?
        when "year"
          :year
        else
          raise "Unexpected key: #{key.downcase} with value: #{value}"
        end
      end

      def self.extract_index_data(row)
        normalised = normalise_row_data(row)

        date_received = normalised[:date_received] || normalised[:lodgement_date]
        date_received = Date.strptime(date_received, "%d/%m/%Y").to_s if date_received

        address = normalised[:address]
        suburb = normalised[:suburb]

        # If there's a carriage return, the second part is the lot number.
        # We don't really want that
        address = address.split("\n")[0].strip if address.include?("\n")

        # Add the suburb to addresses that don't already include them
        address += ", #{suburb}" if suburb && !address.include?(suburb)
        address = address.squeeze(" ")

        {
          council_reference: normalised[:council_reference],
          address: address,
          description: normalised[:description],
          date_received: date_received,
          # This URL will only work in a session. Thanks for that!
          detail_url: row[:url]
        }
      end

      # If force_detail is true, then we always scrape the detail page
      # We need this for the case of Barossa, SA that doesn't include the
      # suburb in the address on the index page. We don't have a simple and
      # reliable way to automatically detect this
      def self.scrape_index_page(page, base_url, agent, force_detail, state)
        table = page.at("table.ContentPanel")
        return if table.nil?

        Table.extract_table_data_and_urls(table).each do |row|
          data = extract_index_data(row)

          # Check if we have all the information we need from the index_data
          # If so then there's no need to scrape the detail page
          unless data[:council_reference] &&
                 data[:address] &&
                 data[:description] &&
                 data[:date_received] &&
                 !force_detail

            # Get application page with a referrer or we get an error page
            detail_page = agent.get(data[:detail_url], [], page.uri)

            data = data.merge(Detail.scrape(detail_page))

            # Finally check we have everything
            unless data[:council_reference] &&
                   data[:address] &&
                   data[:description] &&
                   data[:date_received]
              raise "Couldn't get all the data: #{data}"
            end
          end

          # Remove "building name" from address
          if data[:address].split(",").size >= 3
            data[:address] = data[:address].split(",", 2)[1].strip
          end

          # Add state to the end of the address if it isn't already there
          data[:address] += ", #{state}" unless data[:address].include?(state)

          record = {
            "council_reference" => data[:council_reference],
            "address" => data[:address],
            "description" => data[:description],
            "info_url" => base_url,
            "date_scraped" => Date.today.to_s,
            "date_received" => data[:date_received]
          }
          record["on_notice_from"] = data[:on_notice_from] if data[:on_notice_from]
          record["on_notice_to"] = data[:on_notice_to] if data[:on_notice_to]

          # One final check that we actually want this application. If
          # the council hasn't got a proper council reference for it yet,
          # there's little point to adding it, in fact it will kind of screw
          # things up. So, better to just ignore it
          yield(record) if record["council_reference"] != "Not on file"
        end
      end

      # This scrapes all index pages by doing GETs on each page
      def self.scrape_all_index_pages(number_pages, base_url, agent, force_detail, state)
        page = agent.get("EnquirySummaryView.aspx?PageNumber=1")
        number_pages ||= extract_total_number_of_pages(page)
        (1..number_pages).each do |no|
          page = agent.get("EnquirySummaryView.aspx?PageNumber=#{no}") if no > 1
          scrape_index_page(page, base_url, agent, force_detail, state) do |record|
            yield record
          end
        end
      end
    end
  end
end
