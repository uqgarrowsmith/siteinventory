require 'google/api_client'
require 'date'
# Download development kit: http://rubyinstaller.org/downloads
# Installation steps: https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
require 'json'

class UQAnalytics
  include Utilities
  attr_accessor :data, :profileID, :profiles, :analytics, :client, :properties, :app_path, :ga_raw_json, :ga_json, :auth

  def initialize()
    @app_path = File.expand_path('.')

    @ga_raw_json = "data/UQ.json"
    @ga_json = "data/UQ.ordered.json"

    @API_VERSION = 'v3'
    @CACHED_API_FILE = "cache/analytics-#{@API_VERSION}.json"
    @auth = JSON.parse(File.read('conf/settings.json'))

    self.setClient
    @analytics = nil
    # Load cached discovered API, if it exists. 
    if File.exists? @CACHED_API_FILE
      File.open(@CACHED_API_FILE) do |file|
        @analytics = Marshal.load(file)
      end
    else
      @analytics = @client.discovered_api('analytics', @API_VERSION)
      File.open(@CACHED_API_FILE, 'w') do |file|
        Marshal.dump(@analytics, file)
      end
    end

    @properties = get_properties({ accountId: '~all', webPropertyId: '~all'}).items
    @profiles = get_profiles({ accountId: '~all', webPropertyId: '~all'}).items

  end

  def setClient
    analytics = @auth['analytics']
    service_account_email = analytics['service_account_email'] # Email of service account
    key_file = "privatekey.p12" # File containing your private key
    key_secret = 'notasecret' # Password to unlock private key

    @client = Google::APIClient.new(
      :application_name => 'Ruby Service Accounts sample',
      :application_version => '1.0.0')

            # Load our credentials for the service account
    key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)
    @client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => 'https://www.googleapis.com/auth/analytics.readonly',
      :issuer => service_account_email,
      :signing_key => key)

    # Request a token for our service account
    @client.authorization.fetch_access_token!
  end

  def get_properties(parameters)
    result = @client.execute(:api_method => @analytics.management.webproperties.list, :parameters => parameters)
    return result.data
  end

  def get_profiles(parameters)
    result = @client.execute(:api_method => @analytics.management.profiles.list, :parameters => parameters)
    return result.data
  end

  def get_data(parameters)
    # https://developers.google.com/analytics/devguides/reporting/core/v3/reference
    result = @client.execute(:api_method => @analytics.data.ga.get, :parameters => parameters)
    return result.data
  end

  def monthly_visits(id)
    startDate = DateTime.now.prev_month.strftime("%Y-%m-%d")
    endDate = DateTime.now.strftime("%Y-%m-%d")
    # https://developers.google.com/analytics/devguides/reporting/core/v3/reference
    parameters = {
      'ids' => 'ga:'+ id,
      'start-date' => (Date.today - 365).strftime("%Y-%m-%d"),
      'end-date' => Date.today.strftime("%Y-%m-%d"),
      'dimensions' => "ga:yearMonth",
      #'dimensions' => 'ga:pagePath',
      # 'metrics' => 'ga:pageviews',
      'metrics' => "ga:visits",
      'filters' => "ga:pagePath=~/",
    }

    visits = self.get_data(parameters)
  end

  def write_site_data
    result = {}
    @profiles.each_with_index do |profile, index|  #.first(10)

      visits = self.monthly_visits(profile.id)
      if visits['error']
        puts visits['error'].inspect
        exit
      end

      metrics = visits.rows.map {|visit|
        { visit[0] => visit[1] }
      }

      url = Utilities.url_permutations(profile.websiteUrl)
      if not result.key?(url)
        puts "#{index}. #{url} [#{profile.id}]..."  
        result[url] = { 
          'ga:profile_id' => profile.id, 
          'ga:visits' => metrics,
          'ga:total' => metrics.inject(0) {|sum, i|  sum + i.values[0].to_i }
        }
      else 
        puts "! duplicate for #{url} [#{result['ga:profile.id']}]..."  
      end
    end

    puts "Saving #{@ga_raw_json}"
    File.open(@ga_raw_json,"w") do |f|
      f.write(result.to_json)
    end

  end 

  def sort_by_visits
    file = File.read("data/UQ.json")
    sites = JSON.parse(file)

    sorted = Hash[sites.sort_by {|k,v|v['ga:total']}.reverse]

    File.open("data/UQ.ordered.json","w") do |f|
      f.write(sorted.to_json)
    end
  end  
end
