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

// ── Pull-to-refresh ──────────────────────────────────────────────────────────
;(function initPullToRefresh() {
  // Touch-primary devices only (excludes mouse/trackpad users)
  if (!window.matchMedia('(pointer: coarse)').matches) return

  const THRESHOLD    = 80    // damped px needed to trigger reload
  const DAMPING      = 0.45  // pull resistance (< 1 feels native)
  const RELOAD_DELAY = 500   // ms of spinner before window.location.reload

  const prefersReducedMotion =
    window.matchMedia('(prefers-reduced-motion: reduce)').matches

  // Feather refresh-cw icon
  const REFRESH_ICON = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
      viewBox="0 0 24 24" fill="none" stroke="currentColor"
      stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <polyline points="23 4 23 10 17 10"></polyline>
    <polyline points="1 20 1 14 7 14"></polyline>
    <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path>
  </svg>`

  const indicator = document.createElement('div')
  indicator.id = 'ptr-indicator'
  indicator.setAttribute('aria-hidden', 'true')
  indicator.innerHTML = REFRESH_ICON
  document.body.appendChild(indicator)

  const svg = indicator.querySelector('svg')

  const RESTING_Y = -52  // px — keeps badge fully above viewport at rest

  let touchStartY  = 0
  let currentPull  = 0  // current damped pull in px
  let isDragging   = false
  let isTriggered  = false

  function applyPull(dampedPull) {
    currentPull = dampedPull
    indicator.style.transform =
      `translateX(-50%) translateY(${RESTING_Y + dampedPull}px)`
    if (!prefersReducedMotion) {
      const deg = Math.min(dampedPull / THRESHOLD, 1) * 270
      svg.style.transform = `rotate(${deg}deg)`
    }
  }

  function resetIndicator() {
    currentPull = 0
    indicator.style.transition = ''  // restore stylesheet transition for snap-back
    indicator.style.transform =
      `translateX(-50%) translateY(${RESTING_Y}px)`
    if (!prefersReducedMotion) svg.style.transform = 'rotate(0deg)'
  }

  function triggerRefresh() {
    isTriggered = true
    indicator.style.transition = ''
    indicator.style.transform =
      `translateX(-50%) translateY(${RESTING_Y + THRESHOLD}px)`
    indicator.classList.add('ptr-spinning')
    svg.style.transform = ''  // hand rotation to keyframe animation
    setTimeout(function () { window.location.reload(true) }, RELOAD_DELAY)
  }

  document.addEventListener('touchstart', function (e) {
    if (window.scrollY !== 0 || e.touches.length !== 1) return
    touchStartY = e.touches[0].clientY
    isDragging  = true
    indicator.style.transition = 'none'  // instant response while dragging
  }, { passive: true })

  document.addEventListener('touchmove', function (e) {
    if (!isDragging || isTriggered) return
    if (window.scrollY !== 0) { isDragging = false; resetIndicator(); return }

    const rawPull = e.touches[0].clientY - touchStartY
    if (rawPull <= 0) { applyPull(0); return }

    applyPull(rawPull * DAMPING)
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isDragging || isTriggered) return
    isDragging = false

    if (currentPull >= THRESHOLD) {
      triggerRefresh()
    } else {
      resetIndicator()
    }
  }, { passive: true })
})()
