#!/usr/bin/env python

import

class Interface():
  username = None
  apikey = None

  def delete(delete_uri, delete_code):
    pass

  def __init__(self, username = None, apikey = None):
    self.username = username
    self.apikey = apikey

  def shorten(self, uri):
    pass

  def preview(self, uri_or_shortname):
    pass

