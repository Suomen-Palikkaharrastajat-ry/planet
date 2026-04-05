module HtmlGenSpec (htmlTests) where

-- \| Tests for HtmlGen module
--

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import Data.Time
import Data.Time.Zones
import Data.Time.Zones.All
import Text.Blaze.Html.Renderer.Text (renderHtml)
import qualified Text.Blaze.Html5 as H

import HtmlGen
import I18n

htmlTests :: TestTree
htmlTests =
    testGroup
        "HTML Tests"
        [ testCase "generateHtml basic" $ do
            let config = Config (T.pack "Test Planet") [] En (T.pack "Europe/Helsinki")
                msgs = getMessages En
                items = []
                now = read "2023-01-01 00:00:00 UTC"
                tz = timeZoneForUTCTime (tzByLabel Europe__Helsinki) now
                html = generateHtml config msgs items now tz
            -- Just check it doesn't crash and contains expected content
            let htmlText = TE.decodeUtf8 $ LBS.toStrict html
            assertBool "Contains title" (T.isInfixOf (T.pack "Test Planet") htmlText)
        , testCase "renderCard with date" $ do
            let item = AppItem (T.pack "Test Title") (T.pack "http://example.com") (Just $ read "2023-01-01 00:00:00 UTC") (Just (T.pack "Test desc")) Nothing (T.pack "Test Source") Blog
                locale = defaultTimeLocale
                card = renderCard locale item
                rendered = renderHtml card
            assertBool "Contains date" (TL.isInfixOf (TL.pack "2023-01-01") rendered)
        ]
