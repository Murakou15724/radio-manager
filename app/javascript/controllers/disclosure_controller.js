import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggleLabel"]

  connect() {
    if (this.hasToggleLabelTarget) {
      this.openLabel = this.toggleLabelTarget.textContent
    }
  }

  toggle() {
    const isOpen = this.panelTarget.classList.toggle("is-open")
    this.element.classList.toggle("is-open", isOpen)

    if (this.hasToggleLabelTarget) {
      this.toggleLabelTarget.textContent = isOpen ? "閉じる" : this.openLabel
    }

    if (isOpen) {
      this.panelTarget.querySelector("input, select")?.focus()
    }
  }
}
