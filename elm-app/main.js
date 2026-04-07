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
  let startY = 0
  let currentY = 0
  let isPulling = false
  let isReloading = false

  const indicator = document.createElement('div')
  indicator.setAttribute('aria-hidden', 'true')
  indicator.style.cssText = [
    'position:fixed',
    'top:2rem',
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
    'transition:transform 0.18s ease, opacity 0.18s ease',
  ].join(';')

  const action = document.createElement('div')
  action.style.cssText = [
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'gap:12px',
    'width:min(100%, 20rem)',
    `min-height:${MENU_HEIGHT}px`,
    'padding:0 16px',
    'border-radius:12px',
    'background:#FFFFFF',
    'color:var(--color-brand, #05131D)',
    'font-family:var(--font-sans, Outfit, system-ui, sans-serif)',
    'font-size:1.75rem',
    'font-weight:500',
    'line-height:1.5',
    'box-shadow:0 1px 2px rgba(5, 19, 29, 0.08)',
    'transition:background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease',
    'transform:translateY(0)',
  ].join(';')

  const dot = document.createElement('span')
  dot.style.cssText = [
    'width:16px',
    'height:16px',
    'border-radius:999px',
    'flex-shrink:0',
    'background:#FAC80A',
    'opacity:0',
    'transition:opacity 0.15s ease',
  ].join(';')

  const label = document.createElement('span')
  label.textContent = 'Päivitä'

  action.appendChild(dot)
  action.appendChild(label)
  indicator.appendChild(action)
  document.documentElement.appendChild(indicator)

  function clearPullState() {
    isPulling = false
    startY = 0
    currentY = 0
    indicator.style.transform = 'translateY(-100%)'
    indicator.style.opacity = '0'
    action.style.background = '#FFFFFF'
    action.style.boxShadow = '0 1px 2px rgba(5, 19, 29, 0.08)'
    action.style.color = 'var(--color-brand, #05131D)'
    action.style.transform = 'translateY(0)'
    dot.style.opacity = '0'
  }

  function navigateForRefresh() {
    isReloading = true
    window.location.reload()
  }

  function updateIndicator(delta) {
    if (delta <= REVEAL_THRESHOLD) {
      indicator.style.transform = 'translateY(-100%)'
      indicator.style.opacity = '0'
      action.style.transform = 'translateY(0)'
      action.style.background = '#FFFFFF'
      action.style.boxShadow = '0 1px 2px rgba(5, 19, 29, 0.08)'
      action.style.color = 'var(--color-brand, #05131D)'
      dot.style.opacity = '0'
      return
    }

    const progress = Math.min(
      (delta - REVEAL_THRESHOLD) / (MAX_PULL_DISTANCE - REVEAL_THRESHOLD),
      1
    )
    const translateY = Math.round((-100 + (100 * progress)) * 10) / 10
    const isArmed = delta >= ARM_THRESHOLD

    indicator.style.transform = `translateY(${translateY}%)`
    indicator.style.opacity = '1'
    action.style.transform = `translateY(${Math.max(0, 10 - (progress * 10))}px)`

    if (isArmed) {
      action.style.background = '#F3F4F6'
      action.style.boxShadow = '0 0 0 1px rgba(5, 19, 29, 0.08)'
      action.style.color = 'var(--color-brand, #05131D)'
      dot.style.opacity = '1'
    } else {
      action.style.background = '#FFFFFF'
      action.style.boxShadow = '0 1px 2px rgba(5, 19, 29, 0.08)'
      action.style.color = 'var(--color-brand, #05131D)'
      dot.style.opacity = '0'
    }
  }

  document.addEventListener('touchstart', function (e) {
    if (isReloading) return
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
      updateIndicator(delta)
    } else {
      clearPullState()
    }
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isPulling) return
    const delta = currentY - startY
    clearPullState()
    if (delta >= ARM_THRESHOLD && !isReloading) {
      setTimeout(navigateForRefresh, 150)
    }
  }, { passive: true })

  document.addEventListener('touchcancel', clearPullState, { passive: true })
}

setupPullToRefresh()
