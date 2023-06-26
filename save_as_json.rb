#!/usr/bin/env ruby

require 'csv'
require 'json'
require 'open-uri'
require 'optparse'
require 'zip'
require 'ruby-progressbar'

AOZORA_INDEX_URL = 'https://www.aozora.gr.jp/index_pages/list_person_all_extended_utf8.zip'
AOZORA_INDEX_FILENAME = 'list_person_all_extended_utf8.csv'
AOZORA_INDEX_ENCODING = Encoding::UTF_8
AOZORA_URL_PATTERN = /https:\/\/www.aozora.gr.jp\/cards\/(\d+)\/files\/(\d+_\w+(_\d+)?)/
AOZORA_PATH = 'aozorabunko_text/cards/%<author_id>s/files/%<file_id>s/%<file_id>s.txt'
ENCODING_MAPPING = { 'ShiftJIS' => Encoding::CP932, 'UTF-8' => Encoding::UTF_8 }

args = {
  public: false,
  out: '/dev/stdout'
}
OptionParser.new do |opt|
  opt.on('--public') { |_| args[:public] = true }
  opt.on('--out FILE') { |v| args[:out] = v }
  opt.parse!
end

aozora_index = URI.open(AOZORA_INDEX_URL) { |f|
  Zip::File.open(f) { |zipfile|
    entry = zipfile.find_entry AOZORA_INDEX_FILENAME
    # Is there any method in the CSV module to open the stream directly?
    entry_content = entry.get_input_stream.read.force_encoding AOZORA_INDEX_ENCODING
    if entry_content[0] == "\uFEFF"
      # Remove BOM character
      entry_content.slice! 0
    end
    CSV.parse entry_content, headers: true
  }
}

File.open(args[:out], 'w') do |f|
  pb = ProgressBar.create total: aozora_index.length,
                          output: STDERR,
                          format: '%t: |%B|%c/%u|%j%%|%E'
  aozora_index.each do |row|
    pb.increment

    next if row["テキストファイルURL"].empty?
    next if args[:public] && (row['人物著作権フラグ'] == 'あり' || row['作品著作権フラグ'] == 'あり')

    path_match = row["テキストファイルURL"].match AOZORA_URL_PATTERN
    next if not path_match

    path = format AOZORA_PATH, file_id: path_match[2], author_id: path_match[1]
    encoding = ENCODING_MAPPING[row['テキストファイル符号化方式']]
    if File.exist? path
      text = File.read path, encoding: encoding
    else
      # aozorabunko_text is sometimes old; get up-to-date text
      text = URI.open(row["テキストファイルURL"]) { |f|
        ret = nil
        open_method = f.is_a?(StringIO) ? :open_buffer : :open
        Zip::File.public_send(open_method, f) do |zipfile|
          text_entries = zipfile.glob '**/*.[tT][xX][tT]'
          if text_entries.length != 1
            raise ".txt file cannot be identified: #{row["テキストファイルURL"]}"
          end
          entry = text_entries.first
          raw_text = entry.get_input_stream.read
          ret = raw_text.force_encoding encoding
        end
        ret
      }
    end

    data = row.to_h
    data['テキスト'] = text
    json = JSON.dump data
    f.puts json
  end
  pb.finish
end
