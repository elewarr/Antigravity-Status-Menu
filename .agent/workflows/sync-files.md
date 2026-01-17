---
description: Sync new files to Xcode project
---

# Sync Project Files

After adding new `.swift` files to the filesystem, run:

```bash
// turbo
./scripts/sync-project.rb
```

This will automatically:
1. Find all `.swift` files on disk
2. Add any missing files to the Xcode project
3. Assign them to the correct target

## When to use

- After creating a new Swift file manually
- After pulling changes that include new files
- After pasting files from another project
