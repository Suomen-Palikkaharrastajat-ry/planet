module Main (main) where

import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck as QC

import qualified Data.ByteString.Lazy as LBS
import qualified Data.HashMap.Strict as HM
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import Data.Time
import Data.Time.Format (TimeLocale (..), defaultTimeLocale)
import Data.Time.Zones
import Data.Time.Zones.All
import qualified Data.Vector as V
import Data.XML.Types
import qualified Text.Atom.Feed as Atom
import Text.Blaze.Html.Renderer.Text (renderHtml)
import qualified Text.Blaze.Html5 as H
import Text.Feed.Types
import Text.HTML.TagSoup
import Text.HTML.TagSoup.Tree (TagTree (..), flattenTree, tagTree)
import qualified Text.RSS.Syntax as RSS

import qualified FeedParser
import qualified HtmlGen
import I18n
import qualified Planet as PlanetMain

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
        [ i18nTests
        , configTests
        , feedTests
        , htmlTests
        , utilityTests
        ]

i18nTests :: TestTree
i18nTests =
    testGroup
        "I18n Tests"
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
        "Config Tests"
        [ testCase "PlanetMain.parseConfig valid" $ do
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
                    feedTitle feed @?= T.pack "Test Blog"
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
                        , T.pack "type = \"blog\""
                        , T.pack "title = \"Test\""
                        , T.pack "url = \"http://example.com\""
                        ]
            case parseConfig toml of
                Right config -> configTitle config @?= T.pack "Planet"
                Left _ -> assertFailure "Should succeed with default title"
        ]

feedTests :: TestTree
feedTests =
    testGroup
        "Feed Tests"
        [ testCase "PlanetMain.extractFirstImage" $ do
            let html = T.pack "<p>Some text <img src=\"http://example.com/image.jpg\" alt=\"test\"> more text</p>"
            FeedParser.extractFirstImage html @?= Just (T.pack "http://example.com/image.jpg")
        , testCase "PlanetMain.extractFirstImage no image" $ do
            let html = T.pack "<p>Some text without image</p>"
            FeedParser.extractFirstImage html @?= Nothing
        , testCase "PlanetMain.getMediaDescription" $ do
            let elements = [Element (Name (T.pack "description") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeContent (ContentText (T.pack "Test description"))]]
            FeedParser.getMediaDescriptionFromElements elements @?= Just (T.pack "Test description")
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
                elements = [e]
            FeedParser.findMediaThumbnail elements @?= Just (T.pack "http://example.com")
        , testCase "PlanetMain.findMediaGroupThumbnail" $ do
            let thumb = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])] []
                group = Element (Name (T.pack "group") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeElement thumb]
                elements = [group]
            FeedParser.findMediaGroupThumbnail elements @?= Just (T.pack "http://example.com")
        , testCase "join Just Just" $ join (Just (Just "test")) @?= Just "test"
        , testCase "join Just Nothing" $ (join (Just Nothing) :: Maybe String) @?= Nothing
        , testCase "join Nothing" $ (join Nothing :: Maybe String) @?= Nothing
        , testCase "FeedParser.stripFirstPTag with p tag" $ do
            let html = T.pack "<p>This is content</p><p>More</p>"
            FeedParser.stripFirstPTag html @?= T.pack "This is content<p>More</p>"
        , testCase "FeedParser.stripFirstPTag without p tag" $ do
            let html = T.pack "<div>Content</div>"
            FeedParser.stripFirstPTag html @?= T.pack "<div>Content</div>"
        , testCase "FeedParser.cleanTitle remove hashtags" $ do
            let title = T.pack "My post #tag1 #tag2"
            FeedParser.cleanTitle title @?= T.pack "My post"
        , testCase "FeedParser.cleanTitle keep number hashtags" $ do
            let title = T.pack "My post #123 #tag"
            FeedParser.cleanTitle title @?= T.pack "My post #123"
        , testCase "FeedParser.cleanTitle no hashtags" $ do
            let title = T.pack "My post without hashtags"
            FeedParser.cleanTitle title @?= T.pack "My post without hashtags"
        ]

htmlTests :: TestTree
htmlTests =
    testGroup
        "HTML Tests"
        [ testCase "PlanetMain.generateHtml basic" $ do
            let config = Config (T.pack "Test Planet") [] En (T.pack "Europe/Helsinki")
                msgs = getMessages En
                items = []
                now = read "2023-01-01 00:00:00 UTC"
                tz = timeZoneForUTCTime (tzByLabel Europe__Helsinki) now
                html = HtmlGen.generateHtml config msgs items now tz
            -- Just check it doesn't crash and contains expected content
            let htmlText = TE.decodeUtf8 $ LBS.toStrict html
            assertBool "Contains title" (T.isInfixOf (T.pack "Test Planet") htmlText)
        , testCase "PlanetMain.renderCard with date" $ do
            let item = AppItem (T.pack "Test Title") (T.pack "http://example.com") (Just $ read "2023-01-01 00:00:00 UTC") (Just (T.pack "Test desc")) Nothing (T.pack "Test Source") Blog
                locale = defaultTimeLocale
                card = HtmlGen.renderCard locale item
                rendered = renderHtml card
            assertBool "Contains date" (TL.isInfixOf (TL.pack "2023-01-01") rendered)
        ]

utilityTests :: TestTree
utilityTests =
    testGroup
        "Utility Tests"
        [ testCase "PlanetMain.cleanAndTruncate short text" $ do
            let text = T.pack "<p>Short text</p>"
            HtmlGen.cleanAndTruncate 100 text @?= T.pack "<p>Short text</p>"
        , testCase "PlanetMain.cleanAndTruncate long text" $ do
            let text = T.pack $ "<p>" ++ replicate 200 'a' ++ "</p>"
            let result = HtmlGen.cleanAndTruncate 50 text
            assertBool "Truncated" (T.length result < T.length text)
            assertBool "Contains ..." (T.isInfixOf (T.pack "...") result)
        , testCase "PlanetMain.normalizeVoids" $ do
            let tags = [TagOpen (T.pack "img") [(T.pack "src", T.pack "test")]]
                normalized = HtmlGen.normalizeVoids tags
            length normalized @?= 2 -- Should add closing tag
        , testCase "PlanetMain.pruneTree removes empty" $ do
            let tree = [TagBranch (T.pack "div") [] []]
                pruned = HtmlGen.pruneTree tree
            length pruned @?= 0
        , testCase "PlanetMain.pruneTree keeps content" $ do
            let tree = [TagBranch (T.pack "p") [] [TagLeaf (TagText (T.pack "content"))]]
                pruned = HtmlGen.pruneTree tree
            length pruned @?= 1
        , testCase "PlanetMain.takeWithLimit exact" $ do
            let tags = [TagText (T.pack "hello")]
                result = HtmlGen.takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello")]
        , testCase "PlanetMain.takeWithLimit truncate" $ do
            let tags = [TagText (T.pack "hello world")]
                result = HtmlGen.takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello...")]
        ]
