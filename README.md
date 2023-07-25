# 青空文庫 (Aozora Bunko) Extractor

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
