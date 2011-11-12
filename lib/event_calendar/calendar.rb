module EventCalendar
  module CalendarHelper
    class Calendar
      def initialize options, block=nil
        # default month name for the given number
        if options[:show_header]
          options[:month_name_text] ||= I18n.translate(:'date.month_names')[options[:month]]
        end

        # make the height calculations
        # tricky since multiple events in a day could force an increase in the set height
        height = options[:day_names_height]
        row_heights = cal_row_heights(options)
        row_heights.each do |row_height|
          height += row_height
        end

        # the first and last days of this calendar month
        if options[:dates].is_a?(Range)
          first = options[:dates].begin
          last = options[:dates].end
        else
          first = Date.civil(options[:year], options[:month], 1)
          last = Date.civil(options[:year], options[:month], -1)
        end

        # create the day names array [Sunday, Monday, etc...]
        day_names = []
        if options[:abbrev]
          day_names.concat(I18n.translate(:'date.abbr_day_names'))
        else
          day_names.concat(I18n.translate(:'date.day_names'))
        end
        options[:first_day_of_week].times do
          day_names.push(day_names.shift)
        end

        @options = options
        @html = ""

        outer_calendar_container do
          table_header_and_links

          # body container (holds day names and the calendar rows)
          @html << %(<div class="ec-body" style="height: #{height}px;">)

          # day names
          @html << %(<table class="ec-day-names" style="height: #{options[:day_names_height]}px;" cellpadding="0" cellspacing="0">)
          @html << %(<tbody><tr>)
          day_names.each do |day_name|
            @html << %(<th class="ec-day-name" title="#{day_name}">#{day_name}</th>)
          end
          @html << %(</tr></tbody></table>)

          # container for all the calendar rows
          @html << %(<div class="ec-rows" style="top: #{options[:day_names_height]}px; )
          @html << %(height: #{height - options[:day_names_height]}px;">)

          # initialize loop variables
          first_day_of_week = beginning_of_week(first, options[:first_day_of_week])
          last_day_of_week = end_of_week(first, options[:first_day_of_week])
          last_day_of_cal = end_of_week(last, options[:first_day_of_week])
          row_num = 0
          top = 0

          # go through a week at a time, until we reach the end of the month
          while(last_day_of_week <= last_day_of_cal)
            @html << %(<div class="ec-row" style="top: #{top}px; height: #{row_heights[row_num]}px;">)
            top += row_heights[row_num]

            # this weeks background table
            @html << %(<table class="ec-row-bg" cellpadding="0" cellspacing="0">)
            @html << %(<tbody><tr>)
            first_day_of_week.upto(first_day_of_week+6) do |day|
              today_class = (day == Date.today) ? "ec-today-bg" : ""
              other_month_class = (day < first) || (day > last) ? 'ec-other-month-bg' : ''
              @html << %(<td class="ec-day-bg #{today_class} #{other_month_class}">&nbsp;</td>)
            end
            @html << %(</tr></tbody></table>)

            # calendar row
            @html << %(<table class="ec-row-table" cellpadding="0" cellspacing="0">)
            @html << %(<tbody>)

            # day numbers row
            @html << %(<tr>)
            first_day_of_week.upto(last_day_of_week) do |day|
              @html << %(<td class="ec-day-header )
              @html << %(ec-today-header ) if options[:show_today] and (day == Date.today)
              @html << %(ec-other-month-header ) if (day < first) || (day > last)
              @html << %(ec-weekend-day-header) if weekend?(day)
              @html << %(" style="height: #{options[:day_nums_height]}px;">)
              if options[:link_to_day_action]
                @html << day_link(day.day, day, options[:link_to_day_action])
              else
                @html << %(#{day.day})
              end
              @html << %(</td>)
            end
            @html << %(</tr>)

            # event rows for this day
            # for each event strip, create a new table row
            options[:event_strips].each do |strip|
              @html << %(<tr>)
              # go through through the strip, for the entries that correspond to the days of this week
              strip[row_num*7, 7].each_with_index do |event, index|
                day = first_day_of_week + index

                if event
                  # get the dates of this event that fit into this week
                  dates = event.clip_range(first_day_of_week, last_day_of_week)
                  # if the event (after it has been clipped) starts on this date,
                  # then create a new cell that spans the number of days
                  if dates[0] == day.to_date
                    # check if we should display the bg color or not
                    no_bg = no_event_bg?(event, options)
                    class_name = event.class.name.tableize.singularize

                    @html << %(<td class="ec-event-cell" colspan="#{(dates[1]-dates[0]).to_i + 1}" )
                    @html << %(style="padding-top: #{options[:event_margin]}px;">)
                    @html << %(<div id="ec-#{class_name}-#{event.id}" class="ec-event )
                    if class_name != "event"
                      @html << %(ec-#{class_name} )
                    end
                    if no_bg
                      @html << %(ec-event-no-bg" )
                      @html << %(style="color: #{event.color}; )
                    else
                      @html << %(ec-event-bg" )
                      @html << %(style="background-color: #{event.color}; )
                    end

                    @html << %(padding-top: #{options[:event_padding_top]}px; )
                    @html << %(height: #{options[:event_height] - options[:event_padding_top]}px;" )
                    if options[:use_javascript]
                      # custom attributes needed for javascript event highlighting
                      @html << %(data-event-id="#{event.id}" data-event-class="#{class_name}" data-color="#{event.color}" )
                    end
                    @html << %(>)

                    # add a left arrow if event is clipped at the beginning
                    if event.start_at.to_date < dates[0]
                      @html << %(<div class="ec-left-arrow"></div>)
                    end
                    # add a right arrow if event is clipped at the end
                    if event.end_at.to_date > dates[1]
                      @html << %(<div class="ec-right-arrow"></div>)
                    end

                    if no_bg
                      @html << %(<div class="ec-bullet" style="background-color: #{event.color};"></div>)
                      # make sure anchor text is the event color
                      # here b/c CSS 'inherit' color doesn't work in all browsers
                      @html << %(<style type="text/css">.ec-#{class_name}-#{event.id} a { color: #{event.color}; }</style>)
                    end

                    if block_given?
                      # add the additional html that was passed as a block to this helper
                      @html << block.call({:event => event, :day => day.to_date, :options => options})
                    else
                      # default content in case nothing is passed in
                      @html << %(<a href="/#{class_name.pluralize}/#{event.id}" title="#{h(event.name)}">#{h(event.name)}</a>)
                    end

                    @html << %(</div></td>)
                  end

                else
                  # there wasn't an event, so create an empty cell and container
                  @html << %(<td class="ec-event-cell ec-no-event-cell" )
                  @html << %(style="padding-top: #{options[:event_margin]}px;">)
                  @html << %(<div class="ec-event" )
                  @html << %(style="padding-top: #{options[:event_padding_top]}px; )
                  @html << %(height: #{options[:event_height] - options[:event_padding_top]}px;" )
                  @html << %(>)
                  @html << %(&nbsp;</div></td>)
                end
              end
              @html << %(</tr>)
            end

            @html << %(</tbody></table>)
            @html << %(</div>)

            # increment the calendar row we are on, and the week
            row_num += 1
            first_day_of_week += 7
            last_day_of_week += 7
          end

          @html << %(</div>)
          @html << %(</div>)
        end
      end

      def to_s
        @html
      end

      attr_reader :options


      def << value
        @html << value
      end

      private

      def outer_calendar_container
        self << %(<div class="ec-calendar")
        self << %(style="width: #{options[:width]}px;") if options[:width]
        self << %(>)
        yield

        self << %(</div>)
      end

      def table_header_and_links
        if options[:show_header]
          self << %(<table class="ec-calendar-header" cellpadding="0" cellspacing="0">)
          self << %(<thead><tr>)
          if options[:previous_month_text] or options[:next_month_text]
            self << %(<th colspan="2" class="ec-month-nav ec-previous-month">#{options[:previous_month_text]}</th>)
            colspan = 3
          else
            colspan = 7
          end

          self << %(<th colspan="#{colspan}" class="ec-month-name">#{options[:month_name_text]}</th>)

          if options[:next_month_text]
            self << %(<th colspan="2" class="ec-month-nav ec-next-month">#{options[:next_month_text]}</th>)
          end
          self << %(</tr></thead></table>)
        end
      end


      # calculate the height of each row
      # by default, it will be the height option minus the day names height,
      # divided by the total number of calendar rows
      # this gets tricky, however, if there are too many event rows to fit into the row's height
      # then we need to add additional height
      def cal_row_heights(options)
        # number of rows is the number of days in the event strips divided by 7
        num_cal_rows = options[:event_strips].first.size / 7
        # the row will be at least this big
        min_height = (options[:height] - options[:day_names_height]) / num_cal_rows
        row_heights = []
        num_event_rows = 0
        # for every day in the event strip...
        1.upto(options[:event_strips].first.size+1) do |index|
          num_events = 0
          # get the largest event strip that has an event on this day
          options[:event_strips].each_with_index do |strip, strip_num|
            num_events = strip_num + 1 unless strip[index-1].blank?
          end
          # get the most event rows for this week
          num_event_rows = [num_event_rows, num_events].max
          # if we reached the end of the week, calculate this row's height
          if index % 7 == 0
            total_event_height = options[:event_height] + options[:event_margin]
            calc_row_height = (num_event_rows * total_event_height) + options[:day_nums_height] + options[:event_margin]
            row_height = [min_height, calc_row_height].max
            row_heights << row_height
            num_event_rows = 0
          end
        end
        row_heights
      end

      #
      # helper methods for working with a calendar week
      #

      def days_between(first, second)
        if first > second
          second + (7 - first)
        else
          second - first
        end
      end

      def beginning_of_week(date, start = 0)
        days_to_beg = days_between(start, date.wday)
        date - days_to_beg
      end

      def end_of_week(date, start = 0)
        beg = beginning_of_week(date, start)
        beg + 6
      end

      def weekend?(date)
        [0, 6].include?(date.wday)
      end

    end
  end
end
