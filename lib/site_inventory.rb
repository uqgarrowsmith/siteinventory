require 'grabzit'
require "rubygems"
require "google_drive"
require "csv"
require "json"

class Site
  include Utilities
  attr_accessor :id, :url, :name, :tier, :cms, :unit_type, :tag, :branding, :portfolio, :owner, :analytics, :img

  @@img_ext = 'jpg'

  def initialize(id = nil, url = '', name = '', tier = '5:Not applicable', cms = '', unit_type = '', tag = [], branding = 'untagged', portfolio = '', owner = '')
    url = nil if url == 'Website not listed in UQ ORG'
    name = url if name.to_s.empty? == true
    @id, @url, @name, @tier, @cms, @unit_type, @tag, @branding, @portfolio, @owner = id, url, name, tier, cms, unit_type, tag, branding, portfolio, owner
    @analytics = { 
      'ga:total' => 0, 
      'ga:visits' => [], 
      'ga:profile_id' => ''
    }
  end

  def slug(thing)
    thing.to_s.downcase.strip.gsub(' ', '-').gsub(/[^a-z]/i, '')
  end

  def unit_type
    if @unit_type.to_s.empty?
      return 'untagged'
    else
      return @unit_type
    end
  end 

  def branding
    if @branding.to_s.empty?
      return 'untagged'
    else
      return @branding
    end
  end 

  def <=>(other)
    self.analytics['ga:total'].to_i <=> other.analytics['ga:total'].to_i
  end

  def img_filepath
    "report/images/#{self.filename}.#{@@img_ext}"
  end

  def to_h
    site = {
      :id => self.id,
      :url => self.http_url,
      :title => self.name,
      :img => self.img_filepath,
      :portfolio => self.slug(self.portfolio),
      :owner => self.slug(self.owner),
      :tier => self.slug(self.tier),
      :cms => self.slug(self.cms),            
      :tag => self.slug(self.tag),
      :branding => self.slug(self.branding),
      :unit_type => self.slug(self.unit_type),
      :is_website => self.is_a_website,
      :ga => { 
          :total => self.analytics['ga:total'],
          :visits => self.analytics['ga:visits']
      }
    }
  end

  def filename
    return Utilities.sanitize_filename(self.url)
  end

  def www_url
    return "http://www.#{self.url}"
  end 

  def http_url
    return "http://#{self.url}"
  end

  def is_uq
    if @branding == 'UQ' || @branding == 'Custom UQ' then true else false end
  end  

  def is_valid
    if @url.to_s.empty? then false else true end
  end

  def is_a_website
    bad_tiers = ['5:not applicable','0:unclassified']
    bad_tags = ['alias','404','development','archive', 'intranet']
    bad_cms = [] #['static pages','other']
    if bad_tiers.include?(@tier.downcase) || bad_tags.include?(@tag.downcase) || bad_cms.include?(@cms.downcase)
      return false
    else
      return true
    end
  end

end  

class SiteInventory
  include Utilities
  attr_accessor :csv, :sites, :urls, :grab_exension, :report, :csv, :spreadsheet, :ga_json, :app_path, :ga_raw_json, :auth, :tags

  def initialize
    @app_path = File.expand_path('.')
    @auth = JSON.parse(File.read("#{@app_path}/config/settings.json"))
    grabzit = @auth['grabzit']
    @@grabber = GrabzIt::Client.new(grabzit['username'], grabzit['password'])
    @spreadsheet = '********************' 
    @grab_exension = 'jpg'
    @report = "#{@app_path}/report/screenshots.html"

    data_path =  "#{@app_path}/data"
    @csv = "#{data_path}/Site Inventory Master - Master domains.csv"
    @ga_raw_json = "#{data_path}/UQ.json"
    @ga_json = "#{data_path}/UQ.ordered.json"
    @sites = []
    self.import_sites if File.file?(@csv)
  end

  def update_csv
    if File.file?(@csv) then 
      puts "deleting csv"
      File.delete(@csv) 
    else
      puts "missing #{@csv}"
    end
    if not File.file?(@csv)
      google_drive = @auth['google_drive']
      session = GoogleDrive.login(google_drive['username'], google_drive['password'])
      ss = session.spreadsheet_by_key(google_drive['spreadsheet'])
      ss.export_as_file(@csv, 'csv', 0)
      puts "downloaded #{@csv}"
    else
      puts "Error could not update #{@csv}"
    end
  end

  def report
    puts "Total urls evaluated: #{@sites.length}"
    length = 0
    @sites.each{|site| length+=1 if site.is_a_website}
    puts "Total websites: #{length}"
  end

  def get_filtered_sites
  	@sites.map { |site| 
  		site if site.is_a_website == true
  	}
  end
  
  def export_to_json
    data = []
    
    @taxonomy = { 
      'branding' => {},
      'cms' => {},
      'tier' => {},
      'unit_type' => {},
      'portfolio' => {}
    }
    
    @sites.each do |site, index|
      if site.is_a_website
        if File.file?(site.img_filepath)
          @taxonomy['branding'].merge!(site.slug(site.branding) => site.branding ) unless @taxonomy['branding'].value?(site.branding)
          @taxonomy['cms'].merge!(site.slug(site.cms) => site.cms ) unless @taxonomy['cms'].value?(site.cms)
          @taxonomy['tier'].merge!(site.slug(site.tier) => site.tier ) unless @taxonomy['tier'].value?(site.tier)
          @taxonomy['unit_type'].merge!(site.slug(site.unit_type) => site.unit_type ) unless @taxonomy['unit_type'].value?(site.unit_type)
          @taxonomy['portfolio'].merge!(site.slug(site.portfolio) => site.portfolio ) unless @taxonomy['portfolio'].value?(site.portfolio)
          data << site.to_h
        end
      end
    end
    
    site_output = {
      :sites => data,
      :total => { 
        :sites => data.length,
        :urls => @sites.length
      }
    }
    
    File.open('report/data/sites.json', 'w') {|f| f.write(site_output.to_json)}
    puts "Saved report/data/sites.json"
    File.open('report/data/taxonomy.json', 'w') {|f| f.write(@taxonomy.to_json)}
    puts "Saved report/data/taxonomy.json"
  end

  def import_sites
    skipped = 0
    CSV.foreach(@csv, :headers => true) do |r|
      site = Site.new($., r['RAW URL'], r['Site name'], r['Tier'], r['CMS'], r['Unit Type'], r['Tags'], r['Branding'], r['Portfolio'], r['Owner'])
      if site.is_valid == true
        @sites << site 
      else 
        skipped += 1
      end
    end
    puts "Import CSV Complete. Skipped #{skipped} invalid rows"
  end

  def merge_analytics
    puts "Loading Google Analytics data: #{ga_json}"
    if File.exists?(@ga_json)
      file = File.read(@ga_json)
      puts "Parsing #{ga_json}"
      analytics = JSON.parse(file)
      puts analytics.first.inspect
      no_match = {'sites' => [], 'other' => []}
      puts "Extending inventory with GA data"
      @sites.each do |site|
        if analytics.key?(site.url) 
          puts "Matching #{site.url}"
          site.analytics["ga:total"] = analytics[site.url]["ga:total"] 
          site.analytics["ga:visits"] = analytics[site.url]["ga:visits"]
          analytics.delete(site.url)
        else
          if site.is_a_website == true
            no_match['sites'] << site.url if not no_match['sites'].include?(site.url)
          else
            no_match['other'] << site.url if not no_match['other'].include?(site.url)
          end
        end
      end

      puts "Dumping report of sites with no GA data to data/no_analytics.json"
      File.open('data/no_analytics.json',"w") do |f|
        f.write(no_match.to_json)
      end
    else  
      puts "Error: file #{ga_json} missing. Run analytics.write_site_data first. Exiting"
    end 
  end

  def get_screengrabs
  	@sites.each do |site| 
      next if not site.is_valid
      next if not site.is_a_website
  		filename = Utilities.sanitize_filename(site.url)
      result = self.grab(site.www_url, site.img_filepath)
      case result
      when 'saved'
      when 'exists'
      else 
        puts "! error: #{result} #{site.www_url}"
        result = self.grab(site.http_url, site.img_filepath)
      end
  	end
    self.report
  end

  def grab(url, filepath)  
		if not File.file?(filepath)
			begin
    		width = 200
    		height = 150
			  @@grabber.set_image_options(url, nil, nil, nil, width, height, 'jpg', nil)
				@@grabber.save_to(filepath)
			rescue GrabzIt::GrabzItException => e 
				return e.code
			else 
        puts "+ saved #{filepath}"        
				return 'saved'
			end	
		else
      puts "= #{filepath} exists"
			return 'exists'
		end
  end

end