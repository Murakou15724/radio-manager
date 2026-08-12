import { Controller } from "@hotwired/stimulus"

const WEEKDAYS_JP = ["日", "月", "火", "水", "木", "金", "土"]

export default class extends Controller {
  static targets = ["time", "date"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const now = new Date()

    if (this.hasTimeTarget) {
      const hh = String(now.getHours()).padStart(2, "0")
      const mm = String(now.getMinutes()).padStart(2, "0")
      const ss = String(now.getSeconds()).padStart(2, "0")
      this.timeTarget.textContent = `${hh}:${mm}:${ss}`
    }

    if (this.hasDateTarget) {
      const y = now.getFullYear()
      const m = now.getMonth() + 1
      const d = now.getDate()
      const w = WEEKDAYS_JP[now.getDay()]
      this.dateTarget.textContent = `${y}年${m}月${d}日(${w})`
    }
  }
}
