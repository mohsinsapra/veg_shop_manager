/// Formats a quantity for display: whole numbers show without a decimal
/// point (e.g. "3"), halves show one decimal place (e.g. "1.5").
String fmtQty(num q) => q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
