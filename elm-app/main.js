import './main.css'
import { Elm } from './src/Main.elm'
import lunr from 'lunr'

// Format date in Finnish locale with Europe/Helsinki timezone
const now = new Date()
const options = {
  timeZone: 'Europe/Helsinki',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
}

const formatted = new Intl.DateTimeFormat('fi-FI', options)
  .formatToParts(now)
  .reduce((acc, part) => {
    if (part.type === 'day') acc.day = part.value
    if (part.type === 'month') acc.month = part.value
    if (part.type === 'year') acc.year = part.value
    if (part.type === 'hour') acc.hour = part.value
    if (part.type === 'minute') acc.minute = part.value
    if (part.type === 'second') acc.second = part.value
    return acc
  }, {})

const formattedDate = `${formatted.day}.${formatted.month}.${formatted.year} ${formatted.hour}:${formatted.minute}:${formatted.second}`

// Load saved view mode from localStorage
const savedViewMode = localStorage.getItem('palikkalinkit-viewMode') || 'Full'

// Load saved selected feed types from localStorage
const savedSelectedFeedTypes = localStorage.getItem('palikkalinkit-selectedFeedTypes') || '["Feed","YouTube","Image"]'

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    timestamp: formattedDate,
    viewMode: savedViewMode,
    selectedFeedTypes: savedSelectedFeedTypes,
  },
})

// Handle saving view mode to localStorage
app.ports.saveViewMode.subscribe(function (viewMode) {
  localStorage.setItem('palikkalinkit-viewMode', viewMode)
})

// Handle saving selected feed types to localStorage
app.ports.saveSelectedFeedTypes.subscribe(function (selectedFeedTypes) {
  localStorage.setItem('palikkalinkit-selectedFeedTypes', selectedFeedTypes)
})

// Load search index and set up lunr
let searchIndex = null
fetch('/search-index.json')
  .then((response) => response.json())
  .then((data) => {
    searchIndex = lunr(function () {
      this.ref('id')
      this.field('title')
      this.field('description')
      this.field('source')
      data.forEach((item, index) => {
        item.id = index
        this.add(item)
      })
    })
  })
  .catch((err) => console.error('Failed to load search index:', err))

// Handle performSearch
app.ports.performSearch.subscribe(function (query) {
  if (searchIndex) {
    const results = searchIndex.search(query)
    const ids = results.map((result) => parseInt(result.ref))
    app.ports.searchResults.send(ids)
  } else {
    app.ports.searchResults.send([])
  }
})

// Handle scroll to top
app.ports.scrollToTop.subscribe(function () {
  window.scrollTo({ top: 0, behavior: 'smooth' })
})

// Handle scroll to element by ID
app.ports.scrollToElement.subscribe(function (elementId) {
  const element = document.getElementById(elementId)
  if (element) {
    element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
})

// Handle focus mobile search
app.ports.focusMobileSearch.subscribe(function () {
  const el = document.getElementById('mobile-search-input')
  if (el) el.focus()
})

// Listen for scroll events
window.addEventListener('scroll', function () {
  app.ports.onScroll.send(window.scrollY)
})

// ── Pull-to-refresh (standalone PWA only) ───────────────────────────────────
// Source: https://github.com/Suomen-Palikkaharrastajat-ry/master-builder/blob/1beab237edb509753536c6473b7ece2cbe809187/index.js
function setupPullToRefresh() {
  if (window.__pullToRefreshSetup) return
  window.__pullToRefreshSetup = true

  const isStandalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  if (!isStandalone) return

  const THRESHOLD = 64
  const RELOAD_THRESHOLD = THRESHOLD * 1.5
  const RELOAD_COOLDOWN_MS = 10000
  const RELOAD_KEY = 'pwa-pull-to-refresh-reload-at'
  let startY = 0
  let currentY = 0
  let isPulling = false
  let isReloading = false
  let reloadCooldownUntil = 0

  try {
    const previousReloadAt = Number(window.sessionStorage.getItem(RELOAD_KEY) || '0')
    if (Number.isFinite(previousReloadAt) && previousReloadAt > 0) {
      reloadCooldownUntil = previousReloadAt + RELOAD_COOLDOWN_MS
    }
  } catch (_error) {
    reloadCooldownUntil = 0
  }

  const indicator = document.createElement('div')
  indicator.setAttribute('aria-hidden', 'true')
  indicator.style.cssText = [
    'position:fixed',
    'top:0',
    'left:0',
    'right:0',
    'height:0',
    'overflow:hidden',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'background:#fff',
    'color:#05131D',
    'font-family:system-ui,sans-serif',
    'font-size:1.75rem',
    'z-index:9999',
    'transition:height 0.15s ease',
    'pointer-events:none',
    'user-select:none',
  ].join(';')
  document.documentElement.appendChild(indicator);

  function clearPullState() {
    isPulling = false
    startY = 0
    currentY = 0
    indicator.style.height = '0'
  }

  function isCoolingDown() {
    return Date.now() < reloadCooldownUntil
  }

  function navigateForRefresh() {
    const refreshAt = Date.now()
    reloadCooldownUntil = refreshAt + RELOAD_COOLDOWN_MS
    isReloading = true
    try {
      window.sessionStorage.setItem(RELOAD_KEY, String(refreshAt))
    } catch (_error) {
      // Ignore sessionStorage failures; the in-memory guard still prevents rapid loops.
    }
    window.location.reload()
  }

  document.addEventListener('touchstart', function (e) {
    if (isReloading || isCoolingDown()) return
    if (e.touches.length !== 1) { clearPullState(); return }
    if (window.scrollY === 0) {
      startY = e.touches[0].clientY
      currentY = startY
      isPulling = true
    }
  }, { passive: true })

  document.addEventListener('touchmove', function (e) {
    if (!isPulling) return
    currentY = e.touches[0].clientY
    const delta = currentY - startY
    if (delta > 0) {
      const h = Math.min(delta * 0.5, THRESHOLD)
      indicator.style.height = h + 'px'
      indicator.textContent = delta > RELOAD_THRESHOLD
        ? '✓ Vapauta päivittymään'
        : '↓ Vedä päivittääksesi'
    } else {
      clearPullState()
    }
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isPulling) return
    const delta = currentY - startY
    clearPullState()
    if (delta > RELOAD_THRESHOLD && !isReloading && !isCoolingDown()) {
      setTimeout(navigateForRefresh, 150)
    }
  }, { passive: true })

  document.addEventListener('touchcancel', clearPullState, { passive: true })
}

setupPullToRefresh()
