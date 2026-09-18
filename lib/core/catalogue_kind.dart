/// Which part of a provider's catalogue something belongs to. Xtream
/// numbers live, VOD and series categories independently, so the same
/// remote key can appear once per kind.
enum CatalogueKind { live, movie, series }
