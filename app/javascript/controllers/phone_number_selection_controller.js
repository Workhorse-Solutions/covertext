import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

  select() {
    this.submitButtonTarget.disabled = false
  }
}
