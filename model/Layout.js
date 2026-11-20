// Stack & 2-column macOS bento layout for the default (non-dragged) cards.
function widgetName(id) {
  if (id === "clock") return "Clock"
  if (id === "system") return "System"
  if (id === "gpu") return "Graphics"
  if (id === "media") return "VinylPod"
  if (id === "calendar") return "Calendar"
  if (id === "todo") return "Reminders"
  return String(id)
}

function widgetGlyph(id) {
  if (id === "clock") return "\uF017"
  if (id === "system") return "\uF4BC"
  if (id === "gpu") return "\uEAD9"
  if (id === "media") return "\uF001"
  if (id === "calendar") return "\uF073"
  if (id === "todo") return "\uF0AE"
  return "\uF111"
}

// Places non-dragged cards into 1 or 2 columns anchored at `position`, wrapping
// to a second column when total height exceeds available vertical space or when
// 4+ cards are active, matching macOS desktop widget stacks.
function flowPositions(position, entries, spacing, marginX, marginY, screenW, screenH) {
  if (!entries || entries.length === 0) return {}

  var availH = Math.max(400, screenH - marginY * 2)
  var singleH = 0
  var maxCardW = 280
  for (var i = 0; i < entries.length; i++) {
    singleH += entries[i].h
    maxCardW = Math.max(maxCardW, entries[i].w)
  }
  if (entries.length > 1) singleH += spacing * (entries.length - 1)

  var numCols = (entries.length >= 4 || singleH > availH) ? 2 : 1
  var cols = []
  var colHeights = []
  for (var c = 0; c < numCols; c++) {
    cols.push([])
    colHeights.push(0)
  }

  for (var k = 0; k < entries.length; k++) {
    var targetCol = 0
    if (numCols > 1) {
      for (var cc = 1; cc < numCols; cc++) {
        if (colHeights[cc] < colHeights[targetCol]) targetCol = cc
      }
    }
    cols[targetCol].push(entries[k])
    colHeights[targetCol] += entries[k].h + spacing
  }

  var totalW = numCols * maxCardW + (numCols - 1) * spacing
  var maxColH = 0
  for (var hIdx = 0; hIdx < numCols; hIdx++) {
    var ch = colHeights[hIdx] > 0 ? colHeights[hIdx] - spacing : 0
    maxColH = Math.max(maxColH, ch)
  }

  var startX = marginX
  var startY = marginY
  if (position.indexOf("center") !== -1) startX = Math.max(marginX, Math.round((screenW - totalW) / 2))
  if (position.indexOf("right") !== -1) startX = Math.max(marginX, screenW - totalW - marginX)
  if (position.indexOf("middle") !== -1) startY = Math.max(marginY, Math.round((screenH - maxColH) / 2))
  if (position.indexOf("bottom") !== -1) startY = Math.max(marginY, screenH - maxColH - marginY)

  var out = {}
  for (var col = 0; col < numCols; col++) {
    var colX = startX + col * (maxCardW + spacing)
    var y = startY
    for (var row = 0; row < cols[col].length; row++) {
      var item = cols[col][row]
      out[item.id] = { x: Math.round(colX), y: Math.round(y) }
      y += item.h + spacing
    }
  }
  return out
}
