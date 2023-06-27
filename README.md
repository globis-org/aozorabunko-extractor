# 青空文庫 (Aozora Bunko) Extractor

## Usage

### 1. Include submodule

### 2. Bundle install

```bash
bundle install
```

### 3. Download Aozora Bunko data

```bash
bundle exec ./save_as_json.rb --public > tmp/aozorabunko.json
```

Without `--public` flag, the output will contain non-public-domain or non-CC data.

### 4. Deduplicate books

This removes all redundant entries with identical text (`テキスト`) field values.

```bash
bundle exec ./deduplicate_books.rb --in tmp/aozorabunko.json > tmp/aozorabunko-dedupe.json
```

### 5. Clean up texts

This removes Aozora-Bunko-specific markups in the text (`テキスト`) fields as much as possible.

```bash
bundle exec ./clean_text_in_json.rb --in tmp/aozorabunko-dedupe.json > tmp/aozorabunko-dedupe-clean.json
```
