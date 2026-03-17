{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module I18n (
    FeedType (..),
    AppItem (..),
    Locale (..),
    Messages (..),
    messagesEn,
    messagesFi,
    getMessages,
    getTimeLocale,
    defaultLocale,
    parseLocale,
    fiTimeLocale,
) where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Time.Format (TimeLocale (..), defaultTimeLocale)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON (..))

-- Configuration Types
data FeedType = Feed | YouTube | Image
    deriving (Show, Eq, Generic, ToJSON)

-- App Data Types
data AppItem = AppItem
    { itemTitle :: Text
    , itemLink :: Text
    , itemDate :: Maybe UTCTime
    , itemDesc :: Maybe Text
    , itemDescText :: Maybe Text
    , itemDescSnippet :: Maybe Text
    , itemThumbnail :: Maybe Text
    , itemSourceTitle :: Text
    , itemSourceLink :: Maybe Text
    , itemType :: FeedType
    }
    deriving (Show, Eq, Generic, ToJSON)

-- Supported locales
data Locale = En | Fi
    deriving (Show, Eq, Read)

-- Message keys
data Messages = Messages
    { msgLatestVideos :: Text
    , msgLatestPosts :: Text
    , msgGeneratedOn :: Text
    , msgPoweredBy :: Text
    , msgCookieConsentTitle :: Text
    , msgCookieConsentText :: Text
    , msgCookieConsentButton :: Text
    , msgCookieRejectButton :: Text
    , msgRevokeConsentTitle :: Text
    , msgSkipToContent :: Text
    , msgTimeline :: Text
    }

-- Translations
messagesEn :: Messages
messagesEn =
    Messages
        { msgLatestVideos = "Latest Videos"
        , msgLatestPosts = "Latest Posts"
        , msgGeneratedOn = "Generated on"
        , msgPoweredBy = "Powered by Haskell Planet Generator"
        , msgCookieConsentTitle = "Cookie Consent"
        , msgCookieConsentText = "This site uses external images that may track you. Do you agree to load them?"
        , msgCookieConsentButton = "I Agree"
        , msgCookieRejectButton = "Reject"
        , msgRevokeConsentTitle = "Revoke consent"
        , msgSkipToContent = "Skip to main content"
        , msgTimeline = "Timeline"
        }

messagesFi :: Messages
messagesFi =
    Messages
        { msgLatestVideos = "Uusimmat videot"
        , msgLatestPosts = "Uusimmat kirjoitukset"
        , msgGeneratedOn = "Koottu"
        , msgPoweredBy = "Suomen Palikkaharrastajat ry:n tuottama syötekooste"
        , msgCookieConsentTitle = "Yksityisyys"
        , msgCookieConsentText = "Tämä sivu käyttää ulkoisia kuvia, jotka voivat seurata sinua. Sallitko niiden lataamisen?"
        , msgCookieConsentButton = "Salli"
        , msgCookieRejectButton = "Estä"
        , msgRevokeConsentTitle = "Muuta asetuksia"
        , msgSkipToContent = "Siirry pääsisältöön"
        , msgTimeline = "Aikajana"
        }

getMessages :: Locale -> Messages
getMessages En = messagesEn
getMessages Fi = messagesFi

getTimeLocale :: Locale -> TimeLocale
getTimeLocale En = defaultTimeLocale
getTimeLocale Fi = fiTimeLocale

defaultLocale :: Locale
defaultLocale = Fi

parseLocale :: Text -> Locale
parseLocale "en" = En
parseLocale "fi" = Fi
parseLocale _ = defaultLocale

fiTimeLocale :: TimeLocale
fiTimeLocale =
    defaultTimeLocale
        { wDays =
            [ ("sunnuntai", "su")
            , ("maanantai", "ma")
            , ("tiistai", "ti")
            , ("keskiviikko", "ke")
            , ("torstai", "to")
            , ("perjantai", "pe")
            , ("lauantai", "la")
            ]
        , months =
            [ ("tammikuu", "tammi")
            , ("helmikuu", "helmi")
            , ("maaliskuu", "maalis")
            , ("huhtikuu", "huhti")
            , ("toukokuu", "touko")
            , ("kesäkuu", "kesä")
            , ("heinäkuu", "heinä")
            , ("elokuu", "elo")
            , ("syyskuu", "syys")
            , ("lokakuu", "loka")
            , ("marraskuu", "marras")
            , ("joulukuu", "joulu")
            ]
        , amPm = ("ap.", "ip.")
        , dateTimeFmt = "%d.%m.%Y %H.%M.%S"
        , dateFmt = "%d.%m.%Y"
        , timeFmt = "%H.%M.%S"
        , time12Fmt = "%H.%M.%S"
        }
