{-# LANGUAGE OverloadedStrings #-}

module ElmGenSpec (elmGenTests) where

import qualified Data.ByteString.Lazy.Char8 as LBS8
import qualified Data.Text as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

import qualified ElmGen
import I18n

elmGenTests :: TestTree
elmGenTests =
    testGroup
        "ElmGen"
        [ testCase "generateElmModule includes module structure" $ do
            let elmCode = ElmGen.generateElmModule []
            assertBool "module declaration" ("module Data exposing" `T.isInfixOf` elmCode)
            assertBool "FeedType type" ("type FeedType" `T.isInfixOf` elmCode)
            assertBool "AppItem alias" ("type alias AppItem" `T.isInfixOf` elmCode)
            assertBool "allAppItems" ("allAppItems : List AppItem" `T.isInfixOf` elmCode)
        , testCase "generateElmModule renders all feed types" $ do
            let items =
                    [ sampleItem Feed
                    , sampleItem YouTube
                    , sampleItem Image
                    ]
                elmCode = ElmGen.generateElmModule items
            assertBool "Feed constructor" ("itemType = Feed" `T.isInfixOf` elmCode)
            assertBool "YouTube constructor" ("itemType = YouTube" `T.isInfixOf` elmCode)
            assertBool "Image constructor" ("itemType = Image" `T.isInfixOf` elmCode)
        , testCase "generateElmModule escapes quotes" $ do
            let elmCode = ElmGen.generateElmModule [sampleItem Feed]
            assertBool "escapes quotes" ("\\\"quoted\\\"" `T.isInfixOf` elmCode)
        , testCase "generateSearchIndex contains title and source" $ do
            let json = LBS8.unpack (ElmGen.generateSearchIndex [sampleItem Feed])
            assertBool "title present" ("Title \\\"quoted\\\"" `elemSubstr` json)
            assertBool "source present" ("Source" `elemSubstr` json)
        ]
  where
    elemSubstr needle haystack = needle `T.isInfixOf` T.pack haystack

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
            }

    sampleDate = UTCTime (fromGregorian 2023 1 1) (secondsToDiffTime 0)
