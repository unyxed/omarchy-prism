import QtQuick
import Quickshell.Io
import "../model/Sysfs.js" as Sysfs

// CPU and memory sampling from /proc. Stops entirely when nothing is shown.
Item {
  id: root

  property bool active: false
  property int intervalMs: 2000

  readonly property real cpuLoad: cpuSample.overall
  readonly property var coreLoads: cpuSample.cores
  readonly property var memory: memorySample

  property var cpuSample: ({ overall: Sysfs.UNKNOWN, cores: [] })
  property var memorySample: Sysfs.parseMeminfo("")
  property var previousStat: null

  function sample() {
    statFile.reload()
    memoryFile.reload()
  }

  function applyStat(raw) {
    var next = Sysfs.parseCpuStat(raw)
    if (!next.overall) return
    if (previousStat) cpuSample = Sysfs.cpuLoad(previousStat, next)
    previousStat = next
  }

  function resetBaseline() {
    previousStat = null
    cpuSample = ({ overall: Sysfs.UNKNOWN, cores: [] })
  }

  onActiveChanged: {
    if (active) {
      resetBaseline()
      sample()
    }
  }

  Timer {
    interval: Math.max(500, root.intervalMs)
    running: root.active
    repeat: true
    onTriggered: root.sample()
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.applyStat(text())
  }

  FileView {
    id: memoryFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: root.memorySample = Sysfs.parseMeminfo(text())
  }
}
