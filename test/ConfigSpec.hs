module ConfigSpec (configTests) where

-- \| Tests for Config module
--

import Test.Tasty
import Test.Tasty.HUnit

import Data.Text (Text)
import qualified Data.Text as T

import Config

configTests :: TestTree
configTests =
    testGroup
        "Config Tests"
        [ testCase "parseConfig valid" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test Planet\""
                        , T.pack "locale = \"en\""
                        , T.pack "timezone = \"Europe/Helsinki\""
                        , T.pack "[[feeds]]"
                        , T.pack "type = \"blog\""
                        , T.pack "title = \"Test Blog\""
                        , T.pack "url = \"http://example.com/rss.xml\""
                        ]
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= T.pack "Test Planet"
                    configLocale config @?= En
                    configTimezone config @?= T.pack "Europe/Helsinki"
                    length (configFeeds config) @?= 1
                    let feed = head (configFeeds config)
                    feedType feed @?= Blog
                    feedTitle feed @?= Just (T.pack "Test Blog")
                    feedUrl feed @?= T.pack "http://example.com/rss.xml"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig invalid feed type" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test\""
                        , T.pack "[[feeds]]"
                        , T.pack "type = \"invalid\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Left _ -> return () -- Should fail
                Right _ -> assertFailure "Should have failed"
        , testCase "parseConfig missing title" $ do
            let toml =
                    T.unlines
                        [ T.pack "[[feeds]]"
                        , T.pack "type = \"blog\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> configTitle config @?= T.pack "Planet"
                Left _ -> assertFailure "Should succeed with default title"
        , testCase "parseConfig default values" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"blog\"", "title = \"Test\"", "url = \"http://example.com\""]
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= T.pack "Planet"
                    configLocale config @?= Fi
                    configTimezone config @?= T.pack "Europe/Helsinki"
                Left _ -> assertFailure "Should succeed with default values"
        , testCase "parseConfig missing feed url" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"blog\"", "title = \"Test\""]
            case parseConfig toml of
                Left _ -> return ()
                Right _ -> assertFailure "Should fail due to missing url"
        , testCase "parseConfig default feed type" $ do
            let toml = T.unlines ["[[feeds]]", "title = \"Test\"", "url = \"http://example.com\""]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedType feed @?= Rss
                Left _ -> assertFailure "Should succeed with default feed type"
        , testCase "parseConfig youtube feed type" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"youtube\"", "title = \"Test YouTube\"", "url = \"http://youtube.com/feed\""]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedType feed @?= YouTube
                    feedTitle feed @?= Just (T.pack "Test YouTube")
                    feedUrl feed @?= T.pack "http://youtube.com/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig flickr feed type" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"flickr\"", "title = \"Test Flickr\"", "url = \"http://flickr.com/feed\""]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedType feed @?= Flickr
                    feedTitle feed @?= Just (T.pack "Test Flickr")
                    feedUrl feed @?= T.pack "http://flickr.com/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig kuvatfi feed type" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"kuvatfi\"", "title = \"Test Kuvatfi\"", "url = \"http://kuvat.fi/feed\""]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedType feed @?= Kuvatfi
                    feedTitle feed @?= Just (T.pack "Test Kuvatfi")
                    feedUrl feed @?= T.pack "http://kuvat.fi/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "parseConfig atom feed type" $ do
            let toml = T.unlines ["[[feeds]]", "type = \"atom\"", "title = \"Test Atom\"", "url = \"http://atom.com/feed\""]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedType feed @?= Atom
                    feedTitle feed @?= Just (T.pack "Test Atom")
                    feedUrl feed @?= T.pack "http://atom.com/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        ]
