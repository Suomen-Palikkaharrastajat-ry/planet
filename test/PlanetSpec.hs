{-# LANGUAGE OverloadedStrings #-}

module PlanetSpec (planetTests) where

import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

import Config
import I18n
import Planet (generateOpml)

planetTests :: TestTree
planetTests =
    testGroup
        "Planet"
        [ testCase "generateOpml includes configured feeds" $ do
            let config =
                    Config
                        { configTitle = "Test Planet"
                        , configFeeds =
                            [ FeedConfig Feed (Just "Test Blog") "http://example.com/rss.xml"
                            , FeedConfig YouTube Nothing "http://youtube.com/feed"
                            ]
                        , configLocale = Fi
                        , configTimezone = "Europe/Helsinki"
                        }
                xml = LT.toStrict (generateOpml config)
            assertBool "contains XML declaration" ("<?xml" `T.isInfixOf` xml)
            assertBool "contains title" ("Test Planet" `T.isInfixOf` xml)
            assertBool "contains feed title" ("Test Blog" `T.isInfixOf` xml)
            assertBool "contains feed URL" ("http://example.com/rss.xml" `T.isInfixOf` xml)
        ]
