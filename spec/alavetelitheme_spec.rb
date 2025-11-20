# -*- encoding : utf-8 -*-
# If defined, ALAVETELI_TEST_THEME will be loaded in config/initializers/theme_loader
ALAVETELI_TEST_THEME = 'alavetelitheme'
require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','..','spec','spec_helper'))

describe 'AccessInfoHK Theme' do

  describe 'Custom Request States' do

    describe 'theme_extra_states' do
      it 'includes all Hong Kong-specific states' do
        expect(InfoRequest.theme_extra_states).to include('internal_review_pending')
        expect(InfoRequest.theme_extra_states).to include('ombudsman_complaint')
        expect(InfoRequest.theme_extra_states).to include('interim_reply_received')
        expect(InfoRequest.theme_extra_states).to include('payment_required')
        expect(InfoRequest.theme_extra_states).to include('exceeds_21_days')
        expect(InfoRequest.theme_extra_states).to include('transferred_hk')
      end

      it 'returns exactly 6 custom states' do
        expect(InfoRequest.theme_extra_states.length).to eq(6)
      end
    end

    describe 'theme_display_status' do
      it 'returns correct status message for internal_review_pending' do
        expect(InfoRequest.theme_display_status('internal_review_pending')).to eq("Internal review pending.")
      end

      it 'returns correct status message for ombudsman_complaint' do
        expect(InfoRequest.theme_display_status('ombudsman_complaint')).to eq("Complaint lodged with The Ombudsman.")
      end

      it 'returns correct status message for interim_reply_received' do
        expect(InfoRequest.theme_display_status('interim_reply_received')).to eq("Interim reply received, awaiting final response.")
      end

      it 'returns correct status message for payment_required' do
        expect(InfoRequest.theme_display_status('payment_required')).to eq("Payment required for photocopying charges.")
      end

      it 'returns correct status message for exceeds_21_days' do
        expect(InfoRequest.theme_display_status('exceeds_21_days')).to eq("Response time exceeded 21 calendar days.")
      end

      it 'returns correct status message for transferred_hk' do
        expect(InfoRequest.theme_display_status('transferred_hk')).to eq("Transferred to another Hong Kong government department.")
      end

      it 'raises error for unknown status' do
        expect { InfoRequest.theme_display_status('unknown_status') }.to raise_error(RuntimeError, /unknown status/)
      end
    end

    describe 'interim reply detection' do
      let(:info_request) { FactoryBot.create(:info_request) }
      let(:incoming_message) { FactoryBot.create(:incoming_message, info_request: info_request) }

      context 'with English interim reply keywords' do
        it 'detects "interim reply" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("This is an interim reply. We need more time.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end

        it 'detects "more time" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("We need more time to process your request.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end

        it 'detects "extending" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("We are extending the deadline for your request.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end
      end

      context 'with Chinese interim reply keywords' do
        it 'detects "中期回覆" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("這是中期回覆。我們需要更多時間。")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end

        it 'detects "需要更多時間" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("我們需要更多時間處理你的要求。")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end

        it 'detects "延長" in message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("我們正在延長你的要求的截止日期。")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be true
        end
      end

      context 'without interim reply keywords' do
        it 'does not detect interim reply in regular message' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("Here is the information you requested.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 15.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be false
        end
      end

      context 'within first 10 days' do
        it 'does not flag as interim reply if within 10 days' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("This is an interim reply.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 5.days.ago)

          expect(info_request.has_interim_reply_without_final?).to be false
        end
      end
    end

    describe '21-day deadline detection' do
      let(:info_request) { FactoryBot.create(:info_request) }

      context 'request within 21 days' do
        it 'does not flag as exceeds_21_days' do
          info_request.update_attribute(:created_at, 15.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end
      end

      context 'request over 21 days without explanation' do
        it 'flags as exceeds_21_days' do
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)
          allow(info_request).to receive(:incoming_messages).and_return([])

          expect(info_request.exceeds_target_time_without_explanation?).to be true
        end
      end

      context 'request over 21 days with English explanation' do
        let(:incoming_message) { FactoryBot.create(:incoming_message, info_request: info_request) }

        it 'does not flag if extension explained' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("We need to request an extension due to exceptional circumstances.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end

        it 'does not flag if more time mentioned' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("We need more time to complete your request.")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end
      end

      context 'request over 21 days with Chinese explanation' do
        let(:incoming_message) { FactoryBot.create(:incoming_message, info_request: info_request) }

        it 'does not flag if 延長 mentioned' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("由於特殊情況，我們需要延長處理時間。")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end

        it 'does not flag if 需要更多時間 mentioned' do
          allow(incoming_message).to receive(:get_main_body_text_unfolded).and_return("我們需要更多時間完成你的要求。")
          info_request.incoming_messages << incoming_message
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(true)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end
      end

      context 'request not awaiting response' do
        it 'does not flag if not awaiting response' do
          info_request.update_attribute(:created_at, 25.days.ago)
          allow(info_request).to receive(:awaiting_response).and_return(false)

          expect(info_request.exceeds_target_time_without_explanation?).to be false
        end
      end
    end

    describe 'theme_calculate_status' do
      let(:info_request) { FactoryBot.create(:info_request) }

      it 'returns interim_reply_received when interim reply detected' do
        allow(info_request).to receive(:has_interim_reply_without_final?).and_return(true)
        allow(info_request).to receive(:exceeds_target_time_without_explanation?).and_return(false)

        expect(info_request.theme_calculate_status).to eq('interim_reply_received')
      end

      it 'returns exceeds_21_days when deadline exceeded' do
        allow(info_request).to receive(:has_interim_reply_without_final?).and_return(false)
        allow(info_request).to receive(:exceeds_target_time_without_explanation?).and_return(true)

        expect(info_request.theme_calculate_status).to eq('exceeds_21_days')
      end

      it 'falls back to base calculation when no custom conditions met' do
        allow(info_request).to receive(:has_interim_reply_without_final?).and_return(false)
        allow(info_request).to receive(:exceeds_target_time_without_explanation?).and_return(false)
        allow(info_request).to receive(:base_calculate_status).and_return('waiting_response')

        expect(info_request.theme_calculate_status).to eq('waiting_response')
      end
    end
  end

  describe 'Theme Configuration' do
    it 'theme name is set correctly' do
      expect(THEME_NAME).to be_defined
      expect(THEME_NAME).to be_a(String)
    end

    it 'theme has custom routes configured' do
      expect($alaveteli_route_extensions).to include('custom-routes.rb')
    end
  end

  describe 'View Customizations' do
    describe 'Help pages' do
      it 'has customized unhappy page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/unhappy.html.erb'))).to be true
      end

      it 'has customized requesting page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/requesting.html.erb'))).to be true
      end

      it 'has customized about page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/about.html.erb'))).to be true
      end

      it 'has new exemptions page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/exemptions.html.erb'))).to be true
      end

      it 'has new timelines page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/timelines.html.erb'))).to be true
      end

      it 'has new payments page' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/payments.html.erb'))).to be true
      end

      it 'has customized sidebar' do
        expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/lib/views/help/_sidebar.html.erb'))).to be true
      end
    end
  end

  describe 'Localization' do
    it 'has Traditional Chinese (Hong Kong) locale directory' do
      expect(Dir.exist?(Rails.root.join('lib/themes/alavetelitheme/locale-theme/zh_HK'))).to be true
    end

    it 'has Traditional Chinese translations file' do
      expect(File.exist?(Rails.root.join('lib/themes/alavetelitheme/locale-theme/zh_HK/app.po'))).to be true
    end

    it 'Traditional Chinese translations file is not empty' do
      content = File.read(Rails.root.join('lib/themes/alavetelitheme/locale-theme/zh_HK/app.po'))
      expect(content.length).to be > 1000  # Should have substantial content
    end

    it 'includes translations for custom statuses' do
      content = File.read(Rails.root.join('lib/themes/alavetelitheme/locale-theme/zh_HK/app.po'))
      expect(content).to include('內部覆核待處理')  # Internal review pending
      expect(content).to include('申訴專員')  # The Ombudsman
      expect(content).to include('公開資料守則')  # Code on Access to Information
    end
  end

  describe 'Model Patches' do
    describe 'RawEmail' do
      it 'RawEmail has data method patched' do
        expect(RawEmail.instance_methods).to include(:data)
      end
    end
  end

end
