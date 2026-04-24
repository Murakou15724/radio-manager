import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initializeTheme()
  }

  initializeTheme() {
    // LocalStorageから保存されたテーマを取得、なければダークモードをデフォルトに
    const savedTheme = localStorage.getItem('theme') || 'dark'
    this.setTheme(savedTheme)
  }

  toggle() {
    const currentTheme = localStorage.getItem('theme') || 'dark'
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    this.setTheme(newTheme)
  }

  setTheme(theme) {
    // HTMLタグのdata-theme属性を設定
    document.documentElement.setAttribute('data-theme', theme)
    
    // LocalStorageに保存
    localStorage.setItem('theme', theme)
    
    // アイコン更新
    this.updateIcon(theme)
  }

  updateIcon(theme) {
    const button = this.element
    if (button) {
      // ダークモードの場合は月アイコン、ライトモードの場合は太陽アイコンを表示
      button.textContent = theme === 'dark' ? '🌙' : '☀️'
    }
  }
}
