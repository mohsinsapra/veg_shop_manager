/// Formats a quantity for display: whole numbers show without a decimal
/// point (e.g. "3"), halves show one decimal place (e.g. "1.5").
String fmtQty(num q) => q == q.truncateToDouble() ? q.toInt().toString() : q.toString();

/// Builds the stable key used to group/aggregate a catalog item — plain, or
/// one specific pack size — across entry doc ids, PDF row aggregation and
/// on-screen pivots. Plain items (no size) keep the bare itemId so the
/// existing scheme is untouched; a sized entry appends the formatted size
/// (via [fmtQty], so "5" not "5.0"), e.g. "carrot_5".
String itemSizeKey(String itemId, double? packSize) =>
    packSize == null ? itemId : '${itemId}_${fmtQty(packSize)}';
