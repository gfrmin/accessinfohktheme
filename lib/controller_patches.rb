# -*- encoding : utf-8 -*-
require 'net/http'
require 'json'

# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do

  # Fix IP detection: use Cloudflare headers for real client IP
  # + Cloudflare Turnstile CAPTCHA (replaces Google reCAPTCHA)
  ApplicationController.class_eval do

    def user_ip
      request.headers['CF-Connecting-IP'] || request.remote_ip
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError
      nil
    end

    def country_from_ip
      cf_country = request.headers['CF-IPCountry']
      return cf_country if cf_country.present? && cf_country != 'XX'
      return AlaveteliGeoIP.country_code_from_ip(user_ip) if user_ip
      AlaveteliConfiguration.iso_country_code
    end

    def turnstile_site_key
      MySociety::Config.get('TURNSTILE_SITE_KEY', '')
    end
    helper_method :turnstile_site_key

    def turnstile_tags
      key = turnstile_site_key
      %(<div class="cf-turnstile" data-sitekey="#{ERB::Util.html_escape(key)}"></div>).html_safe
    end
    helper_method :turnstile_tags

    # Override the recaptcha gem's verify_recaptcha to use Cloudflare Turnstile
    def verify_recaptcha(options = {})
      token = params['cf-turnstile-response']
      return false if token.blank?

      secret = MySociety::Config.get('TURNSTILE_SECRET_KEY', '')
      uri = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')
      response = Net::HTTP.post_form(uri, {
        secret: secret,
        response: token,
        remoteip: user_ip
      })

      result = JSON.parse(response.body)
      result['success'] == true
    rescue StandardError => e
      Rails.logger.error("Turnstile verification failed: #{e.message}")
      false
    end

  end

  # Rate limit password reset emails (3 per hour per IP)
  PasswordChangesController.class_eval do

    def create_with_rate_limit
      unless @user || params[:password_change_user]
        @email_field_options = {}
        render :new
        return
      end

      email = @user ? @user.email : params[:password_change_user][:email]

      unless MySociety::Validate.is_valid_email(email)
        flash[:error] = _("That doesn't look like a valid email address. " \
                          "Please check you have typed it correctly.")
        @email_field_options =
          @user ? { disabled: true, value: email } : {}
        render :new
        return
      end

      unless verify_recaptcha
        flash.now[:error] = _('There was an error with the reCAPTCHA. Please try again.')
        @email_field_options =
          @user ? { disabled: true, value: email } : {}
        render :new
        return
      end

      password_change_ip_rate_limiter.record!(user_ip) if user_ip

      if user_ip && password_change_ip_rate_limiter.limit?(user_ip)
        logger.info "Rate limited password change from #{user_ip}"
        render :check_email
        return
      end

      @password_change_user = User.find_user_by_email(email)

      if @password_change_user
        post_redirect_attrs =
          { post_params: {},
            reason_params: \
              { web: '',
                email: _('Then you can change your password on {{site_name}}',
                            site_name: site_name),
                email_subject: _('Change your password on {{site_name}}',
                                    site_name: site_name) },
            circumstance: 'change_password',
            user: @password_change_user }
        post_redirect = PostRedirect.new(post_redirect_attrs)
        post_redirect.uri = edit_password_change_url(post_redirect.token,
                                                     @pretoken_hash)
        post_redirect.save!

        url = confirm_url(email_token: post_redirect.email_token)
        begin
          UserMailer.
            confirm_login(@password_change_user, post_redirect.reason_params, url).
              deliver_now
        rescue *OutgoingMessage.expected_send_errors => e
          logger.warn "Failed to send password change email to " \
                      "#{@password_change_user.id}: #{e.class} #{e.message}"
        end
      end

      render :check_email
    end

    alias_method :create_without_rate_limit, :create
    alias_method :create, :create_with_rate_limit

    private

    def password_change_ip_rate_limiter
      @password_change_ip_rate_limiter ||= AlaveteliRateLimiter::IPRateLimiter.new(
        AlaveteliRateLimiter::Rule.new(
          :password_change, 3,
          AlaveteliRateLimiter::Window.new(1, :hour)
        )
      )
    end

  end

  # Rate limit login confirmation email resend
  Users::SessionsController.class_eval do

    def create_with_rate_limit
      if @post_redirect.present?
        @user_signin =
          User.authenticate_from_form(user_signin_params,
                                      @post_redirect.reason_params[:user_name])
      end
      if @post_redirect.nil? || !@user_signin.errors.empty?
        clear_session_credentials
        render template: 'user/sign'
      elsif @user_signin.email_confirmed
        if spam_user?(@user_signin)
          handle_spam_user(@user_signin, 'signin') do
            render template: 'user/sign'
          end && return
        end

        sign_in(@user_signin, remember_me: params[:remember_me].present?)

        if is_modal_dialog
          render template: 'users/sessions/show'
        else
          do_post_redirect @post_redirect, @user_signin
        end
      else
        ip_rate_limiter.record!(user_ip) if user_ip
        if user_ip && ip_rate_limiter.limit?(user_ip)
          logger.info "Rate limited login confirmation resend from #{user_ip}"
          render action: 'confirm'
          return
        end
        send_confirmation_mail @user_signin
      end

    rescue ActionController::ParameterMissing
      flash[:error] = _('Invalid form submission')
      render template: 'user/sign'
    end

    alias_method :create_without_rate_limit, :create
    alias_method :create, :create_with_rate_limit

  end

  # Move signup rate limiter to cover already_registered_mail path
  UserController.class_eval do

    def signup_with_rate_limit
      @user_signup = User.new(user_params(:user_signup))
      error = false
      if @request_from_foreign_country && !verify_recaptcha
        flash.now[:error] = _('There was an error with the reCAPTCHA. ' \
                                'Please try again.')
        error = true
      end
      @user_signup.valid?
      user_alreadyexists = User.find_user_by_email(params[:user_signup][:email])
      if user_alreadyexists
        @user_signup.errors.delete(:email, :taken)
      end
      if error || !@user_signup.errors.empty?
        render action: 'sign'
      else
        # Rate limit ALL signup attempts (both new and already-registered)
        ip_rate_limiter.record!(user_ip) if user_ip

        if user_ip && ip_rate_limiter.limit?(user_ip)
          handle_rate_limited_signup(user_ip, @user_signup.email) && return
        end

        if user_alreadyexists
          already_registered_mail user_alreadyexists
        else
          if blocked_ip?
            handle_blocked_ip(@user_signup) && return
          end

          if spam_user?(@user_signup)
            handle_spam_user(@user_signup, 'signup') { render action: 'sign' }
            render action: 'sign' unless performed?
            return
          end

          @user_signup.email_confirmed = false
          @user_signup.save!
          send_confirmation_mail @user_signup
        end
        nil
      end

    rescue ActionController::ParameterMissing
      flash[:error] = _('Invalid form submission')
      render action: :sign
    end

    alias_method :signup_without_rate_limit, :signup
    alias_method :signup, :signup_with_rate_limit

  end

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
    alias_method :show_without_hk_deadline_info, :show
    alias_method :show, :show_with_hk_deadline_info

  end

end
