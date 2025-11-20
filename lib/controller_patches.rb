# -*- encoding : utf-8 -*-
# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do

  # Hong Kong-specific controller helper methods for deadline calculations
  ApplicationController.class_eval do

    # Calculate Hong Kong Code on Access to Information deadlines
    # Returns hash with deadline dates (10, 21, 51 calendar days)
    def hk_calculate_deadlines(request_created_at)
      {
        initial_response: request_created_at + 10.days,    # 10 calendar days
        target_completion: request_created_at + 21.days,   # 21 calendar days
        maximum_time: request_created_at + 51.days         # 51 calendar days in exceptional circumstances
      }
    end
    helper_method :hk_calculate_deadlines

    # Check if request has exceeded the 10-day initial response deadline
    def hk_exceeded_initial_deadline?(request_created_at)
      Time.now > (request_created_at + 10.days)
    end
    helper_method :hk_exceeded_initial_deadline?

    # Check if request has exceeded the 21-day target deadline
    def hk_exceeded_target_deadline?(request_created_at)
      Time.now > (request_created_at + 21.days)
    end
    helper_method :hk_exceeded_target_deadline?

    # Check if request has exceeded the 51-day maximum deadline
    def hk_exceeded_maximum_deadline?(request_created_at)
      Time.now > (request_created_at + 51.days)
    end
    helper_method :hk_exceeded_maximum_deadline?

    # Get days elapsed since request was made (calendar days)
    def hk_days_elapsed(request_created_at)
      ((Time.now - request_created_at) / 1.day).floor
    end
    helper_method :hk_days_elapsed

    # Get days remaining until deadline (negative if overdue)
    def hk_days_until_deadline(request_created_at, deadline_type = :target)
      deadline = case deadline_type
      when :initial
        request_created_at + 10.days
      when :target
        request_created_at + 21.days
      when :maximum
        request_created_at + 51.days
      else
        request_created_at + 21.days
      end

      ((deadline - Time.now) / 1.day).ceil
    end
    helper_method :hk_days_until_deadline

    # Get user-friendly deadline status message
    def hk_deadline_status_message(request_created_at)
      days_elapsed = hk_days_elapsed(request_created_at)

      if days_elapsed <= 10
        _("Department should respond within %{days} calendar days (by %{date})") % {
          days: 10 - days_elapsed,
          date: I18n.l(request_created_at + 10.days, format: :long)
        }
      elsif days_elapsed <= 21
        _("Target response time is %{days} calendar days (by %{date})") % {
          days: 21 - days_elapsed,
          date: I18n.l(request_created_at + 21.days, format: :long)
        }
      elsif days_elapsed <= 51
        _("Request overdue. Maximum time is %{days} calendar days (by %{date})") % {
          days: 51 - days_elapsed,
          date: I18n.l(request_created_at + 51.days, format: :long)
        }
      else
        _("Request significantly overdue (exceeded 51 calendar day maximum). Consider requesting an internal review or complaining to The Ombudsman.")
      end
    end
    helper_method :hk_deadline_status_message

    # Get CSS class for deadline status (for styling)
    def hk_deadline_status_class(request_created_at)
      days_elapsed = hk_days_elapsed(request_created_at)

      if days_elapsed <= 10
        'hk-deadline-ok'
      elsif days_elapsed <= 21
        'hk-deadline-approaching'
      elsif days_elapsed <= 51
        'hk-deadline-overdue'
      else
        'hk-deadline-significantly-overdue'
      end
    end
    helper_method :hk_deadline_status_class

  end

  # Add HK-specific display helpers to RequestController
  RequestController.class_eval do

    # Display HK deadline information on request page
    def show_with_hk_deadline_info
      show_without_hk_deadline_info

      if @info_request && @info_request.awaiting_response
        @hk_deadlines = hk_calculate_deadlines(@info_request.created_at)
        @hk_days_elapsed = hk_days_elapsed(@info_request.created_at)
        @hk_deadline_message = hk_deadline_status_message(@info_request.created_at)

        # Add flash warning if significantly overdue
        if hk_exceeded_maximum_deadline?(@info_request.created_at)
          flash.now[:warning] ||= ""
          flash.now[:warning] += " " + _("This request has exceeded the 51 calendar day maximum under the Code on Access to Information.")
        elsif hk_exceeded_target_deadline?(@info_request.created_at)
          flash.now[:notice] ||= ""
          flash.now[:notice] += " " + _("This request has exceeded the 21 calendar day target response time.")
        end
      end
    end
    # Note: Uncomment below to activate (requires testing in Alaveteli environment)
    # alias_method :show_without_hk_deadline_info, :show
    # alias_method :show, :show_with_hk_deadline_info

  end

end
