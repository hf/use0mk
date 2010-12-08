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

class Use0MK::RedirectError < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end
end

class Use0MK::EmptyLinkError < StandardError
  attr_reader :message
  def initialize(message)
    @message = message
  end

  def status
    return 1
  end
end

class Use0MK::InvalidLinkError < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 2
  end
end

class Use0MK::InvalidFormatError < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 3
  end
end

class Use0MK::Invalidshort_nameError < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 4
  end
end

class Use0MK::InvalidAPIKey < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 5
  end
end

class Use0MK::InvalidCredentials < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 6
  end
end

class Use0MK::InvalidAPICall < StandardError
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def status
    return 7
  end
end

module Use0MK
  ERRORS = {
    1 => Use0MK::EmptyLinkError,
    2 => Use0MK::InvalidLinkError,
    3 => Use0MK::InvalidFormatError,
    4 => Use0MK::Invalidshort_nameError,
    5 => Use0MK::InvalidAPIKey,
    6 => Use0MK::InvalidCredentials,
    7 => Use0MK::InvalidAPICall
  }
end

class Use0MK::ShortenedURI
  attr_reader :origin
  attr_reader :long_uri
  attr_reader :short_uri
  attr_reader :short_name
  attr_reader :stats_uri
  attr_reader :title
  attr_reader :delete_uri
  attr_reader :delete_code

  def initialize(origin, attributes = {:long_uri => nil, :short_uri => nil, :short_name => nil, :stats_uri => nil, :title => nil, :delete_uri => nil, :delete_code => nil})

    if !(Use0MK::ORIGINS.member? origin)
      raise ArgumentError, "origin should be a member of Use0MK::ORIGINS"
    end

    @origin = origin

    @long_uri = attributes[:long_uri]
    @short_uri = attributes[:short_uri]
    @short_name = attributes[:short_name]
    @stats_uri = attributes[:stats_uri]
    @title = attributes[:title]
    @delete_uri = attributes[:delete_uri]
    @delete_code = attributes[:delete_code]
  end

  def delete
    if @origin == :preview
      return false
    end

    Use0MK::Interface.delete(@delete_uri, @delete_code)
  end
end

class Use0MK::Interface
  attr_accessor :username
  attr_accessor :apikey

  def initialize(username = nil, apikey = nil)
    @username = username
    @apikey = apikey
  end

  def self.delete(delete_uri, delete_code)
    delete_uri = URI.parse(delete_uri)

    response = Net::HTTP.post_form(delete_uri,
      {'brisiKod' => delete_code})

    case response
      when Net::HTTPSuccess
        return true # phew, that was hard work, that delete
      else
        response.error!
      end

    return false
  end

  def shorten(uri, short_name = nil)
    uri = URI.parse(uri)

    _shorten(uri, short_name)
  end

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
      raise Use0MK::ERRORS[json['greskaId']], json['greskaMsg'].to_s.strip
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

