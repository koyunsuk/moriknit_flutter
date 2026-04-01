Feature structure rule:

- Each feature keeps a consistent `data / domain / presentation` split.
- `presentation/` contains screens, sheets, and widgets used by that feature.
- Presentation helper files that are not full screens go under `presentation/widgets/`.
- Features that do not need `data` or `domain` yet still keep those folders reserved for future growth.
