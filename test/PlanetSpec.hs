module PlanetSpec where

-- \| Tests for Planet module
--
-- Covers: US-002 (Configure Planet)
-- Constrained by: ADR-0000-agent-guidance.md
--

import Test.Tasty
import Test.Tasty.HUnit

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT

import Config
import Planet

planetTests :: TestTree
planetTests =
    testGroup
        "Planet Tests"
        [ testCase "generateOpml produces valid XML" $ do
            let config =
                    Config
                        { configTitle = T.pack "Test Planet"
                        , configFeeds =
                            [ FeedConfig Blog (Just $ T.pack "Test Blog") (T.pack "http://example.com/rss.xml")
                            , FeedConfig YouTube Nothing (T.pack "http://youtube.com/feed")
                            ]
                        , configLocale = Fi
                        , configTimezone = T.pack "Europe/Helsinki"
                        }
            let opml = generateOpml config
            let xml = LT.unpack opml
            assertBool "Contains opml" $ "<?xml" `T.isInfixOf` T.pack xml
            assertBool "Contains title" $ "Test Planet" `T.isInfixOf` T.pack xml
            assertBool "Contains feed" $ "Test Blog" `T.isInfixOf` T.pack xml
            assertBool "Contains url" $ "http://example.com/rss.xml" `T.isInfixOf` T.pack xml
        ]
