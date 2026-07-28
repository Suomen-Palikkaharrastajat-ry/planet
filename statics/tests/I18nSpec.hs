{-# LANGUAGE OverloadedStrings #-}

module I18nSpec (i18nTests) where

import qualified Data.Text as T
import Data.Time.Format (TimeLocale (months, wDays), defaultTimeLocale)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import I18n

i18nTests :: TestTree
i18nTests =
    testGroup
        "I18n"
        [ testCase "parseLocale en" $ parseLocale "en" @?= En
        , testCase "parseLocale fi" $ parseLocale "fi" @?= Fi
        , testCase "parseLocale unknown falls back to default" $ parseLocale "unknown" @?= defaultLocale
        , testCase "english messages" $ msgGeneratedOn (getMessages En) @?= T.pack "Generated on"
        , testCase "finnish messages" $ msgGeneratedOn (getMessages Fi) @?= T.pack "Koottu"
        , testCase "english time locale" $ wDays (getTimeLocale En) @?= wDays defaultTimeLocale
        , testCase "finnish month names" $ head (months (getTimeLocale Fi)) @?= ("tammikuu", "tammi")
        ]
