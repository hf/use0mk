#
#  Copyright (c) 2010 Stojan Dimitrovski <s.dimitrovski@gmail.com>
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#
require "rubygems"
require "net/http"
require "json"

module Use0MK
  SHORTEN_URI = "http://api.0.mk/v2/skrati"
  PREVIEW_URI = "http://api.0.mk/v2/pregled"
  ORIGINS = [:shorten, :preview]

  # ERRORS defined below
end

# Standard error class concerning {Use0MK} errors.
class Use0MK::Error < StandardError
  # the message returned by 0.mk
  # @return [String]
  attr_reader :message
  # the status ID for the error
  # @return [Integer]
  attr_reader :status
end

# Too many redirects while attempting an API call.
#
# *status*: 100
class Use0MK::RedirectError < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 100
  end
end

# Provided link (any URI concerning any API call) was empty.
#
# *status*: 1
class Use0MK::EmptyLinkError < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 1
  end
end

# Provided link (any URI concerning any API call) was invalid.
#
# *status*: 2
class Use0MK::InvalidLinkError < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 2
  end
end

# Provided format parameter was invalid. Probably an internal error.
#
# *status*: 3
class Use0MK::InvalidFormatError < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 3
  end
end

# Provided (custom) short name was invalid.
#
# *status*: 4
class Use0MK::InvalidShortNameError < Use0MK::Error
 def initialize(message)
    @message = message
    @status = 4
  end
end

# Provided API key was invalid.
#
# *status*: 5
class Use0MK::InvalidAPIKey < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 5
  end
end

# Provided credentials were invalid.
#
# *status*: 6
class Use0MK::InvalidCredentials < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 6
  end
end

# API call not supported by 0.mk. Check {Use0MK::SHORTEN_URI} and
# {Use0MK::PREVIEW_URI} to see which API is being used. Probably an
# internal error.
#
# *status*: 7
class Use0MK::InvalidAPICall < Use0MK::Error
  def initialize(message)
    @message = message
    @status = 7
  end
end

module Use0MK
  APIERRORS = [
    Use0MK::EmptyLinkError,
    Use0MK::InvalidLinkError,
    Use0MK::InvalidFormatError,
    Use0MK::InvalidShortNameError,
    Use0MK::InvalidAPIKey,
    Use0MK::InvalidCredentials,
    Use0MK::InvalidAPICall
  ]
end

# Represents a shortened URI from 0.mk. It contains only the information
# retrieved by the API call to 0.mk. The volume of information with any
# API call is not consistent therefore any attribute of this class that
# is +nil+ or +empty+ should be ignored.
#
# The origin (the API call which generated the object of this class)
# of this object can be tracked with the +origin+ attribute. The origin
# is a Symbol which is a member of {Use0MK::ORIGINS}.
#
# It is not a good idea to create instances of this class by hand, as
# it contains only data available from API calls to 0.mk.
#
class Use0MK::ShortenedURI
  # a member of {Use0MK::ORIGINS}
  # @return [Symbol]
  attr_reader :origin
  # the long URI
  # @return [String, nil]
  attr_reader :long_uri
  # the shortened URI
  # @return [String, nil]
  attr_reader :short_uri
  # the short name (+http://0.mk/short_name+)
  # @return [String, nil]
  attr_reader :short_name
  # the stats URI
  # @return [String, nil]
  attr_reader :stats_uri
  # the document title of the long URI
  # @return [String, nil]
  attr_reader :title
  # the deletion URI
  # @return [String, nil]
  attr_reader :delete_uri
  # the deletion code
  # @return [String, nil]
  attr_reader :delete_code
  # whether this URI is deleted
  # @return [true, false]
  attr_reader :deleted

  # Initializes this class. Usually called from either +shorten+ or +preview+.
  #
  # @param [Symbol] origin origin of this class (which API call created it), a member of {Use0MK::ORIGINS}
  # @param [Hash] attributes hash of the attributes needed to create the object
  def initialize(origin, attributes = {})

    if !(Use0MK::ORIGINS.member? origin)
      raise ArgumentError, "origin should be a member of Use0MK::ORIGINS"
    end

    @origin = origin
    @deleted = @origin != :shorten

    @long_uri = attributes[:long_uri]
    @short_uri = attributes[:short_uri]
    @short_name = attributes[:short_name]
    @stats_uri = attributes[:stats_uri]
    @title = attributes[:title]
    @delete_uri = attributes[:delete_uri]
    @delete_code = attributes[:delete_code]
  end

  # Deletes the shortened URI.
  # This method calls {Use0MK::Interface.delete} internally.
  #
  # @return [true, false] wheter deletion succeeds (usually +true+ when +origin+ is +:shorten+)
  def delete
    if @deleted
      return false
    end

    @deleted = Use0MK::Interface.delete(@delete_uri, @delete_code)
  end
end

# This class represents the main interface through which one can operate on
# the 0.mk API.
class Use0MK::Interface
  # the username associated with 0.mk
  # @return [String, nil]
  attr_accessor :username
  # the API key for 0.mk
  # @return [String, nil]
  attr_accessor :apikey

  # Initializes the {Use0MK::Interface}.
  #
  # @param [String] username 0.mk username
  # @param [String] apikey 0.mk API key
  def initialize(username = nil, apikey = nil)
    @username = username
    @apikey = apikey
  end

  # Deletes a shortened URI from 0.mk.
  # This method does not raise or handles any exceptions. It also does not
  # handle redirection.
  #
  # @param [String] delete_uri the 0.mk URI to delete
  # @param [String] delete_code the 0.mk delete code associated with the 0.mk URI
  # @return [true, false] wheter the delete succeeded
  def self.delete(delete_uri, delete_code)
    delete_uri = URI.parse(delete_uri)

    response = Net::HTTP.post_form(delete_uri,
      {'brisiKod' => delete_code})

    case response
      when Net::HTTPSuccess
        return true # phew, that was hard work, that delete
      end

    return false
  end

  # Shortens a URI.
  # This method can raise several exceptions of which most importantly:
  # * {URI::Error}
  # * {Net::HTTPException}
  # * {Use0MK::Error}
  #
  # It is a wise thing to watch for any of those exceptions.
  #
  # @param [String] uri the _long_ URI to shorten
  # @param [String] short_name a custom short name to use when shortening the long URI (+http://0.mk/short_name+)
  # @return [Use0MK::ShortenedURI] the shortened URI
  def shorten(uri, short_name = nil)
    uri = URI.parse(uri)

    _shorten(uri, short_name)
  end

  # Inspects an already shortened URI.
  # This method can raise several exceptions of which most importantly:
  # * {URI::Error}
  # * {Net::HTTPException}
  # * {Use0MK::Error}
  #
  # It is a wise idea to watch for any of these.
  #
  # @param [Hash] link provide +:short_name+ to inspect only the short name of an URI, or +:uri+ to inspect a whole +http://0.mk/short_name+ URI
  # @return [Use0MK::ShortenedURI] the shortened URI (volume of data varies)
  def preview(link = {:short_name => nil, :uri => nil})
    uri = nil

    if !link[:short_name].nil? and !link[:short_name].empty?
      uri = "http://0.mk/#{link[:short_name]}"
    elsif !link[:uri].nil? and !link[:uri].empty?
      uri = link[:uri] if (link[:uri] =~ /http:\/\/0\.mk\/.*/)
    end

    if uri.nil?
      raise ArgumentError, ':uri should be a valid http://0.mk shortened URI.'
    end

    _preview(uri)
  end

  private
  def _queryize(hash = {})
    pairs = []

    hash.each do |key, value|
      if !(key.nil? or value.nil?)
        pairs << key.to_s.strip + "=" + value.to_s.strip
      end
    end

    return pairs.join("&")
  end

  def _generate_uri(link, short_name = nil, apicall = Use0MK::SHORTEN_URI)
    uri = URI.parse(apicall)

    query = {
      :korisnik => @username,
      :apikey => @apikey,
      :format => 'json',
      :nastavka => short_name
    }

    uri.query = _queryize(query) + "&link=#{link}"

    return uri
  end

  def _fetch(uri, link, redirect = 5)
    raise Use0MK::RedirectError, "Redirect level too deep (max 5)." if redirect <= 0

    response = Net::HTTP.get_response(uri)
    case response
      when Net::HTTPSuccess then return response
      when Net::HTTPRedirection then _fetch(response['location'], redirect - 1)
      else
        response.error!
      end

  end

  def _parse(origin, json)
    if json['status'] != 1
      raise Use0MK::APIERRORS[json['greskaId'].to_i - 1], json['greskaMsg'].to_s.strip
    end

    assign = {
      'dolg' => :long_uri,
      'kratok' => :short_uri,
      'nastavka' => :short_name,
      'urlNaslov' => :title,
      'statsLink' => :stats_uri,
      'brisiLink' => :delete_uri,
      'brisiKod' => :delete_code
    }

    attributes = {}
    json.each do |key, value|
      if assign.has_key? key
        attributes[assign[key]] = value
      end
    end

    assign.keys.each do |key|
      if !attributes.has_key? key
        attributes[key] = nil
      end
    end

    shortened = Use0MK::ShortenedURI.new(origin, attributes)
  end

  def _shorten(uri, short_name)
    request_uri = _generate_uri(uri, short_name)

    response = _fetch(request_uri, uri)
    body = JSON.parse(response.body)

    _parse(:shorten, body)
  end

  def _preview(uri)
    request_uri = _generate_uri(uri, nil, Use0MK::PREVIEW_URI)

    response = _fetch(request_uri, uri)
    body = JSON.parse(response.body)

    _parse(:preview, body)
  end


end

