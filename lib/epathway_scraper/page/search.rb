# frozen_string_literal: true

module EpathwayScraper
  module Page
    # Usually the second page on the site where you do an actual search.
    # It has a tab interface usually for different kinds of searches
    module Search
      DATE_TAB_LABELS = [
        "Date Search",
        "Lodgement Date",
        "Date Range",
        "Date Lodged",
        "Date",
        "Search by Date Range",
        "Date range search",
        "Search by date range"
      ].freeze

      # Currently only supporting type of :last_30_days
      def self.pick(page, type, agent)
        raise "Unexpected type #{type}" unless type == :last_30_days

        page = click_date_search_tab(page, agent)
        # The Date tab defaults to a search range of the last 30 days.
        click_search(page)
      end

      def self.click_date_search_tab(page, agent)
        table = page.at("table.tabcontrol")
        links = table.search("a")
        a = links.find { |b| DATE_TAB_LABELS.include?(b.inner_text) }
        raise "Couldn't find tab link in #{links.map(&:inner_text).join(', ')}" if a.nil?

        # Extract target and argument of postback from href
        match = a["href"].match(/javascript:__doPostBack\('(.*)','(.*)'\)/)
        raise "Link isn't a postback link: #{a['href']}" if match.nil?

        form = page.forms.first
        raise "Can't find form for postback" if form.nil?

        form["__EVENTTARGET"] = match[1]
        form["__EVENTARGUMENT"] = match[2]
        agent.submit(form)
      end

      def self.search_for_one_application(page, application_no)
        form = page.form
        field = form.field_with(name: /FormattedNumberTextBox/)
        field.value = application_no
        click_search(page)
      end

      def self.click_search(page)
        page.form.submit(search_button(page))
      end

      def self.on_page?(page)
        !search_button(page).nil?
      end

      def self.search_button(page)
        page.form.button_with(value: "Search")
      end
    end
  end
end
