# LLM Tricks
Trying to find *anything* useful to do with local LLMs.

All scripts work with data within `PRIVATE_DATA/` so that private data can't be
accidentally committed.

###### `cosine_similarity.lua`
Opens `embeddings.json` and creates `similarities.json` with a sorted list of
comparisons.

###### `generate_embeddings.lua`
Opens every file on its whitelist within the `notebook` directory, and generates
embeddings (placed in `embeddings.json`). When files are too long, it truncates
them.

###### `least_similar.lua`
Opens `similarities.json`, reverses the sort order, and saves it as
`differences.json`.

###### `synopsis_generator.lua`
Chooses a random file within `notebook`, and generates a novel synopsis from it.

Arguments:
- `refresh_file_list`: Refreshes the cached file list to choose from.
- `export_ordered_list_of_prompts`: Makes an epub to review generated synopses.

## Tasks
- [ ] The whitelisting/blacklisting of tree should be in list too.
- [ ] synopsis_generator should be able to blacklist files it already tried?
