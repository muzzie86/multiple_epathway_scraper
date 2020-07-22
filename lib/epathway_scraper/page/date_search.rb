# frozen_string_literal: true

require "epathway_scraper/page/search"

module EpathwayScraper
  module Page
    # The tab for searching for applications by date range
    module DateSearch
      def self.pick_date_range(page, from_date, to_date)
        from = page.form.field_with(name: /FromDatePicker/)
        to = page.form.field_with(name: /ToDatePicker/)

        from.value = from_date.strftime("%d/%m/%Y")

        # By default the to date is set to today's date. We can't use a later date
        # otherwise the search doesn't work
        to.value = to_date.strftime("%d/%m/%Y") unless to_date > Date.strptime(to.value, "%d/%m/%Y")

        Search.click_search(page)
      end

      def self.pick_all_year(page, year)
        pick_date_range(
          page,
          Date.new(year, 1, 1),
          Date.new(year + 1, 1, 1).prev_day
        )
      end
    end
  end
end
