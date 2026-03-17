{-# LANGUAGE OverloadedStrings #-}

module HtmlGen (
    renderHead,
    renderCookieConsent,
    renderRevokeButton,
    renderTimelineNav,
    renderIntro,
    renderMonthSection,
    renderFooter,
    renderScript,
    generateHtml,
    renderCard,
) where

import Control.Monad (forM_)
import qualified Data.ByteString.Lazy as LBS
import Data.Function (on)
import Data.List (groupBy)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (TimeLocale, UTCTime, formatTime)
import Data.Time.LocalTime (TimeZone, utcToZonedTime)
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

import Config
import HtmlSanitizer
import I18n
import Scripts
import Styles

-- HTML Generation Components
renderHead :: Config -> H.Html
renderHead config = H.head $ do
    H.meta H.! A.charset "UTF-8"
    H.meta H.! A.name "viewport" H.! A.content "width=device-width, initial-scale=1.0"
    H.title (H.toHtml $ configTitle config <> " \x2014 Suomen Palikkaharrastajat ry")
    H.link H.! A.rel "icon" H.! A.href "/favicon/favicon.ico"
    H.link H.! A.rel "icon" H.! A.type_ "image/png" H.! A.sizes "32x32" H.! A.href "/favicon/favicon-32.png"
    H.link H.! A.rel "apple-touch-icon" H.! A.sizes "180x180" H.! A.href "/favicon/apple-touch-icon.png"
    H.link H.! A.rel "icon" H.! A.type_ "image/png" H.! A.sizes "192x192" H.! A.href "/favicon/icon-192.png"
    H.link H.! A.rel "icon" H.! A.type_ "image/png" H.! A.sizes "512x512" H.! A.href "/favicon/icon-512.png"
    H.style $ H.toHtml css

renderCookieConsent :: Messages -> H.Html
renderCookieConsent msgs = H.div H.! A.id "cookie-consent" H.! A.class_ "cookie-consent hidden" $
    H.div H.! A.class_ "consent-content" $ do
        H.p (H.toHtml (msgCookieConsentText msgs))
        H.button H.! A.id "reject-btn" $ H.toHtml (msgCookieRejectButton msgs)
        H.button H.! A.id "consent-btn" $ H.toHtml (msgCookieConsentButton msgs)

renderRevokeButton :: Messages -> H.Html
renderRevokeButton msgs =
    H.button H.! A.id "revoke-btn" H.! A.class_ "revoke-btn hidden" H.! A.title (H.toValue $ msgRevokeConsentTitle msgs) $
        "⚙️"

renderTimelineNav :: Messages -> TimeLocale -> UTCTime -> TimeZone -> [(Text, Text, [AppItem])] -> H.Html
renderTimelineNav msgs locale now localTZ groups = H.nav H.! A.class_ "timeline" $ do
    H.h2 H.! A.class_ "sr-only" $ H.toHtml (msgTimeline msgs)
    H.div H.! A.class_ "timeline-header" H.! A.attribute "aria-hidden" "" "true" $ H.toHtml (formatTime locale "%Y" (utcToZonedTime localTZ now))
    H.ul $ forM_ groups $ \(monthLabel, monthId, _) ->
        H.li $ H.a H.! A.href (H.toValue $ "#" <> monthId) $ H.toHtml monthLabel

renderIntro :: Config -> H.Html
renderIntro config = H.div H.! A.class_ "intro" $
    H.a H.! A.href "/" H.! A.class_ "site-header-link" $ do
        H.img H.! A.src "/logo/square/square-smile.svg"
              H.! A.alt ""
              H.! H.customAttribute "aria-hidden" "true"
              H.! A.class_ "site-logo"
        H.h1 (H.toHtml $ configTitle config)

renderMonthSection :: TimeLocale -> (Text, Text, [AppItem]) -> H.Html
renderMonthSection locale (monthLabel, monthId, groupItems) = H.div H.! A.id (H.toValue monthId) H.! A.class_ "month-section" $ do
    H.h2 H.! A.class_ "month-title" $ H.toHtml monthLabel
    H.div H.! A.class_ "grid" $
        mapM_ (renderCard locale) groupItems

renderFooter :: Messages -> TimeLocale -> UTCTime -> TimeZone -> H.Html
renderFooter msgs locale now localTZ = H.footer $ do
    H.p (H.toHtml $ msgPoweredBy msgs)
    H.p $ do
        H.toHtml (msgGeneratedOn msgs)
        " "
        H.toHtml (formatTime locale "%Y-%m-%d %H:%M:%S" (utcToZonedTime localTZ now))

renderScript :: H.Html
renderScript = H.script $ H.preEscapedToHtml js

-- HTML Generation
generateHtml :: Config -> Messages -> [AppItem] -> UTCTime -> TimeZone -> LBS.ByteString
generateHtml config msgs items now localTZ = renderHtml $ H.docTypeHtml $ do
    renderHead config
    H.body $ do
        H.a H.! A.href "#main-content" H.! A.class_ "skip-link" $ H.toHtml (msgSkipToContent msgs)
        renderCookieConsent msgs
        renderRevokeButton msgs
        H.div H.! A.class_ "layout" $ do
            renderTimelineNav msgs locale now localTZ groups
            H.main H.! A.id "main-content" H.! A.class_ "main-content" $ do
                renderIntro config
                forM_ groups (renderMonthSection locale)
        renderFooter msgs locale now localTZ
        renderScript
  where
    locale = getTimeLocale (configLocale config)

    -- Group items by Year-Month
    groups = map mkGroup $ groupBy ((==) `on` itemMonth) items

    itemMonth item = case itemDate item of
        Just d -> formatTime locale "%Y-%m" d
        Nothing -> "Unknown"

    mkGroup groupItems =
        let first = head groupItems
            monthLabel = case itemDate first of
                Just d -> T.pack $ formatTime locale "%B %Y" d
                Nothing -> "Older / Undated"
            monthId = case itemDate first of
                Just d -> T.pack $ formatTime locale "m-%Y-%m" d
                Nothing -> "m-unknown"
         in (monthLabel, monthId, groupItems)

renderCard :: TimeLocale -> AppItem -> H.Html
renderCard locale item = H.div H.! A.class_ "card" $ do
    case itemThumbnail item of
        Just url ->
            H.div H.! A.class_ "card-image" $
                H.a H.! A.href (H.textValue $ itemLink item) H.! A.target "_blank" $
                    H.img
                        H.! A.class_ "lazy-consent"
                        H.! H.dataAttribute "src" (H.toValue url)
                        H.! A.alt (H.toValue $ itemTitle item)
        Nothing -> return ()
    H.div H.! A.class_ "card-content" $ do
        case itemSourceLink item of
            Just url -> H.a H.! A.class_ "source" H.! A.href (H.textValue url) H.! A.target "_blank" $ H.toHtml (itemSourceTitle item)
            Nothing -> H.span H.! A.class_ "source" $ H.toHtml (itemSourceTitle item)
        H.h3 $ H.a H.! A.href (H.textValue $ itemLink item) H.! A.target "_blank" $ H.toHtml (itemTitle item)
        case itemDesc item of
            Just d -> H.div H.! A.class_ "description" $ H.preEscapedToHtml (cleanAndTruncate 160 d)
            Nothing -> return ()
    H.div H.! A.class_ "card-meta" $ do
        case itemDate item of
            Just d -> H.div H.! A.class_ "date" $ H.toHtml (formatTime locale "%Y-%m-%d" d)
            Nothing -> return ()
        H.div H.! A.class_ "type-icon" $ case itemType item of
            YouTube -> "🎥"
            Rss -> "📝"
            Flickr -> "📷"
            Kuvatfi -> "📷"
            Atom -> "📝"
