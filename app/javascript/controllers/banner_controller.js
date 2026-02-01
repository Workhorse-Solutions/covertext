import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss(event) {
    const url = event.currentTarget.dataset.bannerUrl

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Content-Type": "application/json"
      }
    }).then(() => {
      this.element.remove()
    })
  }
}
