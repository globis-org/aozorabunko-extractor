#!/usr/bin/env ruby

require 'json'
require 'optparse'

JIS_TO_LIGATURES = {
  '1-5-87' => 'カ゚',
  '1-5-88' => 'キ゚',
  '1-5-89' => 'ク゚',
  '1-5-90' => 'ケ゚',
  '1-5-91' => 'コ゚',
  '1-5-92' => 'セ゚',
  '1-5-93' => 'ツ゚',
  '1-5-94' => 'ト゚',
  '1-6-88' => 'ㇷ゚',
  # from here, irregular chars
  '1-11-45' => 'ə́'
}

ACCENT_SEPARATIONS = {
  '!@'  => '¡',
  '?@'  => '¿',
  'A`'  => 'À',
  "A'"  => 'Á',
  'A^'  => 'Â',
  'A~'  => 'Ã',
  'A:'  => 'Ä',
  'A&'  => 'Å',
  'AE&' => 'Æ',
  'C,'  => 'Ç',
  'E`'  => 'È',
  "E'"  => 'É',
  'E^'  => 'Ê',
  'E:'  => 'Ë',
  'I`'  => 'Ì',
  "I'"  => 'Í',
  'I^'  => 'Î',
  'I:'  => 'Ï',
  'N~'  => 'Ñ',
  'O`'  => 'Ò',
  "O'"  => 'Ó',
  'O^'  => 'Ô',
  'O~'  => 'Õ',
  'O:'  => 'Ö',
  'O/'  => 'Ø',
  'U`'  => 'Ù',
  "U'"  => 'Ú',
  'U^'  => 'Û',
  'U:'  => 'Ü',
  "Y'"  => 'Ý',
  's&'  => 'ß',
  'a`'  => 'à',
  "a'"  => 'á',
  'a^'  => 'â',
  'a~'  => 'ã',
  'a:'  => 'ä',
  'a&'  => 'å',
  'ae&' => 'æ',
  'c,'  => 'ç',
  'e`'  => 'è',
  "e'"  => 'é',
  'e^'  => 'ê',
  'e:'  => 'ë',
  'i`'  => 'ì',
  "i'"  => 'í',
  'i^'  => 'î',
  'i:'  => 'ï',
  'n~'  => 'ñ',
  'o`'  => 'ò',
  "o'"  => 'ó',
  'o^'  => 'ô',
  'o~'  => 'õ',
  'o:'  => 'ö',
  'o/'  => 'ø',
  'u`'  => 'ù',
  "u'"  => 'ú',
  'u^'  => 'û',
  'u:'  => 'ü',
  "y'"  => 'ý',
  'y:'  => 'ÿ',
  'A_'  => 'Ā',
  'a_'  => 'ā',
  'E_'  => 'Ē',
  'e_'  => 'ē',
  'I_'  => 'Ī',
  'i_'  => 'ī',
  'O_'  => 'Ō',
  'o_'  => 'ō',
  'OE&' => 'Œ',
  'oe&' => 'œ',
  'U_'  => 'Ū',
  'u_'  => 'ū'
}
ANY_ACCENT_SEPARATIONS_PATTERN = Regexp.union(ACCENT_SEPARATIONS.keys())

args = {
  in: '/dev/stdin',
  out: '/dev/stdout'
}
OptionParser.new do |opt|
  opt.on('--in FILE') { |v| args[:in] = v }
  opt.on('--out FILE') { |v| args[:out] = v }
  opt.parse!
end

def char_from_jis_code(code)
  return JIS_TO_LIGATURES[code] if JIS_TO_LIGATURES.key? code
  m, k, t = code.split('-').map(&:to_i)
  euc_code_number = ((m - 1) * 0x8f) << 16 | (k + 0xa0) << 8 | (t + 0xa0)
  euc_code_number.chr(Encoding::EUC_JIS_2004).encode(Encoding::UTF_8)
rescue => e
  STDERR.puts "[WARN] Unprocessable code: #{code}"
  raise e
end

File.open(args[:out], 'w') do |f|
  File.foreach(args[:in]).with_index do |line, i|
    row = JSON.load(line)
    text = row['text']
    meta = row['meta']

    # 1. normalize newline
    text.encode! universal_newline: true

    # 2. remove the top of the header
    text = text.split("\n\n", 2)[1]

    raise 'No content found' unless text || text.empty?

    # 3. remove the headnote
    # 【テキス禊中に現れる記号について】 is an existing typo
    headnote_pattern = /-+{8,}\n\n?[【《]テキス[ト禊]中に現れる記号について[】》].+?\n-+{8,}\n/m
    if text.match(headnote_pattern)
      text.sub!(headnote_pattern, '')
    elsif text.match(/-+{8,}\n/)
      headnote_pattern2 = /-+{8,}\n［表記について］\n.+?\n-+{8,}\n/m
      if text.match(headnote_pattern2)
        text.sub!(headnote_pattern2, '')
      else
        # exceptionally-formatted headnotes which should be removed
        if %w[044457 024357].include? meta['作品ID']
          text.sub!(/-+{8,}\n.+?\n-+{8,}\n/m, '')
        elsif %w[000395].include? meta['作品ID']
          text.sub!(/［収録作品］\n.+?\n=+{8,}\n/m, '')
        elsif %w[000455].include? meta['作品ID']
          text.sub!(/［表記について］\n.+?\n-+{8,}\n/m, '')
        else
          # FIXME: do it later
          text.sub!(/\A-+{8,}\n/, '') # remove the rule at the top if exists
        end
      end
    end

    # 4. remove the table of contents (there few toc exists)
    table_of_contents_pattern = /\A\n*●目次\n.+?\n\n\n/m
    text.sub!(table_of_contents_pattern, '')

    # 5. romove the footnote
    footnote = nil
    pull_out_footnote = -> (matched) do
      footnote = matched
      ''
    end
    footnote_pattern = /^底本：.+\z/m
    footnote_pattern2 = /［＃本文終わり］(.+)\z/m
    if text.match(footnote_pattern)
      text.sub!(footnote_pattern, &pull_out_footnote)
    elsif text.match(footnote_pattern2)
      text.sub!(footnote_pattern2) do
        footnote = $1
        ''
      end
    elsif %w[001871 002526 024456].include? meta['作品ID']  # no ：
      text.sub!(/^底本.+\z/m, &pull_out_footnote)
    elsif %w[056033].include? meta['作品ID']  # half-width :
      text.sub!(/^底本:.+\z/m, &pull_out_footnote)
    elsif %w[043035].include? meta['作品ID']  # a typo
      text.sub!(/^定本：.+\z/m, &pull_out_footnote)
    elsif %w[000395].include? meta['作品ID']  # format error
      text.sub!(/^={8,}底本：.+\z/m, &pull_out_footnote)
    elsif %w[000906 000909].include? meta['作品ID']  # no 底本
      text.sub!(/^入力者注.+\z/m, &pull_out_footnote)
    else
      raise 'No footnote found'
    end

    # 6. reformat the inserted notes
    text.gsub!(/（?［＃割り注］(.+?)［＃割り注終わり］）?/) { |s|
      content = $1.gsub(/［＃改行］/, ' ')
      case [s.start_with?('（'), s.end_with?('）')]
      when [true, true], [false, false]
        "（#{content}）"
      when [true, false]
        "（（#{content}）"
      when [false, true]
        "（#{content}））"
      end
    }

    # 7. remove the rubies
    text.gsub!(/｜(.+?)《.+?》/, '\1')
    text.gsub!(/《.+?》/, '')

    # 8. replace special charactors
    text.gsub!(/／＼/, '〳〵')
    text.gsub!(/／″＼/, '〴〵')

    # 9. resolve the accent separations
    if text.match(/〔([^〔〕]+?)〕/)
      text.gsub!(/〔([^〔〕]+?)〕/) { |s|
        count = 0
        replaced = $1.gsub(ANY_ACCENT_SEPARATIONS_PATTERN) { |c|
          count += 1
          ACCENT_SEPARATIONS[c]
        }
        count > 0 ? replaced : s
      }
    end

    # 10. resolve the gaiji-s
    text.gsub!(/※［.+?U\+([0-9A-F]+).+?］/) { $1.to_i(16).chr(Encoding::UTF_8) }
    text.gsub!(/※［.+?[準、]([12]-\d{1,3}-\d{1,3})、?.*?］/) { char_from_jis_code $1 }
    if text.match(/※［.+?］/)
      # when failed, format original expressions like `※（牛＋子）`
      # remove 「」 if they are redundant with （）
      text.gsub!(/※［＃「((?:「[^「」]+」|[^「」])+)」(?:、[^、]*?］|］)/) { "※（#{$1}）" }
      text.gsub!(/※［＃(.+?)(?:、[^、]*?］|］)/) { "※（#{$1}）" }
    end

    # 11. remove the markups
    markup_pattern = /［＃[^［］]+?］/
    while text.match(markup_pattern)
      text.gsub!(markup_pattern, '')
    end

    # 12. remove prefix/suffix newlines and rules
    text.gsub!(/\A\n+|\n+\z/, '')
    text.gsub!(/\A[-=\n]{8,}|[-=\n]{8,}\z/, '') # not a strict regexp, but I don't care

    STDERR.write "Progress: #{i}\r"

    new_row = { text: text, footnote: footnote, meta: meta }
    json = JSON.dump new_row
    f.puts json
  end
end
