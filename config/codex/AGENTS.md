# AGENTS.md instructions for /Users/andrewsager

<INSTRUCTIONS>
## Preferences
- When editing or generating files with these extensions, reopen the file at the end of your turn so the user can verify: .png, .xlsx, .pptx, .pdf, .docx. During iterative work within a turn, inspect programmatically without opening by default.

## wkt - Git Worktree Tool

`wkt` manages Git worktrees across repositories. Scripts are in `~/Code/wkt/bin/`.

**Commands:**
- `wkt <branch>` - Create a new worktree (auto-creates branch if needed)
- `wkt --fork <branch>` - Fork current worktree (copies uncommitted changes)
- `wkt-rm <path>` - Remove a worktree safely (warns about uncommitted work)
- `wkt-rm .` - Remove current worktree

**Per-repo config** (optional):
- `tools/asset_manifest.yaml` - Large dirs to clone via APFS copy-on-write
- `tools/worktree_sync_manifest.yaml` - Files to sync between worktrees

For full docs: `~/Code/wkt/README.md`
</INSTRUCTIONS>
