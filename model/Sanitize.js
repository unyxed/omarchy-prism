// Sanitize helpers: neutralize markup-shaped input before it reaches a sink
// whose Text format the plugin cannot control (tooltips, notification bodies).
// Display text owned by the plugin uses Text.PlainText directly; this helper
// is for the few strings handed to Omarchy-owned components.
function escapeMarkup(raw, maxLen) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  var limit = maxLen === undefined ? 200 : maxLen
  if (text.length > limit) text = text.substring(0, limit)
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function cleanLine(raw, maxLen) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  var limit = maxLen === undefined ? 200 : maxLen
  text = text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
  text = text.replace(/\s+/g, " ").trim()
  if (text.length > limit) text = text.substring(0, limit)
  return text
}

// Collection bounds for anything read from disk or a subprocess.
function boundList(value, maxItems) {
  if (!value || typeof value.length !== "number") return []
  var out = []
  var n = Math.min(value.length, maxItems === undefined ? 64 : maxItems)
  for (var i = 0; i < n; i++) out.push(value[i])
  return out
}

if (typeof module !== "undefined") {
  module.exports = { escapeMarkup: escapeMarkup, cleanLine: cleanLine, boundList: boundList }
}
