// Parsers for /proc/stat, /proc/meminfo and /proc/loadavg. Pure functions.
var UNKNOWN = -1
var MAX_CORES = 32

function num(raw, fallback) {
  if (typeof raw === "number") return isFinite(raw) ? raw : fallback
  var text = String(raw === undefined || raw === null ? "" : raw).trim()
  if (text === "") return fallback
  var n = Number(text)
  return isFinite(n) ? n : fallback
}

function asFraction(value) {
  var n = num(value, 0)
  return Math.max(0, Math.min(1, n))
}

function parseCpuStat(text) {
  var lines = String(text || "").split("\n")
  var overall = null
  var cores = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("cpu") !== 0) continue
    var fields = line.split(/\s+/)
    var label = fields[0]
    if (label !== "cpu" && !/^cpu\d+$/.test(label)) continue
    var total = 0
    var idle = 0
    for (var f = 1; f < fields.length; f++) {
      var value = num(fields[f], 0)
      total += value
      if (f === 4 || f === 5) idle += value
    }
    var sample = { total: total, idle: idle }
    if (label === "cpu") overall = sample
    else if (cores.length < MAX_CORES) cores.push(sample)
  }
  return { overall: overall, cores: cores }
}

function sampleLoad(previous, next) {
  if (!previous || !next) return UNKNOWN
  var totalDelta = next.total - previous.total
  var idleDelta = next.idle - previous.idle
  if (!(totalDelta > 0)) return UNKNOWN
  return asFraction((totalDelta - idleDelta) / totalDelta)
}

function cpuLoad(previous, next) {
  var prev = previous || { overall: null, cores: [] }
  var cur = next || { overall: null, cores: [] }
  var cores = []
  var count = Math.min(prev.cores.length, cur.cores.length)
  for (var i = 0; i < count; i++) cores.push(sampleLoad(prev.cores[i], cur.cores[i]))
  return { overall: sampleLoad(prev.overall, cur.overall), cores: cores }
}

function parseMeminfo(text) {
  var values = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var separator = lines[i].indexOf(":")
    if (separator <= 0) continue
    var key = lines[i].substring(0, separator)
    values[key] = num(lines[i].substring(separator + 1).replace(/kB/i, ""), 0)
  }
  var total = values.MemTotal || 0
  var available = values.MemAvailable
  if (available === undefined)
    available = (values.MemFree || 0) + (values.Cached || 0) + (values.Buffers || 0)
  return {
    totalKib: total,
    availableKib: Math.min(available, total),
    usedKib: Math.max(0, total - Math.min(available, total)),
    fraction: total > 0 ? asFraction((total - Math.min(available, total)) / total) : UNKNOWN
  }
}

if (typeof module !== "undefined") {
  module.exports = { UNKNOWN: UNKNOWN, parseCpuStat: parseCpuStat, cpuLoad: cpuLoad, parseMeminfo: parseMeminfo }
}
