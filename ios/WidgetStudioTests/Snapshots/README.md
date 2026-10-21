# Snapshot references

One PNG per test spec and language (`<spec id>.<en|ar>.png`), rendered at 2× by
`SpecRenderTests.testSpecSnapshots` with a fixed date (2026-10-21 14:05 Cairo), sample data
and frozen live text (ADR-010).

- **New spec or no reference:** the test is skipped and the render is written to the CI
  artifact `snapshots`. Check it, then copy it here and commit.
- **Intended change:** download the `snapshots` artifact from the failing run, review the
  `<name>.png` renders (and `<name>.diff.png`, red = changed pixels), then replace the
  references here.
- **CI image or Xcode update:** small rendering differences are tolerated (0.2 % of pixels).
  If every snapshot fails after a runner update, re-record all of them the same way.
