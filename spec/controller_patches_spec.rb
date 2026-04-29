require File.expand_path(
  File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec', 'spec_helper')
)

RSpec.describe RequestController, "show action with HK deadline patches" do
  render_views

  before do
    load_raw_emails_data
  end

  context "for a request awaiting response" do
    it "sets HK deadline instance variables" do
      info_request = FactoryBot.create(:info_request)
      get :show, params: { url_title: info_request.url_title }
      expect(response).to be_successful
      expect(assigns[:hk_deadlines]).to be_a(Hash)
      expect(assigns[:hk_deadlines]).to have_key(:initial_response)
      expect(assigns[:hk_deadlines]).to have_key(:target_completion)
      expect(assigns[:hk_deadlines]).to have_key(:maximum_time)
      expect(assigns[:hk_days_elapsed]).to be_a(Integer)
      expect(assigns[:hk_deadline_message]).to be_a(String)
    end
  end

  context "for a successful request" do
    it "does not set HK deadline instance variables" do
      info_request = FactoryBot.create(:info_request, :successful)
      get :show, params: { url_title: info_request.url_title }
      expect(response).to be_successful
      expect(assigns[:hk_deadlines]).to be_nil
    end
  end

  context "for a request older than 51 days" do
    it "adds a flash warning about exceeding maximum deadline" do
      info_request = FactoryBot.create(:info_request,
                                       created_at: 55.days.ago)
      get :show, params: { url_title: info_request.url_title }
      expect(response).to be_successful
      expect(flash[:warning]).to include('51 calendar day maximum')
    end
  end

  context "for a request older than 21 days" do
    it "adds a flash notice about exceeding target" do
      info_request = FactoryBot.create(:info_request,
                                       created_at: 25.days.ago)
      get :show, params: { url_title: info_request.url_title }
      expect(response).to be_successful
      expect(flash[:notice]).to include('21 calendar day target')
    end
  end
end

RSpec.describe ApplicationController, "HK deadline helper methods" do
  controller do
    def index
      render plain: 'ok'
    end
  end

  describe '#hk_calculate_deadlines' do
    it 'returns hash with three deadline dates' do
      created = Time.zone.now - 5.days
      result = controller.send(:hk_calculate_deadlines, created)
      expect(result[:initial_response]).to be_within(1.second).of(created + 10.days)
      expect(result[:target_completion]).to be_within(1.second).of(created + 21.days)
      expect(result[:maximum_time]).to be_within(1.second).of(created + 51.days)
    end
  end

  describe '#hk_deadline_status_class' do
    it 'returns ok for requests under 10 days' do
      expect(controller.send(:hk_deadline_status_class, 5.days.ago)).to eq('hk-deadline-ok')
    end

    it 'returns approaching for 11-21 days' do
      expect(controller.send(:hk_deadline_status_class, 15.days.ago)).to eq('hk-deadline-approaching')
    end

    it 'returns overdue for 22-51 days' do
      expect(controller.send(:hk_deadline_status_class, 30.days.ago)).to eq('hk-deadline-overdue')
    end

    it 'returns significantly-overdue for 52+ days' do
      expect(controller.send(:hk_deadline_status_class, 60.days.ago)).to eq('hk-deadline-significantly-overdue')
    end
  end
end
