import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "chip", "card", "empty"]

  connect() {
    this.activeFrequency = "all"
    this.apply()
  }

  search() {
    this.apply()
  }

  filterByChip(event) {
    this.activeFrequency = event.currentTarget.dataset.frequency
    this.chipTargets.forEach((chip) => {
      chip.classList.toggle("active", chip.dataset.frequency === this.activeFrequency)
    })
    this.apply()
  }

  apply() {
    const keyword = this.hasInputTarget ? this.inputTarget.value.trim().toLowerCase() : ""
    let visibleCount = 0

    this.cardTargets.forEach((card) => {
      const name = (card.dataset.name || "").toLowerCase()
      const matchesKeyword = keyword === "" || name.includes(keyword)
      const matchesFrequency =
        this.activeFrequency === "all" || card.dataset.frequency === this.activeFrequency
      const visible = matchesKeyword && matchesFrequency

      card.classList.toggle("is-hidden", !visible)
      if (visible) visibleCount += 1
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("is-hidden", visibleCount !== 0)
    }
  }
}
