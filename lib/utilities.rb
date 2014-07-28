require 'date'
require 'json/pure'

module Utilities
  extend self

  def url_permutations(url)
    url, params = url.split("?")
    # without_trailing_slash, with www
    a = url.gsub(/\/$/, "").gsub(/http(s)?:\/\/([^\/]+)/) do |match|
      protocol = "http#{$1.to_s}"
      domain = $2
      domain = "www.#{domain}" if domain.split(".").length < 3 # www.google.com == 3, google.com == 2
      "#{protocol}://#{domain}"
    end
    # with_trailing_slash, with www
    b = "#{a}/"
    # without_trailing_slash, without www
    c = a.gsub(/http(s)?:\/\/www\./, "http#{$1.to_s}://")
    # with_trailing_slash, without www
    d = "#{c}/"
    return c.gsub(/http(s)?:\/\//, "")
    #[a, b, c, d].map { |url| "#{url}"}
  end

  def sanitize_filename(filename)
   filename.gsub(/[^a-z0-9\-\.]+/i, '_')
  end

end