# Tasks: fix-doc-version-and-skill-refs

- [x] T1 Add CHANGELOG.md entries for 0.4.7 and 0.4.8 from release commits
- [x] T2 Update docs/design.md version line and add Completed sections for 0.4.7/0.4.8
- [x] T3 Reference migrations assets explicitly in specnav-vertical-slices SKILL.md (both repos)
- [x] T4 Reference assets/visual-inventory.json in specnav-prototype SKILL.md (both repos)
- [x] T5 Reword verify-plan Stop Condition to drop the banned literal (claude repo; codex already had the fixed wording — recorded as drift evidence)
- [x] T6 Rerun suites: claude 22/22 green + plugin-validate ok, codex 14/14 green
- [x] T7 Release version bump so fixes reach installed caches: claude marketplace + 7 plugin.json to 0.4.9 with 0.4.9 changelog/design notes; codex 7 plugin.json + package.json + design version to 0.1.8; full suites green after bump
