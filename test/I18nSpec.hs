module I18nSpec (i18nTests) where

-- \| Tests for I18n module
--

import Test.Tasty
import Test.Tasty.HUnit

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Format (TimeLocale (..), defaultTimeLocale)

import I18n

i18nTests :: TestTree
i18nTests =
    testGroup
        "I18n Tests"
        [ testCase "parseLocale en" $ parseLocale (T.pack "en") @?= En
        , testCase "parseLocale fi" $ parseLocale (T.pack "fi") @?= Fi
        , testCase "parseLocale unknown" $ parseLocale (T.pack "unknown") @?= defaultLocale
        , testCase "getMessages En" $ msgGeneratedOn (getMessages En) @?= T.pack "Generated on"
        , testCase "getMessages Fi" $ msgGeneratedOn (getMessages Fi) @?= T.pack "Koottu"
        , testCase "getTimeLocale En" $ wDays (getTimeLocale En) @?= wDays defaultTimeLocale
        , testCase "getTimeLocale Fi" $ head (months (getTimeLocale Fi)) @?= ("tammikuu", "tammi")
        ]
