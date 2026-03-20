{-# LANGUAGE OverloadedStrings #-}
module Main (main, tests) where

import Test.Tasty
import Test.Tasty.HUnit

import qualified Data.Text as T
import Data.Time
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.Time.Zones
import Data.Time.Zones.All
import Data.XML.Types
import qualified Text.Atom.Feed as Atom
import Text.Feed.Types
import Text.HTML.TagSoup
import Text.HTML.TagSoup.Tree (TagTree (..))

import Data.Aeson (Value (..), decode, encode, object, (.=))
import qualified Data.Aeson.KeyMap as KM
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import Config
import qualified ElmGen
import qualified FeedParser
import HtmlSanitizer
import I18n
import PocketBase
    ( decodeAppItemFromPb
    , encodeAppItemToPb
    , urlEncodeFilter
    )
import PocketBaseSync
    ( UpsertAction (..)
    , buildUpsertAction
    )

-- Helper function for tests
join :: Maybe (Maybe a) -> Maybe a
join (Just (Just x)) = Just x
join _ = Nothing

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
    testGroup
        "Planet Tests"
        [ invariantsTests
        , i18nTests
        , configTests
        , feedTests
        , htmlTests
        , utilityTests
        , pocketBaseTests
        ]

invariantsTests :: TestTree
invariantsTests =
    testGroup
        "Invariants" -- Core system invariants that must never fail
        [ testCase "HTML sanitization: cleanAndTruncate short text" $ do
            let text = T.pack "<p>Short text</p>"
            cleanAndTruncate 100 text @?= T.pack "<p>Short text</p>"
        , testCase "HTML sanitization: cleanAndTruncate long text" $ do
            let text = T.pack $ "<p>" ++ replicate 300 'a' ++ "</p>"
            let result = cleanAndTruncate 160 text
            assertBool "Truncated" (T.length result < T.length text)
            assertBool "Contains ..." (T.isInfixOf (T.pack "...") result)
        , testCase "HTML sanitization: normalizeVoids" $ do
            let tags = [TagOpen (T.pack "img") [(T.pack "src", T.pack "test")]]
                normalized = normalizeVoids tags
            length normalized @?= 2 -- Should add closing tag
        , testCase "HTML sanitization: pruneTree removes empty" $ do
            let tree = [TagBranch (T.pack "div") [] []]
                pruned = pruneTree tree
            length pruned @?= 0
        , testCase "HTML sanitization: pruneTree keeps content" $ do
            let tree = [TagBranch (T.pack "p") [] [TagLeaf (TagText (T.pack "content"))]]
                pruned = pruneTree tree
            length pruned @?= 1
        , testCase "HTML sanitization: takeWithLimit exact" $ do
            let tags = [TagText (T.pack "hello")]
                result = takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello")]
        , testCase "HTML sanitization: takeWithLimit truncate" $ do
            let tags = [TagText (T.pack "hello world")]
                result = takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello...")]
        ]

i18nTests :: TestTree
i18nTests =
    testGroup
        "I18n Tests" -- Covers US-002, constrained by ADR-0000
        [ testCase "parseLocale en" $ parseLocale (T.pack "en") @?= En
        , testCase "parseLocale fi" $ parseLocale (T.pack "fi") @?= Fi
        , testCase "parseLocale unknown" $ parseLocale (T.pack "unknown") @?= defaultLocale
        , testCase "getMessages En" $ msgGeneratedOn (getMessages En) @?= T.pack "Generated on"
        , testCase "getMessages Fi" $ msgGeneratedOn (getMessages Fi) @?= T.pack "Koottu"
        , testCase "getTimeLocale En" $ wDays (getTimeLocale En) @?= wDays defaultTimeLocale
        , testCase "getTimeLocale Fi" $ head (months (getTimeLocale Fi)) @?= ("tammikuu", "tammi")
        ]

configTests :: TestTree
configTests =
    testGroup
        "Config Tests" -- Covers US-002, constrained by ADR-0000
        [ testCase "PlanetMain.parseConfig valid" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test Planet\""
                        , T.pack "locale = \"en\""
                        , T.pack "timezone = \"Europe/Helsinki\""
                        , T.pack "[[feeds]]"
                        , T.pack "type = \"rss\""
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
                    Config.feedType feed @?= I18n.Feed
                    feedTitle feed @?= Just (T.pack "Test Blog")
                    feedUrl feed @?= T.pack "http://example.com/rss.xml"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig invalid feed type" $ do
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
        , testCase "PlanetMain.parseConfig missing title" $ do
            let toml =
                    T.unlines
                        [ T.pack "[[feeds]]"
                        , T.pack "type = \"rss\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> configTitle config @?= T.pack "Planet"
                Left _ -> assertFailure "Should succeed with default title"
        , testCase "PlanetMain.parseConfig atom type" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test\""
                        , T.pack "[[feeds]]"
                        , T.pack "type = \"atom\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    Config.feedType feed @?= I18n.Feed
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig missing type defaults to rss" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test\""
                        , T.pack "[[feeds]]"
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> do
                    let feed = head (configFeeds config)
                    Config.feedType feed @?= I18n.Feed
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig default type is rss" $ do
            let toml =
                    T.unlines
                        [ T.pack "title = \"Test\""
                        , T.pack "[[feeds]]"
                        , T.pack "type = \"default\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case Config.parseConfig toml of
                Right config -> do
                    let feed = head (Config.configFeeds config)
                    Config.feedType feed @?= I18n.Feed
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig default values" $ do
            let toml = T.unlines [T.pack "[[feeds]]", T.pack "type = \"blog\"", T.pack "title = \"Test\"", T.pack "url = \"http://example.com\""]
            case Config.parseConfig toml of
                Right config -> do
                    Config.configTitle config @?= T.pack "Planet"
                    Config.configLocale config @?= I18n.Fi
                    Config.configTimezone config @?= T.pack "Europe/Helsinki"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig missing feed url" $ do
            let toml = T.unlines [T.pack "[[feeds]]", T.pack "type = \"blog\"", T.pack "title = \"Test\""]
            case Config.parseConfig toml of
                Left _ -> return ()
                Right _ -> assertFailure "Should fail due to missing url"
        , testCase "PlanetMain.parseConfig youtube feed type" $ do
            let toml = T.unlines [T.pack "[[feeds]]", T.pack "type = \"youtube\"", T.pack "title = \"Test YouTube\"", T.pack "url = \"http://youtube.com/feed\""]
            case Config.parseConfig toml of
                Right config -> do
                    let feed = head (Config.configFeeds config)
                    Config.feedType feed @?= I18n.YouTube
                    Config.feedTitle feed @?= Just (T.pack "Test YouTube")
                    Config.feedUrl feed @?= T.pack "http://youtube.com/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig flickr feed type" $ do
            let toml = T.unlines [T.pack "[[feeds]]", T.pack "type = \"flickr\"", T.pack "title = \"Test Flickr\"", T.pack "url = \"http://flickr.com/feed\""]
            case Config.parseConfig toml of
                Right config -> do
                    let feed = head (Config.configFeeds config)
                    Config.feedType feed @?= I18n.Image
                    Config.feedTitle feed @?= Just (T.pack "Test Flickr")
                    Config.feedUrl feed @?= T.pack "http://flickr.com/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        , testCase "PlanetMain.parseConfig kuvatfi feed type" $ do
            let toml = T.unlines [T.pack "[[feeds]]", T.pack "type = \"kuvatfi\"", T.pack "title = \"Test Kuvatfi\"", T.pack "url = \"http://kuvat.fi/feed\""]
            case Config.parseConfig toml of
                Right config -> do
                    let feed = head (Config.configFeeds config)
                    Config.feedType feed @?= I18n.Image
                    Config.feedTitle feed @?= Just (T.pack "Test Kuvatfi")
                    Config.feedUrl feed @?= T.pack "http://kuvat.fi/feed"
                Left err -> assertFailure $ "Parse failed: " ++ T.unpack err
        ]

feedTests :: TestTree
feedTests =
    testGroup
        "Feed Tests" -- Covers US-001, US-006, constrained by ADR-0000
        [ testCase "PlanetMain.extractFirstImage" $ do
            let html = T.pack "<p>Some text <img src=\"http://example.com/image.jpg\" alt=\"test\"> more text</p>"
            FeedParser.extractFirstImage html @?= Just (T.pack "http://example.com/image.jpg")
        , testCase "PlanetMain.extractFirstImage no image" $ do
            let html = T.pack "<p>Some text without image</p>"
            FeedParser.extractFirstImage html @?= Nothing
        , testCase "PlanetMain.getMediaDescription" $ do
            let mediaElements = [Element (Name (T.pack "description") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeContent (ContentText (T.pack "Test description"))]]
            FeedParser.getMediaDescriptionFromElements mediaElements @?= Just (T.pack "Test description")
        , testCase "PlanetMain.isMediaDescription true" $ do
            let e = Element (Name (T.pack "description") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            FeedParser.isMediaDescription e @?= True
        , testCase "PlanetMain.isMediaDescription false" $ do
            let e = Element (Name (T.pack "description") Nothing Nothing) [] []
            FeedParser.isMediaDescription e @?= False
        , testCase "PlanetMain.isMediaThumbnail true" $ do
            let e = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            FeedParser.isMediaThumbnail e @?= True
        , testCase "PlanetMain.isMediaGroup true" $ do
            let e = Element (Name (T.pack "group") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            FeedParser.isMediaGroup e @?= True
        , testCase "PlanetMain.getUrlAttr" $ do
            let attrs = [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])]
                e = Element (Name (T.pack "thumbnail") Nothing Nothing) attrs []
            FeedParser.getUrlAttr e @?= Just (T.pack "http://example.com")
        , testCase "PlanetMain.getUrlAttr no url" $ do
            let attrs = [(Name (T.pack "other") Nothing Nothing, [ContentText (T.pack "value")])]
                e = Element (Name (T.pack "thumbnail") Nothing Nothing) attrs []
            FeedParser.getUrlAttr e @?= Nothing
        , testCase "PlanetMain.findMediaThumbnail" $ do
            let e = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])] []
                mediaElements = [e]
            FeedParser.findMediaThumbnail mediaElements @?= Just (T.pack "http://example.com")
        , testCase "PlanetMain.findMediaGroupThumbnail" $ do
            let thumb = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])] []
                group = Element (Name (T.pack "group") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeElement thumb]
                mediaElements = [group]
            FeedParser.findMediaGroupThumbnail mediaElements @?= Just (T.pack "http://example.com")
        , testCase "join Just Just" $ join (Just (Just "test")) @?= Just "test"
        , testCase "join Just Nothing" $ (join (Just Nothing) :: Maybe String) @?= Nothing
        , testCase "join Nothing" $ (join Nothing :: Maybe String) @?= Nothing
        , testCase "FeedParser.stripFirstPTag with p tag" $ do
            -- Covers US-006
            let html = T.pack "<p>This is content</p><p>More</p>"
            FeedParser.stripFirstPTag html @?= T.pack "<p>More</p>"
        , testCase "FeedParser.stripFirstPTag flickr-like description" $ do
            let html = T.pack "<p><a href=\"https://www.flickr.com/photos/12345/67890/\">Photo on Flickr</a></p>This is the actual description. It has <b>some</b> formatting."
            FeedParser.stripFirstPTag html @?= T.pack "This is the actual description. It has <b>some</b> formatting."
        , testCase "FeedParser.stripFirstPTag flickr encoded content" $ do
            let html = T.pack "&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/people/infamousq/&quot;&gt;InfamousQ&lt;/a&gt; posted a photo:&lt;/p&gt;\n\t\n&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/photos/infamousq/54774659725/&quot; title=&quot;Plan for Tervahovi LEGO display version 2&quot;&gt;&lt;img src=&quot;https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg&quot; width=&quot;240&quot; height=&quot;135&quot; alt=&quot;Plan for Tervahovi LEGO display version 2&quot; /&gt;&lt;/a&gt;&lt;/p&gt;\n\n&lt;p&gt;Further development of the Tervahovi harbor area&lt;/p&gt;"
            FeedParser.stripFirstPTag html @?= T.pack "\n\t\n<p><a href=\"https://www.flickr.com/photos/infamousq/54774659725/\" title=\"Plan for Tervahovi LEGO display version 2\"><img src=\"https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg\" width=\"240\" height=\"135\" alt=\"Plan for Tervahovi LEGO display version 2\"></img></a></p>\n\n<p>Further development of the Tervahovi harbor area</p>"
        , testCase "FeedParser.cleanTitle remove hashtags" $ do
            -- Covers US-001
            let title = T.pack "My post #tag1 #tag2"
            FeedParser.cleanTitle title @?= T.pack "My post"
        , testCase "FeedParser.cleanTitle keep number hashtags" $ do
            -- Covers US-001
            let title = T.pack "My post #123 #tag"
            FeedParser.cleanTitle title @?= T.pack "My post #123"
        , testCase "FeedParser.cleanTitle no hashtags" $ do
            -- Covers US-001
            let title = T.pack "My post without hashtags"
            FeedParser.cleanTitle title @?= T.pack "My post without hashtags"
        , testCase "getFlickrMediaDescription with HTMLContent" $ do
            let now = read "2023-01-01 00:00:00 UTC"
                entry =
                    (Atom.nullEntry (T.pack "tag:example.com,2023:test") (undefined :: Atom.TextContent) now)
                        { Atom.entryContent = Just (Atom.HTMLContent (T.pack "<p>first</p><p>second</p>"))
                        }
                item = AtomItem entry
            FeedParser.getFlickrMediaDescription item @?= Just (T.pack "<p>second</p>")
        , testCase "getAtomMediaDescription with HTMLContent" $ do
            let now = read "2023-01-01 00:00:00 UTC"
                entry =
                    (Atom.nullEntry (T.pack "tag:example.com,2023:test") (undefined :: Atom.TextContent) now)
                        { Atom.entryContent = Just (Atom.HTMLContent (T.pack "<p>first</p><p>second</p>"))
                        }
                item = AtomItem entry
            FeedParser.getAtomMediaDescription item @?= Just (T.pack "<p>first</p><p>second</p>")
        , testCase "FeedParser.parseItem Atom published date preferred" $ do
            let publishedDate = T.pack "2025-12-31T23:55:00Z"
                updatedDate = T.pack "2026-01-01T17:45:09Z"
                entry =
                    (Atom.nullEntry (T.pack "id") (Atom.TextString (T.pack "Test Atom Title")) (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryPublished = Just publishedDate
                        , Atom.entryUpdated = updatedDate
                        , Atom.entryLinks = [Atom.nullLink (T.pack "http://example.com/atom-link")]
                        }
                item = AtomItem entry
                feedConfig = FeedConfig Feed (Just $ T.pack "Test Feed") (T.pack "http://example.com")
                expectedDate = iso8601ParseM (T.unpack publishedDate)

            FeedParser.parseItem feedConfig Nothing item @?= Just (AppItem (T.pack "Test Atom Title") (T.pack "http://example.com/atom-link") expectedDate Nothing Nothing Nothing Nothing (T.pack "Test Feed") Nothing Feed)
        , testCase "FeedParser.parseItem Atom updated date used if published missing" $ do
            let updatedDate = T.pack "2026-01-01T17:45:09Z"
                entry =
                    (Atom.nullEntry (T.pack "id") (Atom.TextString (T.pack "Test Atom Title")) (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryPublished = Nothing
                        , Atom.entryUpdated = updatedDate
                        , Atom.entryLinks = [Atom.nullLink (T.pack "http://example.com/atom-link")]
                        }
                item = AtomItem entry
                feedConfig = FeedConfig Feed (Just $ T.pack "Test Feed") (T.pack "http://example.com")
                expectedDate = iso8601ParseM (T.unpack updatedDate)

            FeedParser.parseItem feedConfig Nothing item @?= Just (AppItem (T.pack "Test Atom Title") (T.pack "http://example.com/atom-link") expectedDate Nothing Nothing Nothing Nothing (T.pack "Test Feed") Nothing Feed)
        , testCase "FeedParser.parseItem Atom updated date used when published is missing" $ do
            let updatedDate = T.pack "2026-01-01T17:45:09Z"
                entry =
                    (Atom.nullEntry (T.pack "id") (Atom.TextString (T.pack "Test Atom Title")) (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryPublished = Nothing
                        , Atom.entryUpdated = updatedDate
                        , Atom.entryLinks = [Atom.nullLink (T.pack "http://example.com/atom-link")]
                        }
                item = AtomItem entry
                feedConfig = FeedConfig Feed (Just $ T.pack "Test Feed") (T.pack "http://example.com")
                expectedDate = iso8601ParseM (T.unpack updatedDate)

            FeedParser.parseItem feedConfig Nothing item @?= Just (AppItem (T.pack "Test Atom Title") (T.pack "http://example.com/atom-link") expectedDate Nothing Nothing Nothing Nothing (T.pack "Test Feed") Nothing Feed)
        ]

htmlTests :: TestTree
htmlTests =
    testGroup
        "Elm Generation Tests" -- Tests for ElmGen module
        [ testCase "ElmGen.generateElmModule basic" $ do
            let items = []
                elmCode = ElmGen.generateElmModule items
            -- Check it contains expected module structure
            assertBool "Contains module declaration" (T.isInfixOf (T.pack "module Data exposing") elmCode)
            assertBool "Contains FeedType type" (T.isInfixOf (T.pack "type FeedType") elmCode)
            assertBool "Contains AppItem type" (T.isInfixOf (T.pack "type alias AppItem") elmCode)
            assertBool "Contains allAppItems" (T.isInfixOf (T.pack "allAppItems : List AppItem") elmCode)
        , testCase "ElmGen.generateElmModule with items" $ do
            let item = AppItem (T.pack "Test Title") (T.pack "http://example.com") (Just $ read "2023-01-01 00:00:00 UTC") (Just (T.pack "Test desc")) Nothing Nothing Nothing (T.pack "Test Source") Nothing Feed
                elmCode = ElmGen.generateElmModule [item]
            assertBool "Contains item title" (T.isInfixOf (T.pack "Test Title") elmCode)
            assertBool "Contains item link" (T.isInfixOf (T.pack "http://example.com") elmCode)
            assertBool "Contains Feed type" (T.isInfixOf (T.pack "itemType = Feed") elmCode)
        , testCase "ElmGen.generateElmModule escapes strings" $ do
            let item = AppItem (T.pack "Title with \"quotes\"") (T.pack "http://example.com") Nothing Nothing Nothing Nothing Nothing (T.pack "Source") Nothing Feed
                elmCode = ElmGen.generateElmModule [item]
            assertBool "Escapes quotes" (T.isInfixOf (T.pack "\\\"quotes\\\"") elmCode)
        , testCase "ElmGen.generateElmModule all feed types" $ do
            let feedItem = AppItem (T.pack "") (T.pack "") Nothing Nothing Nothing Nothing Nothing (T.pack "") Nothing Feed
                youtubeItem = AppItem (T.pack "") (T.pack "") Nothing Nothing Nothing Nothing Nothing (T.pack "") Nothing YouTube
                imageItem = AppItem (T.pack "") (T.pack "") Nothing Nothing Nothing Nothing Nothing (T.pack "") Nothing Image
                items = [feedItem, youtubeItem, imageItem]
                elmCode = ElmGen.generateElmModule items

            assertBool "Contains Feed type" (T.isInfixOf (T.pack "itemType = Feed") elmCode)
            assertBool "Contains YouTube type" (T.isInfixOf (T.pack "itemType = YouTube") elmCode)
            assertBool "Contains Image type" (T.isInfixOf (T.pack "itemType = Image") elmCode)
        ]

utilityTests :: TestTree
utilityTests =
    testGroup
        "Utility Tests" -- Covers US-005, constrained by ADR-0000
        [ testCase "join Just Just" $ join (Just (Just "x")) @?= Just "x"
        , testCase "join Just Nothing" $ join (Just Nothing :: Maybe (Maybe String)) @?= Nothing
        , testCase "join Nothing" $ join (Nothing :: Maybe (Maybe String)) @?= Nothing
        ]

-- ---------------------------------------------------------------------------
-- PocketBase unit tests (no live PocketBase required)
-- ---------------------------------------------------------------------------

samplePbRecord :: Value
samplePbRecord = object
    [ "id"           .= ("abc123" :: T.Text)
    , "link"         .= ("https://example.com" :: T.Text)
    , "title"        .= ("Hello" :: T.Text)
    , "source_title" .= ("Example Blog" :: T.Text)
    , "feed_type"    .= ("feed" :: T.Text)
    , "pub_date"     .= ("2023-01-15T10:00:00Z" :: T.Text)
    ]

sampleAppItem :: AppItem
sampleAppItem = AppItem
    { itemTitle       = T.pack "Hello"
    , itemLink        = T.pack "https://example.com"
    , itemDate        = Nothing
    , itemDesc        = Nothing
    , itemDescText    = Nothing
    , itemDescSnippet = Nothing
    , itemThumbnail   = Nothing
    , itemSourceTitle = T.pack "Example Blog"
    , itemSourceLink  = Nothing
    , itemType        = Feed
    }

pocketBaseTests :: TestTree
pocketBaseTests =
    testGroup
        "PocketBase Tests" -- Covers ADR-0001; unit tests run without live PocketBase
        [ testCase "decodeAppItemFromPb: valid record" $
            case decodeAppItemFromPb samplePbRecord of
                Left err   -> assertFailure $ "Decode failed: " <> err
                Right item -> do
                    itemLink  item @?= T.pack "https://example.com"
                    itemTitle item @?= T.pack "Hello"
                    itemType  item @?= Feed

        , testCase "decodeAppItemFromPb: missing link fails" $ do
            let record = object
                    [ "title"        .= ("Hello" :: T.Text)
                    , "source_title" .= ("Blog" :: T.Text)
                    , "feed_type"    .= ("feed" :: T.Text)
                    ]
            case decodeAppItemFromPb record of
                Left _  -> return ()  -- expected
                Right _ -> assertFailure "Should fail when link is missing"

        , testCase "encodeAppItemToPb: correct keys present" $ do
            let val = encodeAppItemToPb sampleAppItem
            case val of
                Object km -> do
                    assertBool "has link"         $ KM.member "link"         km
                    assertBool "has title"        $ KM.member "title"        km
                    assertBool "has source_title" $ KM.member "source_title" km
                    assertBool "has feed_type"    $ KM.member "feed_type"    km
                _ -> assertFailure "Expected JSON object"

        , testCase "encodeAppItemToPb: feed_type is 'feed'" $ do
            let val = encodeAppItemToPb sampleAppItem
            case val of
                Object km ->
                    KM.lookup "feed_type" km @?= Just (String "feed")
                _ -> assertFailure "Expected JSON object"

        , testCase "encodeAppItemToPb: youtube feed_type" $ do
            let item = sampleAppItem { itemType = YouTube }
                val  = encodeAppItemToPb item
            case val of
                Object km ->
                    KM.lookup "feed_type" km @?= Just (String "youtube")
                _ -> assertFailure "Expected JSON object"

        , testCase "encodeAppItemToPb: image feed_type" $ do
            let item = sampleAppItem { itemType = Image }
                val  = encodeAppItemToPb item
            case val of
                Object km ->
                    KM.lookup "feed_type" km @?= Just (String "image")
                _ -> assertFailure "Expected JSON object"

        , testCase "buildUpsertAction: Create when link absent" $ do
            let linkMap = Map.empty :: Map T.Text T.Text
            buildUpsertAction linkMap sampleAppItem @?= Create

        , testCase "buildUpsertAction: Update when link present" $ do
            let linkMap = Map.singleton (T.pack "https://example.com") (T.pack "rec001")
            buildUpsertAction linkMap sampleAppItem @?= Update (T.pack "rec001")

        , testCase "buildUpsertAction: picks first match (Map.fromListWith keeps first)" $ do
            let linkMap = Map.fromListWith (\_ old -> old)
                    [ (T.pack "https://example.com", T.pack "first-id")
                    , (T.pack "https://example.com", T.pack "second-id")
                    ]
            buildUpsertAction linkMap sampleAppItem @?= Update (T.pack "first-id")

        , testCase "urlEncodeFilter: encodes link= filter" $ do
            let result = urlEncodeFilter (T.pack "link=\"https://example.com\"")
            -- '=' -> %3D, '"' -> %22, ':' -> %3A, '/' -> %2F
            assertBool "contains %3D" $ T.isInfixOf (T.pack "%3D") result
            assertBool "contains %22" $ T.isInfixOf (T.pack "%22") result
            assertBool "contains %3A" $ T.isInfixOf (T.pack "%3A") result
            assertBool "contains %2F" $ T.isInfixOf (T.pack "%2F") result

        , testCase "urlEncodeFilter: alphanumeric unchanged" $ do
            let result = urlEncodeFilter (T.pack "abc123")
            result @?= T.pack "abc123"

        , testCase "urlEncodeFilter: safe chars unchanged" $ do
            let result = urlEncodeFilter (T.pack "-_.~")
            result @?= T.pack "-_.~"
        ]
