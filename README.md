# 青空文庫 (Aozora Bunko) Extractor
This repository is dedicated to formatting data from [Aozora Bunko (青空文庫)](https://www.aozora.gr.jp/), a website that compiles public domain books in Japan.
The data will be converted into a convenient and user-friendly format, making it ideal for Machine Learning applications.

The dataset processed by this code is made available on HuggingFace: [globis-university/aozorabunko-clean](https://huggingface.co/datasets/globis-university/aozorabunko-clean).

## Methodology 

### 1. Data collection 
First, the [CSV file that lists all works](https://www.aozora.gr.jp/index_pages/person_all.html) is downloaded.
This information is then incorporated into the `meta` field. Non-public-domain books are filtered out.
The main text for each book corresponding to every row in the CSV is retrieved and incorporated into the `text` field.

### 2. Deduplication 
Entries where the `図書カードURL` (Library Card URL) in the CSV does not match the `作品ID` (Work ID) and `人物ID` (Person ID) are removed.
In addition, any rows with text identical to those found earlier are discarded.

### 3. Cleaning 
The `text` field data undergoes cleaning in the following sequence:

1. Convert new lines to `\n`
2. Remove headers
3. Remove footnotes and add them to the `footnote` field
4. Convert inserted notes into regular parenthetical text
5. Remove ruby (phonetic guides)
6. Convert specific characters, such as external characters and iteration marks, into standard Unicode characters
7. Remove any remaining markup
8. Remove leading and trailing new lines and horizontal rules

## Usage

### 1. Include submodule

### 2. Bundle install

```bash
bundle install
```

### 3. Download Aozora Bunko data

```bash
bundle exec ./save_as_jsonl.rb --public > tmp/aozorabunko.jsonl
```

Without `--public` flag, the output will contain non-public-domain or non-CC data.

### 4. Deduplicate books

This removes all redundant entries with identical `text` field values.

```bash
bundle exec ./deduplicate_books.rb --in tmp/aozorabunko.jsonl > tmp/aozorabunko-dedupe.jsonl
```

### 5. Clean up texts

This removes Aozora-Bunko-specific markups in the `text` fields as much as possible.

```bash
bundle exec ./clean_text_in_jsonl.rb --in tmp/aozorabunko-dedupe.jsonl > tmp/aozorabunko-dedupe-clean.jsonl
```

### Extra: Extract chats

This collects chat data using a heuristic approach, specifically by collecting consecutive utterances denoted with brackets as `「...」`.

```bash
bundle exec ./extract_chats.rb --in tmp/aozorabunko-dedupe-clean.jsonl > tmp/aozorabunko-dedupe-clean-chats.jsonl
```
