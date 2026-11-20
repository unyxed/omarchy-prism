import QtQuick
import Quickshell.Io

// GPU sampling: NVIDIA via nvidia-smi, AMD via sysfs. Intel reports absent.
Item {
  id: root

  property bool active: false
  property int intervalMs: 2000

  property string vendor: ""
  property string name: ""
  readonly property bool present: vendor === "amd" || vendor === "nvidia"

  property real utilization: -1
  property real vramUsed: 0
  property real vramTotal: 0
  property real temperature: -1

  property string busyPath: ""
  property string vramUsedPath: ""
  property string vramTotalPath: ""
  property string tempPath: ""

  readonly property real vramFraction: vramTotal > 0
    ? Math.max(0, Math.min(1, vramUsed / vramTotal)) : -1

  function toNumber(raw, fallback) {
    var n = Number(String(raw || "").trim())
    return isFinite(n) ? n : fallback
  }

  function sample() {
    if (vendor === "amd") {
      if (busyPath !== "") busyFile.reload()
      if (vramUsedPath !== "") vramUsedFile.reload()
      if (vramTotalPath !== "") vramTotalFile.reload()
      if (tempPath !== "") tempFile.reload()
    } else if (vendor === "nvidia") {
      if (!nvidiaProcess.running) nvidiaProcess.running = true
    }
  }

  function applyDiscovery(text) {
    var lines = String(text || "").split("\n")
    var found = {}
    for (var i = 0; i < lines.length; i++) {
      var eq = lines[i].indexOf("=")
      if (eq <= 0) continue
      found[lines[i].substring(0, eq).trim()] = lines[i].substring(eq + 1).trim()
    }
    root.vendor = found.vendor || "none"
    root.name = String(found.name || "").substring(0, 80)
    root.busyPath = String(found.busy || "").substring(0, 256)
    root.vramUsedPath = String(found.vram_used || "").substring(0, 256)
    root.vramTotalPath = String(found.vram_total || "").substring(0, 256)
    root.tempPath = String(found.temp || "").substring(0, 256)
    if (root.active) root.sample()
  }

  function applyNvidia(text) {
    var line = String(text || "").split("\n")[0]
    if (!line) return
    var f = line.split(",")
    for (var i = 0; i < f.length; i++) f[i] = f[i].trim()
    if (f.length < 4) return
    root.utilization = Math.max(-1, Math.min(1, root.toNumber(f[0], -1) / 100))
    root.vramUsed = Math.max(0, root.toNumber(f[1], 0) * 1048576)
    root.vramTotal = Math.max(0, root.toNumber(f[2], 0) * 1048576)
    root.temperature = root.toNumber(f[3], -1)
    if (f[4]) root.name = String(f[4]).substring(0, 80)
  }

  onActiveChanged: if (active && vendor !== "") sample()

  Timer {
    interval: Math.max(500, root.intervalMs)
    running: root.active && root.vendor !== ""
    repeat: true
    onTriggered: root.sample()
  }

  Process {
    id: discover
    running: true
    command: ["sh", "-c", "set -eu; if command -v nvidia-smi >/dev/null 2>&1; then echo vendor=nvidia; echo name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1); exit 0; fi; d=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n1); if [ -n \"${d:-}\" ] && [ -f \"$d/gpu_busy_percent\" ]; then echo vendor=amd; echo busy=$d/gpu_busy_percent; [ -f \"$d/mem_info_vram_used\" ] && echo vram_used=$d/mem_info_vram_used; [ -f \"$d/mem_info_vram_total\" ] && echo vram_total=$d/mem_info_vram_total; t=$(ls \"$d/hwmon\"/hwmon*/temp1_input 2>/dev/null | head -n1); [ -n \"${t:-}\" ] && echo temp=$t; exit 0; fi; echo vendor=none"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDiscovery(text)
    }
  }

  Process {
    id: nvidiaProcess
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name", "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyNvidia(text)
    }
  }

  FileView {
    id: busyFile
    path: root.busyPath
    printErrors: false
    onLoaded: root.utilization = Math.max(0, Math.min(1, root.toNumber(text(), -1) / 100))
  }

  FileView {
    id: vramUsedFile
    path: root.vramUsedPath
    printErrors: false
    onLoaded: root.vramUsed = Math.max(0, root.toNumber(text(), 0))
  }

  FileView {
    id: vramTotalFile
    path: root.vramTotalPath
    printErrors: false
    onLoaded: root.vramTotal = Math.max(0, root.toNumber(text(), 0))
  }

  FileView {
    id: tempFile
    path: root.tempPath
    printErrors: false
    onLoaded: root.temperature = root.toNumber(text(), -1) / 1000
  }
}
