{-# LANGUAGE OverloadedStrings #-}

module ConfigSpec (configTests) where

import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Config
import I18n

configTests :: TestTree
configTests =
    testGroup
        "Config"
        [ testCase "parses rss feed config" $ do
            let toml =
                    T.unlines
                        [ "title = \"Test Planet\""
                        , "locale = \"en\""
                        , "timezone = \"Europe/Helsinki\""
                        , "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"Test Blog\""
                        , "url = \"http://example.com/rss.xml\""
                        ]
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= "Test Planet"
                    configLocale config @?= En
                    configTimezone config @?= "Europe/Helsinki"
                    configDefaultGroup config @?= "default"
                    length (configFeeds config) @?= 1
                    let feed = head (configFeeds config)
                    feedType feed @?= Feed
                    feedTitle feed @?= Just "Test Blog"
                    feedUrl feed @?= "http://example.com/rss.xml"
                    feedGroup feed @?= "default"
                    feedExcludeList feed @?= []
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "rejects invalid feed type" $ do
            let toml =
                    T.unlines
                        [ "title = \"Test\""
                        , "[[feeds]]"
                        , "type = \"invalid\""
                        , "title = \"Test\""
                        , "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Left _ -> pure ()
                Right _ -> assertFailure "Should have failed"
        , testCase "defaults title and locale values" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"blog\""
                        , "title = \"Test\""
                        , "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> do
                    configTitle config @?= "Planet"
                    configLocale config @?= Fi
                    configTimezone config @?= "Europe/Helsinki"
                    configDefaultGroup config @?= "default"
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "maps atom to feed" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"atom\""
                        , "title = \"Test Atom\""
                        , "url = \"http://example.com/feed.xml\""
                        ]
            case parseConfig toml of
                Right config -> feedType (head (configFeeds config)) @?= Feed
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "missing type defaults to feed" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "title = \"Test\""
                        , "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> feedType (head (configFeeds config)) @?= Feed
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "supports youtube and image feeds" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"youtube\""
                        , "title = \"Videos\""
                        , "url = \"http://youtube.com/feed\""
                        , "[[feeds]]"
                        , "type = \"flickr\""
                        , "title = \"Photos\""
                        , "url = \"http://flickr.com/feed\""
                        ]
            case parseConfig toml of
                Right config -> map feedType (configFeeds config) @?= [YouTube, Image]
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "rejects missing url" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"blog\""
                        , "title = \"Broken\""
                        ]
            case parseConfig toml of
                Left _ -> pure ()
                Right _ -> assertFailure "Should fail due to missing url"
        , testCase "supports default_group and feed-level group override" $ do
            let toml =
                    T.unlines
                        [ "default_group = \"fi\""
                        , "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"Default Group Feed\""
                        , "url = \"http://example.com/default.xml\""
                        , "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"English Feed\""
                        , "url = \"http://example.com/en.xml\""
                        , "group = \"en\""
                        ]
            case parseConfig toml of
                Right config -> do
                    configDefaultGroup config @?= "fi"
                    map feedGroup (configFeeds config) @?= ["fi", "en"]
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "supports feed exclude_list" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"Feed with excludes\""
                        , "url = \"http://example.com/feed.xml\""
                        , "exclude_list = [\"https://example.com/a\", \"https://example.com/b\"]"
                        ]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    feedExcludeList feed @?= ["https://example.com/a", "https://example.com/b"]
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "supports optional feed link override" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"Test\""
                        , "url = \"http://example.com/feed.xml\""
                        , "link = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> feedLink (head (configFeeds config)) @?= Just "http://example.com"
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        , testCase "feedLink defaults to Nothing when omitted" $ do
            let toml =
                    T.unlines
                        [ "[[feeds]]"
                        , "type = \"rss\""
                        , "title = \"Test\""
                        , "url = \"http://example.com/feed.xml\""
                        ]
            case parseConfig toml of
                Right config -> feedLink (head (configFeeds config)) @?= Nothing
                Left err -> assertFailure ("Parse failed: " ++ T.unpack err)
        ]
