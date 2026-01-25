# Global Claude Code Instructions

## Preferences

- When editing or generating files with these extensions, reopen the file at the end of your turn so the user can verify: .png, .xlsx, .pptx, .pdf, .docx. During iterative work within a turn, inspect programmatically without opening by default.

## PDF OCR

For OCR tasks on PDFs, use the Azure Document Intelligence approach:

- **Script location:** `~/dotfiles/tools/azure_ocr.py` (also available as `~/bin/azure_ocr`)
- **Requirements:** `azure-ai-documentintelligence` package
- **Environment variables required:**
  - `AZURE_DOC_INTELLIGENCE_ENDPOINT`
  - `AZURE_DOC_INTELLIGENCE_KEY`

### Usage

Single file:
```bash
azure_ocr document.pdf --output result.md
```

Batch processing (all PDFs in a directory):
```bash
azure_ocr ./pdfs/ --batch --outdir ./markdown/
```

With layout analysis (better for tables):
```bash
azure_ocr document.pdf --layout --output result.md
```

### Pricing
~$1.00 per 1000 pages (Read model)

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

## Printing

To print a file to the network printer, use `lpr <file>` (the default printer is Brother_HL_L2405W).
