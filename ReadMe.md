# LLM Tricks
Finding useful things to do with local LLMs.

All scripts work with data within `PRIVATE_DATA/` so that private data can't be
accidentally committed.

### `cosine_similarity.lua`
Opens `embeddings.json` and creates `similarities.json` with a sorted list of
comparisons.

### `generate_embeddings.lua`
Opens every file on its whitelist within the `notebook` directory, and generates
embeddings (placed in `embeddings.json`). When files are too long, it truncates
them.

### `least_similar.lua`
Opens `similarities.json`, reverses the sort order, and saves it as
`differences.json`.

### `refresh_sources.lua`
Creates/Maintains a store of chunked data with embeddings based on configurable
`sources.json`. Example:

```json
{
  "source name":{
    "embedding_model":"qwen3-embedding:0.6b",
    "filters":{
      "blacklist":[".git"],
      "extension_whitelist":["md"]
    },
    "initialize_command":"git clone REMOTE .",
    "max_chunk_size":32768,
    "path":"will be created before initialize_command is run",
    "strip_frontmatter":true,
    "target_chunk_size":3072,
    "refresh_command":"git fetch origin && git reset --hard origin/main"
  }
}
```

The filters are based on `utility.tree`'s filter options (optional).
`initialize_command` is only run the first time (optional),
while `refresh_command` is run each time (optional).
Commands will be run in the specified `path`.
`strip_frontmatter` will remove YAML frontmatter (common in Markdown files).
`embedding_model` and `max_chunk_size` are self-explanatory (optional).
`target_chunk_size` (optional) allows for finer-grained chunks to be generated
alongside the maximum overviews for more precise retrieval.

The embeddings are stored like so:

```json
{
  "files":{
    "PRIVATE_DATA/source_path/path/to/file.ext":["sha512sum", "another sum"]
  },
  "vectors":{
    "sha512sum":[0.5, 0, 1, -0.5, -1, ...]
  }
}
```

SHA2 512-bit sums are used to link a text chunk with its embedding. All file
names reference a list of text chunks so they can handle being too large. Every
file that is too large for a single chunk has a whole-file embedding calculated
first (it is the first element of the array), so that if a whole file becomes
relevant, it can still show up instead of only chunks.

### `synopsis_generator.lua`
Chooses a random file within `notebook`, and generates a novel synopsis from it.

Arguments:
- `refresh_file_list`: Refreshes the cached file list to choose from.
- `export_ordered_list_of_prompts`: Makes an epub to review generated synopses.

## JSON config
This repo uses my utility library's config system, using a `config.json` file in
the repo root that is excluded from commits.

```json
{
  "models":{
    "embedding":{
      "model":"qwen3-embedding:0.6b",
      "max_chunk_size":32768
    },
    "initialized_sources":{}
  }
}
```

`refresh_sources.lua` uses `models` to store default embedding model information
and `initialized_sources` to store which sources have been initialized.

## Tasks
- [ ] The whitelisting/blacklisting of tree should be in list too.
- [ ] synopsis_generator should be able to blacklist files it already tried?
