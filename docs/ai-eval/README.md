# AI eval set (ADR-019)

Images for checking Create from image without a phone. `cases.json` lists each image with the
mode and size to generate with.

- `ref-*.png`: crops of `docs/reference/widgets-reference.jpg`, upscaled 6× (the source is small,
  so they are soft, like a phone screenshot of a small widget).
- `draw-*.png`: widgets drawn for this set (calendar like the M5 device test, reminders list,
  quote card).

Run it: Actions → **AI eval** → Run workflow (model, review on/off). It needs the repository
secret `GEMINI_API_KEY`. The job generates a spec per image with the app's real prompt, schema,
parser and renderer, and uploads the artifact `ai-eval` with one side-by-side PNG per case
(original left, render right), the specs, and `summary.md`. The key is never printed.

`results/` holds side-by-side images picked from runs, for the record.
