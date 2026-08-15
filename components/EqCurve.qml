import QtQuick
import qs.Commons

Canvas {
  id: root
  property var gains: []
  property color lineColor: Color.accent
  property color gridColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, .18)
  onGainsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  function yFor(g) { return height / 2 - Math.max(-12, Math.min(12, Number(g) || 0)) * height / 30 }
  function xFor(index) {
    var low = Math.log(60) / Math.LN10
    var high = Math.log(16000) / Math.LN10
    var frequency = [60, 250, 1000, 4000, 8000, 16000][index]
    return width * ((Math.log(frequency) / Math.LN10) - low) / (high - low)
  }
  onPaint: {
    var c=getContext("2d"); c.clearRect(0,0,width,height)
    c.strokeStyle=gridColor; c.lineWidth=1
    for (var j=0;j<5;j++) { var gy=height*j/4; c.beginPath(); c.moveTo(0,gy); c.lineTo(width,gy); c.stroke() }
    c.strokeStyle=Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, .32); c.lineWidth=1
    c.beginPath(); c.moveTo(0,height/2); c.lineTo(width,height/2); c.stroke()
    if (!gains || gains.length < 2) return
    c.strokeStyle=Qt.rgba(lineColor.r, lineColor.g, lineColor.b, .16); c.lineWidth=Style.space(8); c.lineJoin="round"; c.beginPath()
    for (var f=0;f<gains.length;f++) { var fx=xFor(f); var fy=yFor(gains[f]); if (!f)c.moveTo(fx,fy); else c.lineTo(fx,fy) }
    c.stroke()
    c.strokeStyle=lineColor; c.lineWidth=Math.max(2, Style.space(2)); c.lineJoin="round"; c.beginPath()
    for (var i=0;i<gains.length;i++) { var x=xFor(i); var y=yFor(gains[i]); if (!i)c.moveTo(x,y); else c.lineTo(x,y) }
    c.stroke()
    c.fillStyle = lineColor
    for (var p=0;p<gains.length;p++) { c.beginPath(); c.arc(xFor(p), yFor(gains[p]), Math.max(2, Style.space(3)), 0, Math.PI * 2); c.fill() }
  }
}
