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
// Source: https://github.com/Suomen-Palikkaharrastajat-ry/master-builder/blob/refs/heads/main/index.js
function setupPullToRefresh() {
  if (window.__pullToRefreshSetup) return
  window.__pullToRefreshSetup = true

  const isStandalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  if (!isStandalone) return

  const REVEAL_THRESHOLD = 20
  const ARM_THRESHOLD = 148
  const MAX_PULL_DISTANCE = 196
  const MENU_HEIGHT = 52
  const IMMEDIATE_REARM_MS = 400
  let startY = 0
  let currentY = 0
  let isPulling = false
  let isReloading = false
  let allowPullUntil = 0

  const indicator = document.createElement('div')
  indicator.setAttribute('aria-hidden', 'true')
  indicator.style.cssText = [
    'position:fixed',
    'top:0',
    'left:0',
    'right:0',
    'height:72px',
    'display:flex',
    'justify-content:center',
    'padding:8px 16px 12px',
    'z-index:9999',
    'pointer-events:none',
    'user-select:none',
    'transform:translateY(-100%)',
    'opacity:0',
    'margin-top:2rem',
  ].join(';')

  const action = document.createElement('div')
  action.style.cssText = [
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'width:min(100%, 20rem)',
    `min-height:${MENU_HEIGHT}px`,
    'padding:0 16px',
    'color:#000000',
    'font-family:var(--font-sans, Outfit, system-ui, sans-serif)',
    'font-size:1.75rem',
    'font-weight:500',
    'line-height:1.5',
    'opacity:0.3',
    'border-bottom:2px solid transparent',
    'transform:translateY(0)',
  ].join(';')

  const label = document.createElement('span')
  label.textContent = '⟳ Päivitä sivu'

  action.appendChild(label)
  indicator.appendChild(action)
  document.documentElement.appendChild(indicator)

  function clearPullState() {
    isPulling = false
    startY = 0
    currentY = 0
    indicator.style.transform = 'translateY(-100%)'
    indicator.style.opacity = '0'
    action.style.opacity = '0.3'
    action.style.borderBottomColor = 'transparent'
    action.style.transform = 'translateY(0)'
  }

  function updateIndicator(delta) {
    if (delta <= REVEAL_THRESHOLD) {
      indicator.style.transform = 'translateY(-100%)'
      indicator.style.opacity = '0'
      return
    }

    const progress = Math.min(
      (delta - REVEAL_THRESHOLD) / (MAX_PULL_DISTANCE - REVEAL_THRESHOLD),
      1
    )
    const translateY = -100 + 100 * progress
    const isArmed = delta >= ARM_THRESHOLD

    indicator.style.transform = `translateY(${translateY}%)`
    indicator.style.opacity = '1'
    action.style.transform = `translateY(${Math.max(0, 10 - (progress * 10))}px)`

    if (isArmed) {
      action.style.opacity = '1'
      action.style.borderBottomColor = '#000000'
    } else {
      action.style.opacity = '0.3'
      action.style.borderBottomColor = 'transparent'
    }
  }

  document.addEventListener('touchstart', function (e) {
    if (isReloading) return
    if (e.touches.length !== 1) { clearPullState(); return }

    const isAtTop = window.scrollY === 0
    const isWithinRearmWindow = performance.now() <= allowPullUntil

    if (isAtTop || isWithinRearmWindow) {
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
      updateIndicator(delta)
    } else {
      clearPullState()
    }
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isPulling) return
    const delta = currentY - startY
    allowPullUntil = performance.now() + IMMEDIATE_REARM_MS
    clearPullState()
    if (delta >= ARM_THRESHOLD && !isReloading) {
      isReloading = true
      setTimeout(() => window.location.reload(), 0)
    }
  }, { passive: true })

  document.addEventListener('touchcancel', function () {
    allowPullUntil = performance.now() + IMMEDIATE_REARM_MS
    clearPullState()
  }, { passive: true })
}

setupPullToRefresh()
