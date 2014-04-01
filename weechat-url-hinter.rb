#
# Copyright (c) 2014 Kengo Tateishi <embrace.ddd.flake.peace@gmail.com>
# https://github.com/tkengo/weechat-url-hinter
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# ---------------------------------------------------------------------
#
# Url hinter is a plugin that open a url in weehcat buffer without
# touching mouse.
#
# Usage
# 1. Type '/url_hinter' command on the input buffer of Weechat.
# 2. Then, this plugin searches url strings such as 'http://...' or
#    'https://...'
# 3. If urls are found, they are highlighted and give hint key to
#    the url.
# 4. When you type a hint key, open the url related to hint key
#    in your default browser.
#

require 'singleton'

#
# Register url-hinter plugin to weechat and do initialization.
#
def weechat_init
  Weechat.register('url_hinter', 'Kengo Tateish', '0.1', 'GPL3', 'Open an url in the weechat buffer to type a hint', '', '')
  Weechat.hook_command('url_hinter', 'Search url strings, and highlight them, and if you type a hint key, open the url related to hint key.', 'continuous', 'continuous | Continue hint mode even if selected url is opend.', '', 'launch_url_hinter', '');
  Weechat::WEECHAT_RC_OK
end

#
# Callback method that invoked when input text in buffer was changed.
# Search url by the input text from Hint. If a url is found, open it.
#
def open_hint_url(data, signal, buffer_pointer)
  buffer = Buffer.new(buffer_pointer)
  text = buffer.input_text

  if Hint.instance.has_key?(text)
    Hint.instance.reserve(text)
    buffer.input_text = ''

    unless GlobalResource.continuous
      Hint.instance.open_all_url
      reset_hint_mode
    end
  end

  Weechat::WEECHAT_RC_OK
end

#
# Launch url-hinter.
#
# Type '/url_hinter' on the input buffer of Weechat, and then this plugin searches
# strings like 'http://...' or 'https://...' in the current buffer and highlights it.
#
def launch_url_hinter(data, buffer_pointer, argv)
  buffer = Buffer.new(buffer_pointer)

  if Hint.instance.any?
    Hint.instance.open_all_url
    reset_hint_mode
    return Weechat::WEECHAT_RC_OK
  end

  return Weechat::WEECHAT_RC_OK unless buffer.has_url_in_display?

  Hint.instance.set_target(buffer)

  messages = {}
  buffer.own_lines.each do |line|
    messages[line.data_pointer] = line.message.dup
    new_message = line.remove_color_message
    line.urls.each do |url|
      hint_key = "[#{Hint.instance.add(url, line)}]"
      new_message.gsub!(url, Color.yellow + hint_key + Color.red + url[hint_key.length..-1].to_s + Color.blue)
    end
    line.message = Color.blue + new_message + Color.reset
  end

  GlobalResource.messages = messages
  GlobalResource.continuous = argv == 'continuous'
  GlobalResource.hook_pointer = Weechat.hook_signal('input_text_changed', 'open_hint_url', '')
  Weechat::WEECHAT_RC_OK
end

#
# Clear hints and reset hook.
#
def reset_hint_mode
  Hint.instance.clear
  GlobalResource.messages.each {|pointer, message| Weechat.hdata_update(Weechat.hdata_get('line_data'), pointer, { 'message' => message }) }
  Weechat.unhook(GlobalResource.hook_pointer)
end

#----------------------------
# Custome classes
#----------------------------

HINT_KEYS = 'jfhkgyuiopqwertnmzxcvblasd'

class Hint
  include Singleton

  def initialize
    clear
  end

  def set_target(buffer)
    @buffer = buffer
    @url_count = @buffer.url_count
  end

  def clear
    @urls = {}
    @open_target_urls = []
    @lines = {}
    @hint_key_index = 0
  end

  def any?
    @urls.any?
  end

  def add(url, line)
    hint_key = next_hint_key
    @urls[hint_key] = url
    @lines[hint_key] = line
    hint_key
  end

  def reserve(key)
    line = @lines.delete(key)
    line.message = line.message(hdata: true).gsub("[#{key}]", "[#{'*' * key.length}]")
    @open_target_urls << @urls.delete(key)
  end

  def open_all_url
    Weechat.hook_process("open #{@open_target_urls.join(' ')}", 10000, '', '') if @open_target_urls.any?
  end

  def has_key?(key)
    @urls.has_key?(key)
  end

  private

  def next_hint_key
    if @url_count > HINT_KEYS.length
      key1 = HINT_KEYS[@hint_key_index / HINT_KEYS.length]
      key2 = HINT_KEYS[@hint_key_index % HINT_KEYS.length]
      hint_key = key1 + key2
    else
      hint_key = HINT_KEYS[@hint_key_index]
    end

    @hint_key_index += 1
    hint_key
  end
end

class GlobalResource
  class << self
    attr_accessor :hook_pointer, :messages, :continuous
  end
end

#----------------------------
# Wrapper of weechat objects.
#----------------------------

#
# Wrapper of weechat color object.
#
class Color
  class << self
    def method_missing(method_name)
      Weechat.color(method_name.to_s)
    end
  end
end

#
# Wrapper of weechat hdata window.
#
class Window
  class << self
    def current
      Window.new(Weechat.current_window)
    end
  end

  def initialize(pointer)
    @pointer = pointer
  end

  def chat_height
    Weechat.hdata_integer(Weechat.hdata_get('window'), @pointer, 'win_chat_height')
  end
end

#
# Wrapper of weechat hdata buffer.
#
class Buffer
  def initialize(pointer)
    @pointer = pointer
  end

  def own_lines
    own_lines_pointer = Weechat.hdata_pointer(Weechat.hdata_get('buffer'), @pointer, 'own_lines')
    @own_lines ||= Lines.new(own_lines_pointer)
  end

  def input_text
    Weechat.buffer_get_string(@pointer, 'input')
  end

  def input_text=(text)
    Weechat.buffer_set(@pointer, 'input', text)
  end

  def url_count
    own_lines.inject(0){|result, line| result + line.urls.count }
  end

  def has_url_in_display?
    !own_lines.find(&:has_url?).nil?
  end
end

#
# Wrapper of weechat hdata lines.
#
class Lines
  include Enumerable

  def initialize(pointer)
    @pointer = pointer
  end

  def first_line
    first_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('lines'), @pointer, 'first_line')
    Line.new(first_line_pointer)
  end

  def last_line
    last_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('lines'), @pointer, 'last_line')
    Line.new(last_line_pointer)
  end

  def count
    Weechat.hdata_integer(Weechat.hdata_get('lines'), @pointer, 'lines_count')
  end

  def each
    window_height = Window.current.chat_height
    line          = last_line
    index         = 0

    while true
      yield(line)

      index += 1 if line.displayed?
      break if !(line = line.prev) || index >= window_height
    end
  end
end

#
# Wrapper of weechat hdata line and line_data.
#
class Line
  attr_reader :data_pointer

  def initialize(pointer)
    @pointer = pointer
    @data_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'data')
  end

  def message(options = {})
    if options[:hdata]
      @message = Weechat.hdata_string(Weechat.hdata_get('line_data'), @data_pointer, 'message').to_s
    else
      @message ||= Weechat.hdata_string(Weechat.hdata_get('line_data'), @data_pointer, 'message').to_s
    end
  end

  def message=(new_message)
    Weechat.hdata_update(Weechat.hdata_get('line_data'), @data_pointer, { 'message' => new_message })
  end

  def remove_color_message
    Weechat.string_remove_color(message.dup, '')
  end

  def next
    next_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'next_line')
    Line.new(next_line_pointer) unless next_line_pointer.to_s.empty?
  end

  def prev
    prev_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'prev_line')
    Line.new(prev_line_pointer) unless prev_line_pointer.to_s.empty?
  end

  def displayed?
    Weechat.hdata_char(Weechat.hdata_get('line_data'), @data_pointer, 'displayed').to_s == '1'
  end

  def has_url?
    !/https?:\/\/[^ 　\(\)\r\n]*/.match(remove_color_message).nil?
  end

  def urls
    remove_color_message.scan(/https?:\/\/[^ 　\(\)\r\n]*/).uniq
  end
end
