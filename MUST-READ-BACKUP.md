# Backup from work Mac — 2026-09-30

- Original local path: `/Users/muhammadmohsin/Documents/Learning/Nabeel Spain/veg_shop_manager`
- Checked-out branch: `master`; HEAD: `b88e8ace71c8bdcc81e0defeedda9bdae13d76cd`
- Snapshot contents: current HEAD plus all uncommitted and untracked (non-ignored) changes; 20 new/changed files included vs HEAD.

## Backup branches pushed (intended)
- `backup/work-mac-2026-09-30` (snapshot)
- `backup/branches/feature/cloud-inventory-printing`
- `backup/branches/master`
- `backup/stash-0`: On master: tmp

## Excluded files (paths only)
Copy these manually from a secure source if needed.
- (none)

## Restore
```
git clone git@github.com:mohsinsapra/veg_shop_manager.git && cd <repo>
git fetch origin 'refs/heads/backup/*:refs/remotes/origin/backup/*'
git checkout -b restore origin/backup/work-mac-2026-09-30
# then merge/cherry-pick into main when ready; stashes are under origin/backup/stash-N
```

Nothing has been merged into main yet.
