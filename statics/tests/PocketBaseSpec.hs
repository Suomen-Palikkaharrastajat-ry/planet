{-# LANGUAGE OverloadedStrings #-}

module PocketBaseSpec (pocketBaseTests) where

import Data.Aeson (eitherDecode)
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.Maybe (isJust)
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

import Config (FeedConfig (..))
import I18n (AppItem (..), FeedType (..))
import PocketBase

pocketBaseTests :: TestTree
pocketBaseTests =
    testGroup
        "PocketBase"
        [ backendDetectionTests
        , dateParsingTests
        , jsonDecodingTests
        , mapperTests
        ]

backendDetectionTests :: TestTree
backendDetectionTests =
    testGroup
        "detectBackend"
        [ testCase "defaults to TomlBackend on empty env" $
            detectBackend [] @?= TomlBackend
        , testCase "explicit PLANET_BACKEND=toml selects TomlBackend" $
            detectBackend [("PLANET_BACKEND", "toml")] @?= TomlBackend
        , testCase "explicit PLANET_BACKEND=file selects TomlBackend" $
            detectBackend [("PLANET_BACKEND", "file")] @?= TomlBackend
        , testCase "explicit PLANET_BACKEND=pocketbase selects PocketBaseBackend" $
            case detectBackend [("PLANET_BACKEND", "pocketbase")] of
                PocketBaseBackend cfg -> do
                    pbUrl cfg @?= "http://127.0.0.1:8090"
                    pbToken cfg @?= Nothing
                    pbFeedsCollection cfg @?= "feeds"
                    pbItemsCollection cfg @?= "feed_items"
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "explicit PLANET_BACKEND=pb selects PocketBaseBackend" $
            case detectBackend [("PLANET_BACKEND", "pb")] of
                PocketBaseBackend _ -> pure ()
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "case-insensitivity and whitespace in PLANET_BACKEND" $
            case detectBackend [("PLANET_BACKEND", "  POCKETBASE  ")] of
                PocketBaseBackend _ -> pure ()
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "PLANET_BACKEND=toml takes precedence over POCKETBASE_URL" $
            detectBackend [("PLANET_BACKEND", "toml"), ("POCKETBASE_URL", "https://pb.example.com")]
                @?= TomlBackend
        , testCase "POCKETBASE_URL selects PocketBaseBackend when PLANET_BACKEND unset" $
            case detectBackend [("POCKETBASE_URL", "https://pb.example.com/")] of
                PocketBaseBackend cfg -> pbUrl cfg @?= "https://pb.example.com"
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "strips trailing slashes from POCKETBASE_URL" $
            case detectBackend [("PLANET_BACKEND", "pb"), ("POCKETBASE_URL", "http://my-host:8090///")] of
                PocketBaseBackend cfg -> pbUrl cfg @?= "http://my-host:8090"
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "reads token and custom collections from environment" $ do
            let env =
                    [ ("PLANET_BACKEND", "pocketbase")
                    , ("POCKETBASE_URL", "http://localhost:8090")
                    , ("POCKETBASE_TOKEN", "secret123")
                    , ("POCKETBASE_FEEDS_COLLECTION", "custom_feeds")
                    , ("POCKETBASE_ITEMS_COLLECTION", "custom_items")
                    ]
            case detectBackend env of
                PocketBaseBackend cfg -> do
                    pbUrl cfg @?= "http://localhost:8090"
                    pbToken cfg @?= Just "secret123"
                    pbFeedsCollection cfg @?= "custom_feeds"
                    pbItemsCollection cfg @?= "custom_items"
                    pbSince cfg @?= Nothing
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "reads POCKETBASE_SINCE from environment" $ do
            let env =
                    [ ("PLANET_BACKEND", "pocketbase")
                    , ("POCKETBASE_SINCE", "2026-10-15")
                    ]
            case detectBackend env of
                PocketBaseBackend cfg -> do
                    let expectedDate = UTCTime (fromGregorian 2026 10 15) 0
                    pbSince cfg @?= Just expectedDate
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "reads PLANET_POCKETBASE_SINCE and POCKETBASE_FIRST_DATE aliases" $ do
            let env1 =
                    [("POCKETBASE_URL", "http://localhost:8090"), ("PLANET_POCKETBASE_SINCE", "2026-06-01T12:00:00Z")]
                env2 = [("POCKETBASE_URL", "http://localhost:8090"), ("POCKETBASE_FIRST_DATE", "2026-06-01 12:00:00Z")]
                expected = UTCTime (fromGregorian 2026 6 1) (secondsToDiffTime (12 * 3600))
            case detectBackend env1 of
                PocketBaseBackend cfg -> pbSince cfg @?= Just expected
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
            case detectBackend env2 of
                PocketBaseBackend cfg -> pbSince cfg @?= Just expected
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        , testCase "handles invalid POCKETBASE_SINCE gracefully as Nothing" $ do
            let env = [("PLANET_BACKEND", "pocketbase"), ("POCKETBASE_SINCE", "not-a-valid-date")]
            case detectBackend env of
                PocketBaseBackend cfg -> pbSince cfg @?= Nothing
                TomlBackend -> assertFailure "Expected PocketBaseBackend"
        ]

dateParsingTests :: TestTree
dateParsingTests =
    testGroup
        "parsePocketBaseDate"
        [ testCase "parses PocketBase format with space and millis" $ do
            let expected = UTCTime (fromGregorian 2026 11 1) (secondsToDiffTime (12 * 3600 + 34 * 60 + 56))
            parsePocketBaseDate "2026-11-01 12:34:56.000Z" @?= Just expected
        , testCase "parses PocketBase format with space without millis" $ do
            let expected = UTCTime (fromGregorian 2026 11 1) (secondsToDiffTime (12 * 3600 + 34 * 60 + 56))
            parsePocketBaseDate "2026-11-01 12:34:56Z" @?= Just expected
        , testCase "parses standard ISO8601 with T" $ do
            let expected = UTCTime (fromGregorian 2026 11 1) (secondsToDiffTime (8 * 3600))
            parsePocketBaseDate "2026-11-01T08:00:00Z" @?= Just expected
        , testCase "parses date-only string" $ do
            let expected = UTCTime (fromGregorian 2026 11 1) (secondsToDiffTime 0)
            parsePocketBaseDate "2026-11-01" @?= Just expected
        , testCase "returns Nothing for empty or invalid string" $ do
            parsePocketBaseDate "" @?= Nothing
            parsePocketBaseDate "invalid-date" @?= Nothing
        ]

jsonDecodingTests :: TestTree
jsonDecodingTests =
    testGroup
        "jsonDecoding"
        [ testCase "decodes PBListResponse" $ do
            let jsonStr = "{\"page\": 1, \"perPage\": 50, \"totalItems\": 100, \"totalPages\": 2, \"items\": []}"
            case eitherDecode jsonStr of
                Right (PBListResponse p pp ti tp items) -> do
                    p @?= 1
                    pp @?= 50
                    ti @?= 100
                    tp @?= 2
                    items @?= ([] :: [PBFeedRecord])
                Left err -> assertFailure ("Decode failed: " ++ err)
        , testCase "decodes PBFeedRecord with expand.groups" $ do
            let jsonStr =
                    LBS8.pack $
                        unlines
                            [ "{"
                            , "  \"id\": \"fd001\","
                            , "  \"url\": \"https://example.com/rss\","
                            , "  \"title\": \"Example Feed\","
                            , "  \"site_url\": \"https://example.com\","
                            , "  \"feed_type\": \"rss\","
                            , "  \"enabled\": true,"
                            , "  \"exclude_keywords\": [\"spoiler\"],"
                            , "  \"exclude_urls\": [\"https://example.com/ad\"],"
                            , "  \"expand\": {"
                            , "    \"groups\": ["
                            , "      {\"id\": \"grp1\", \"name\": \"fi\", \"title\": \"Suomi\"}"
                            , "    ]"
                            , "  }"
                            , "}"
                            ]
            case eitherDecode jsonStr of
                Right feed -> do
                    pbfId feed @?= "fd001"
                    pbfUrl feed @?= "https://example.com/rss"
                    pbfTitle feed @?= Just "Example Feed"
                    pbfSiteUrl feed @?= Just "https://example.com"
                    pbfFeedType feed @?= Just "rss"
                    pbfEnabled feed @?= Just True
                    pbfExcludeKeywords feed @?= Just ["spoiler"]
                    pbfExcludeUrls feed @?= Just ["https://example.com/ad"]
                    case pbfExpand feed >>= pbfeGroups of
                        Just (g : _) -> pbgName g @?= "fi"
                        _ -> assertFailure "Expected expanded group"
                Left err -> assertFailure ("Decode failed: " ++ err)
        , testCase "decodes PBItemRecord with expand.feed" $ do
            let jsonStr =
                    LBS8.pack $
                        unlines
                            [ "{"
                            , "  \"id\": \"item001\","
                            , "  \"feed\": \"fd001\","
                            , "  \"guid\": \"guid-123\","
                            , "  \"link\": \"https://example.com/post/1\","
                            , "  \"title\": \"Post Title &amp; More\","
                            , "  \"description\": \"Full HTML description\","
                            , "  \"snippet\": \"Clean text snippet\","
                            , "  \"author\": \"Builder Joe\","
                            , "  \"published_at\": \"2026-11-01 10:00:00.000Z\","
                            , "  \"thumbnail\": \"https://example.com/thumb.jpg\","
                            , "  \"media_type\": \"article\","
                            , "  \"is_hidden\": false,"
                            , "  \"expand\": {"
                            , "    \"feed\": {"
                            , "      \"id\": \"fd001\","
                            , "      \"url\": \"https://example.com/rss\","
                            , "      \"title\": \"Example Feed\","
                            , "      \"site_url\": \"https://example.com\","
                            , "      \"feed_type\": \"rss\","
                            , "      \"expand\": {"
                            , "        \"groups\": [{\"id\": \"g1\", \"name\": \"fi\", \"title\": \"Suomi\"}]"
                            , "      }"
                            , "    }"
                            , "  }"
                            , "}"
                            ]
            case eitherDecode jsonStr of
                Right item -> do
                    pbiId item @?= "item001"
                    pbiLink item @?= "https://example.com/post/1"
                    pbiTitle item @?= "Post Title &amp; More"
                    pbiSnippet item @?= Just "Clean text snippet"
                    pbiIsHidden item @?= Just False
                    assertBool "feed is expanded" (isJust (pbiExpand item))
                Left err -> assertFailure ("Decode failed: " ++ err)
        ]

mapperTests :: TestTree
mapperTests =
    testGroup
        "mappers"
        [ testCase "toFeedConfig converts PBFeedRecord properly" $ do
            let feedRecord =
                    PBFeedRecord
                        { pbfId = "fd01"
                        , pbfUrl = "https://example.com/atom"
                        , pbfTitle = Just "Blog Title"
                        , pbfSiteUrl = Just "https://example.com"
                        , pbfFeedType = Just "youtube"
                        , pbfGroups = Nothing
                        , pbfEnabled = Just True
                        , pbfExcludeKeywords = Just ["spam"]
                        , pbfExcludeUrls = Just ["https://example.com/ignore"]
                        , pbfExpand =
                            Just
                                ( PBFeedExpand
                                    (Just [PBGroupRecord (Just "g1") "en" (Just "English")])
                                )
                        }
                cfg = toFeedConfig feedRecord
            feedType cfg @?= YouTube
            feedTitle cfg @?= Just "Blog Title"
            feedUrl cfg @?= "https://example.com/atom"
            feedGroup cfg @?= "en"
            feedExcludeList cfg @?= ["https://example.com/ignore"]
            feedExcludeKeywords cfg @?= ["spam"]
            feedLink cfg @?= Just "https://example.com"
        , testCase "toAppItem converts PBItemRecord and cleans title" $ do
            let feedRecord =
                    PBFeedRecord
                        { pbfId = "fd01"
                        , pbfUrl = "https://example.com/rss"
                        , pbfTitle = Just "The Lego Blog"
                        , pbfSiteUrl = Just "https://example.com"
                        , pbfFeedType = Just "rss"
                        , pbfGroups = Nothing
                        , pbfEnabled = Just True
                        , pbfExcludeKeywords = Nothing
                        , pbfExcludeUrls = Nothing
                        , pbfExpand =
                            Just
                                ( PBFeedExpand
                                    (Just [PBGroupRecord (Just "g1") "fi" (Just "Suomi")])
                                )
                        }
                itemRecord =
                    PBItemRecord
                        { pbiId = "it01"
                        , pbiFeed = Just "fd01"
                        , pbiGuid = Just "guid-1"
                        , pbiLink = "https://example.com/post/1"
                        , pbiTitle = "Lego &amp; Bricks #moc"
                        , pbiDescription = Just "<p>Content</p>"
                        , pbiSnippet = Just "Short summary"
                        , pbiAuthor = Just "Master Builder"
                        , pbiPublishedAt = "2026-11-01 12:00:00.000Z"
                        , pbiThumbnail = Just "https://example.com/pic.png"
                        , pbiMediaType = Just "article"
                        , pbiIsHidden = Just False
                        , pbiExpand = Just (PBItemExpand (Just feedRecord))
                        }
                appItem = toAppItem itemRecord

            -- cleanTitle removes trailing non-numeric hashtags and unescapes entities
            itemTitle appItem @?= "Lego & Bricks"
            itemLink appItem @?= "https://example.com/post/1"
            itemDescSnippet appItem @?= Just "Short summary"
            itemThumbnail appItem @?= Just "https://example.com/pic.png"
            itemSourceTitle appItem @?= "The Lego Blog"
            itemSourceLink appItem @?= Just "https://example.com"
            itemType appItem @?= Feed
            itemGroup appItem @?= "fi"
            assertBool "date is parsed" (isJust (itemDate appItem))
        , testCase "toAppItem handles missing feed expansion gracefully" $ do
            let itemRecord =
                    PBItemRecord
                        { pbiId = "it02"
                        , pbiFeed = Nothing
                        , pbiGuid = Just "guid-2"
                        , pbiLink = "https://example.com/post/2"
                        , pbiTitle = "Solo Post"
                        , pbiDescription = Nothing
                        , pbiSnippet = Nothing
                        , pbiAuthor = Just "Author Name"
                        , pbiPublishedAt = "2026-11-01"
                        , pbiThumbnail = Nothing
                        , pbiMediaType = Just "video"
                        , pbiIsHidden = Just False
                        , pbiExpand = Nothing
                        }
                appItem = toAppItem itemRecord
            itemSourceTitle appItem @?= "Author Name"
            itemSourceLink appItem @?= Nothing
            itemType appItem @?= YouTube
            itemGroup appItem @?= "fi"
        ]
