{-# LANGUAGE OverloadedStrings #-}

module ElmGenSpec (elmGenTests) where

import qualified Data.ByteString.Lazy.Char8 as LBS8
import qualified Data.Text as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

import Config
import qualified ElmGen
import I18n

elmGenTests :: TestTree
elmGenTests =
    testGroup
        "ElmGen"
        [ testCase "generateElmModule includes module structure" $ do
            let elmCode = ElmGen.generateElmModule sampleConfig []
            assertBool "module declaration" ("module Data exposing" `T.isInfixOf` elmCode)
            assertBool "FeedType type" ("type FeedType" `T.isInfixOf` elmCode)
            assertBool "AppItem alias" ("type alias AppItem" `T.isInfixOf` elmCode)
            assertBool "defaultGroup value" ("defaultGroup = \"fi\"" `T.isInfixOf` elmCode)
            assertBool "allGroups list" ("allGroups = [ \"fi\", \"en\" ]" `T.isInfixOf` elmCode)
            assertBool "allAppItems" ("allAppItems : List AppItem" `T.isInfixOf` elmCode)
        , testCase "generateElmModule renders all feed types" $ do
            let items =
                    [ sampleItem Feed
                    , sampleItem YouTube
                    , sampleItem Image
                    ]
                elmCode = ElmGen.generateElmModule sampleConfig items
            assertBool "Feed constructor" ("itemType = Feed" `T.isInfixOf` elmCode)
            assertBool "YouTube constructor" ("itemType = YouTube" `T.isInfixOf` elmCode)
            assertBool "Image constructor" ("itemType = Image" `T.isInfixOf` elmCode)
            assertBool "item group rendered" ("itemGroup = \"fi\"" `T.isInfixOf` elmCode)
        , testCase "generateElmModule escapes quotes" $ do
            let elmCode = ElmGen.generateElmModule sampleConfig [sampleItem Feed]
            assertBool "escapes quotes" ("\\\"quoted\\\"" `T.isInfixOf` elmCode)
        , testCase "generateSearchIndex contains title and source" $ do
            let json = LBS8.unpack (ElmGen.generateSearchIndex [sampleItem Feed])
            assertBool "title present" ("Title \\\"quoted\\\"" `elemSubstr` json)
            assertBool "source present" ("Source" `elemSubstr` json)
        , testCase "generateElmModule includes defaultGroup in allGroups even without feeds" $ do
            let configWithoutDefaultFeed =
                    Config
                        { configTitle = "Planet"
                        , configFeeds = [FeedConfig Feed Nothing "http://example.com/en.xml" "en" [] Nothing]
                        , configLocale = Fi
                        , configTimezone = "Europe/Helsinki"
                        , configDefaultGroup = "fi"
                        }
                elmCode = ElmGen.generateElmModule configWithoutDefaultFeed []
            assertBool "contains default group in allGroups" ("allGroups = [ \"fi\", \"en\" ]" `T.isInfixOf` elmCode)
        ]
  where
    elemSubstr needle haystack = needle `T.isInfixOf` T.pack haystack

    sampleConfig =
        Config
            { configTitle = "Planet"
            , configFeeds =
                [ FeedConfig Feed Nothing "http://example.com/fi.xml" "fi" [] Nothing
                , FeedConfig Feed Nothing "http://example.com/en.xml" "en" [] Nothing
                ]
            , configLocale = Fi
            , configTimezone = "Europe/Helsinki"
            , configDefaultGroup = "fi"
            }

    sampleItem feedTypeValue =
        AppItem
            { itemTitle = "Title \"quoted\""
            , itemLink = "http://example.com"
            , itemDate = Just sampleDate
            , itemDesc = Just "<p>Description</p>"
            , itemDescText = Just "Description"
            , itemDescSnippet = Just "Description"
            , itemThumbnail = Just "http://example.com/image.jpg"
            , itemSourceTitle = "Source"
            , itemSourceLink = Just "http://example.com/source"
            , itemType = feedTypeValue
            , itemGroup = "fi"
            }

    sampleDate = UTCTime (fromGregorian 2023 1 1) (secondsToDiffTime 0)
