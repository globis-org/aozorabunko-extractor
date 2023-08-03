#!/usr/bin/env ruby

require 'json'
require 'optparse'

UTTERANCE_LINE_PATTERN = /^[[:space:]]?「([^」]+)」$/

args = {
  in: '/dev/stdin',
  out: '/dev/stdout'
}
OptionParser.new do |opt|
  opt.on('--in FILE') { |v| args[:in] = v }
  opt.on('--out FILE') { |v| args[:out] = v }
  opt.parse!
end

File.open(args[:out], 'w') do |f|
  File.foreach(args[:in]).with_index do |json_line, i|
    row = JSON.load(json_line)
    text = row['text']
    footnote = row['footnote']
    meta = row['meta']

    chats = []
    current_chat = nil
    text.lines.each.with_index do |line, n|
      match = line.match UTTERANCE_LINE_PATTERN
      if match
        current_chat ||= []
        current_chat << match[1]
      elsif current_chat
        chats << current_chat if current_chat.length >= 2
        current_chat = nil
      end
    end
    if current_chat
      chats << current_chat if current_chat.length >= 2
    end

    STDERR.write "Progress: #{i}\r"

    if chats.length > 0
      new_row = { chats: chats, footnote: footnote, meta: meta }
      json = JSON.dump new_row
      f.puts json
    end
  end
end
