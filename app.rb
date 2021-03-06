require "./lib/utilities.rb"
require "./lib/site_inventory.rb"
require "./lib/analytics.rb"

ENV['SSL_CERT_FILE'] = File.join(File.dirname(__FILE__),"config/cacert.pem")
#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE 

inventory = SiteInventory.new()
analytics = UQAnalytics.new()

case ARGV[0]
when "update"
  STDOUT.puts "updating inventory csv"
  inventory.update_csv
  STDOUT.puts "updating screenshots"
  inventory.get_screengrabs
when "test"
  STDOUT.puts "write sites to json"
  inventory.export_to_json
when "analytics"
  STDOUT.puts "updating analytics"
  analytics.write_site_data
  analytics.sort_by_visits
when "report"
  STDOUT.puts "writing html report"
  inventory.merge_analytics
  inventory.export_to_json
when "grab"
  STDOUT.puts "fetching screenshots"
  inventory.get_screengrabs  
else
  STDOUT.puts <<-EOF
Please provide a command
Usage:
  app update
  app analytics
  app report  
  app grab
EOF
end


# docs: http://gimite.net/doc/google-drive-ruby
# OAuth: GoogleDrive.login_with_oauth for details.
#
# # First worksheet of https://docs.google.com/spreadsheet/ccc?key=pz7XtlQC-PYx-jrVMJErTcg