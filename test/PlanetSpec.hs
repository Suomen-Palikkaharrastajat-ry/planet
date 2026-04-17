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
                            [ FeedConfig Feed (Just "Test Blog") "http://example.com/rss.xml" "fi" [] Nothing
                            , FeedConfig YouTube Nothing "http://youtube.com/feed" "en" [] Nothing
                            ]
                        , configLocale = Fi
                        , configTimezone = "Europe/Helsinki"
                        , configDefaultGroup = "fi"
                        }
                xml = LT.toStrict (generateOpml config (Just "fi"))
            assertBool "contains XML declaration" ("<?xml" `T.isInfixOf` xml)
            assertBool "contains title" ("Test Planet" `T.isInfixOf` xml)
            assertBool "contains feed title" ("Test Blog" `T.isInfixOf` xml)
            assertBool "contains feed URL" ("http://example.com/rss.xml" `T.isInfixOf` xml)
            assertBool "omits non-target group feed" (not ("http://youtube.com/feed" `T.isInfixOf` xml))
        , testCase "generateOpml with Nothing includes all groups" $ do
            let config =
                    Config
                        { configTitle = "Test Planet"
                        , configFeeds =
                            [ FeedConfig Feed (Just "Test Blog") "http://example.com/rss.xml" "fi" [] Nothing
                            , FeedConfig YouTube Nothing "http://youtube.com/feed" "en" [] Nothing
                            ]
                        , configLocale = Fi
                        , configTimezone = "Europe/Helsinki"
                        , configDefaultGroup = "fi"
                        }
                xml = LT.toStrict (generateOpml config Nothing)
            assertBool "contains fi feed URL" ("http://example.com/rss.xml" `T.isInfixOf` xml)
            assertBool "contains en feed URL" ("http://youtube.com/feed" `T.isInfixOf` xml)
        ]
