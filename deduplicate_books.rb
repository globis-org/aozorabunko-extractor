#!/usr/bin/env ruby

# 1. Removes the rows that do not match their 図書カードURL in 作品ID and 人物ID
# 2. Removes the rows with the same 'text' (first ones will be alive)

require 'json'
require 'optparse'

args = {
  in: '/dev/stdin',
  out: '/dev/stdout'
}
OptionParser.new do |opt|
  opt.on('--in FILE') { |v| args[:in] = v }
  opt.on('--out FILE') { |v| args[:out] = v }
  opt.parse!
end


text_to_meta = {}

File.open(args[:out], 'w') do |f|
  File.foreach(args[:in]).with_index do |line, i|
    row = JSON.load(line)
    meta = row['meta']
    card_url = meta['図書カードURL']
    match = card_url.match(/cards\/(\d+)\/card(\d+).html/)
    card_author_id = match[1]
    card_book_id = match[2]
    if meta['作品ID'].end_with?(card_book_id) && meta['人物ID'] == card_author_id
      if text_to_meta.key? row['text']
        STDERR.puts "ignoring #{meta['作品ID']}:#{meta['作品名']} because the 'text' field is duplicated"
      else
        text_to_meta[row['text']] = meta
        f.puts line
      end
    else
      STDERR.puts "ignoring #{meta['作品ID']}:#{meta['作品名']} by #{meta['人物ID']}:#{meta['姓']}#{meta['名']} (#{card_url})"
    end

    STDERR.write "Progress: #{i}\r"
  end
end
