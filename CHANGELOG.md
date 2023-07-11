# Changelog

## 0.2.1

- Fix generated deprecation notice

## 0.2.0

- Remove XML support (`sweet_xml`) until I can get a better handle on what kind of XML support is needed. This might be a thing that we just punt to callers, as there does not appear to be XML library consensus in the Elixir community like there is with `jason` for JSON.
- Add `@deprecated` notices to generated docs for functions that upstream reports are deprecated.
- Add endpoint to generated docs.
- Bump `ex_doc` and `jason`.

## 0.1.0

- initial release