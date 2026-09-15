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
sources. Example:

```json
{
  "source name (unused by the script)":{
    "filters":{
      "blacklist":".git",
      "extension_whitelist":"md"
    },
    "initialize_command":"git clone REMOTE .",
    "path":"will be created before initialize_command is run",
    "strip_frontmatter":true,
    "refresh_command":"git reset --hard origin/main"
  }
}
```

The filters are based on `utility.tree`'s filter options. `initialize_command`
is only run the first time (optional), while `refresh_command` is run each time
(optional). Commands will be run in the specified `path`. `strip_frontmatter` is
for removing YAML frontmatter (common in Markdown files) if truthy.

### `synopsis_generator.lua`
Chooses a random file within `notebook`, and generates a novel synopsis from it.

Arguments:
- `refresh_file_list`: Refreshes the cached file list to choose from.
- `export_ordered_list_of_prompts`: Makes an epub to review generated synopses.

## Tasks
- [ ] The whitelisting/blacklisting of tree should be in list too.
- [ ] synopsis_generator should be able to blacklist files it already tried?
