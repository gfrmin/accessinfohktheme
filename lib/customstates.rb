# -*- encoding : utf-8 -*-
# See `http://alaveteli.org/docs/customising/themes/#customising-the-request-states`
# for more explanation of this file
#
# Custom states for Hong Kong's Code on Access to Information

module InfoRequestCustomStates

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Work out what the situation of the request is. In addition to
  # values of self.described_state, in base Alaveteli can return
  # these (calculated) values:
  #   waiting_classification
  #   waiting_response_overdue
  #   waiting_response_very_overdue
  #
  # Hong Kong-specific calculated statuses:
  #   interim_reply_received - Got 10-day interim reply, waiting for final response
  #   exceeds_21_days - Response time exceeded 21 days without proper explanation
  def theme_calculate_status
    # Check for Hong Kong-specific time-based statuses
    return 'interim_reply_received' if has_interim_reply_without_final?
    return 'exceeds_21_days' if exceeds_target_time_without_explanation?

    # Fall back to core calculation
    return self.base_calculate_status
  end

  # Helper method: Check if we received an interim reply but no final response
  def has_interim_reply_without_final?
    return false unless self.awaiting_response

    # Look for interim reply messages in correspondence
    interim_reply_keywords = ['interim reply', '中期回覆', 'more time', '需要更多時間',
                             'extending', '延長', 'additional time', '額外時間']

    self.incoming_messages.each do |message|
      body_text = message.get_main_body_text_unfolded.downcase
      if interim_reply_keywords.any? { |keyword| body_text.include?(keyword.downcase) }
        # Check if this was within first 10-21 days and we're still waiting
        return true if (Time.now - self.created_at) > 10.days
      end
    end

    false
  end

  # Helper method: Check if request exceeded 21 days without explanation
  def exceeds_target_time_without_explanation?
    return false unless self.awaiting_response

    days_elapsed = (Time.now - self.created_at) / 1.day
    return false if days_elapsed <= 21

    # If over 21 days and still waiting, check if there was an explanation
    has_explanation = self.incoming_messages.any? do |message|
      body = message.get_main_body_text_unfolded.downcase
      body.include?('extension') || body.include?('延長') ||
      body.include?('exceptional') || body.include?('特殊情況') ||
      body.include?('more time') || body.include?('需要更多時間')
    end

    return !has_explanation
  end

  # Mixin methods for InfoRequest
  module ClassMethods

    # Return the name of a custom status for display
    def theme_display_status(status)
      case status
      when 'internal_review_pending'
        _("Internal review pending.")
      when 'ombudsman_complaint'
        _("Complaint lodged with The Ombudsman.")
      when 'interim_reply_received'
        _("Interim reply received, awaiting final response.")
      when 'payment_required'
        _("Payment required for photocopying charges.")
      when 'exceeds_21_days'
        _("Response time exceeded 21 calendar days.")
      when 'transferred_hk'
        _("Transferred to another Hong Kong government department.")
      else
        raise _("unknown status ") + status
      end
    end

    # Return the list of custom statuses added by the theme
    def theme_extra_states
      return [
        'internal_review_pending',    # User requested internal review by senior officer
        'ombudsman_complaint',         # Complaint lodged with Ombudsman
        'interim_reply_received',      # Received 10-day interim reply, waiting for final
        'payment_required',            # Awaiting payment for photocopying charges
        'exceeds_21_days',            # Exceeded 21-day target without explanation
        'transferred_hk'               # Request transferred between HK departments
      ]
    end

  end
end

module RequestControllerCustomStates

  # `theme_describe_state` is called after the core describe_state code.
  # It should end by raising an error if the status is unknown.
  def theme_describe_state(info_request)
    case info_request.calculate_status
    when 'internal_review_pending'
      flash[:notice] = _("You have requested an internal review. The department should have this reviewed by a directorate officer at least one rank senior to the officer who made the original decision.")
      redirect_to request_url(@info_request)
    when 'ombudsman_complaint'
      flash[:notice] = _("You have indicated that you've complained to The Ombudsman. They will investigate whether the department properly complied with the Code on Access to Information.")
      redirect_to request_url(@info_request)
    when 'interim_reply_received'
      flash[:notice] = _("The department sent an interim reply. Under the Code, they should provide the information within 21 calendar days of your original request, or up to 51 days in exceptional circumstances with explanation.")
      redirect_to request_url(@info_request)
    when 'payment_required'
      flash[:notice] = _("The department has indicated that photocopying charges apply (HK$1.5 per A4 page, HK$1.6 per A3 page). Information will not be released until payment is made.")
      redirect_to request_url(@info_request)
    when 'exceeds_21_days'
      flash[:warning] = _("This request has exceeded the 21 calendar day target response time without explanation. You may wish to send a reminder or request an internal review.")
      redirect_to request_url(@info_request)
    when 'transferred_hk'
      flash[:notice] = _("Your request has been transferred to another Hong Kong government department. The receiving department should handle your request under the Code on Access to Information.")
      redirect_to request_url(@info_request)
    else
      raise "unknown calculate_status " + info_request.calculate_status
    end
  end

end
