{-# LANGUAGE OverloadedStrings #-}

module FeedParserSpec (feedParserTests) where

import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.XML.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))
import qualified Text.Atom.Feed as Atom
import Text.Feed.Types (Item (AtomItem, RSSItem))
import qualified Text.RSS.Syntax as RSS
import qualified Data.ByteString.Lazy as LBS

import Config
import FeedParser
import I18n

feedParserTests :: TestTree
feedParserTests =
    testGroup
        "FeedParser"
        [ testCase "extractFirstImage finds image src" $
            extractFirstImage "<p>Some text <img src=\"http://example.com/image.jpg\" alt=\"test\"> more text</p>"
                @?= Just "http://example.com/image.jpg"
        , testCase "extractFirstImage returns Nothing without image" $
            extractFirstImage "<p>Some text without image</p>" @?= Nothing
        , testCase "extractFirstImage skips tracking pixels" $
            extractFirstImage "<img src=\"http://track.example.com/px.gif\" width=\"1\" height=\"1\"><img src=\"http://example.com/real.jpg\">"
                @?= Just "http://example.com/real.jpg"
        , testCase "extractFirstImage returns Nothing for only tracking pixel" $
            extractFirstImage "<img src=\"http://track.example.com/px.gif\" width=\"1\" height=\"1\">"
                @?= Nothing
        , testCase "getMediaDescriptionFromElements reads media description" $ do
            let elements = [mediaDescriptionElement "Test description"]
            getMediaDescriptionFromElements elements @?= Just "Test description"
        , testCase "findMediaThumbnail reads thumbnail url" $ do
            let elements = [mediaThumbnailElement "http://example.com/image.jpg"]
            findMediaThumbnail elements @?= Just "http://example.com/image.jpg"
        , testCase "findMediaGroupThumbnail reads thumbnail inside media group" $ do
            let thumb = mediaThumbnailElement "http://example.com/image.jpg"
                group = Element (Name "group" (Just mediaNs) Nothing) [] [NodeElement thumb]
            findMediaGroupThumbnail [group] @?= Just "http://example.com/image.jpg"
        , testCase "stripFirstPTag removes leading paragraph wrapper" $
            stripFirstPTag "<p>This is content</p><p>More</p>" @?= "<p>More</p>"
        , testCase "stripFirstPTag decodes flickr-style encoded content" $
            stripFirstPTag "&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/people/infamousq/&quot;&gt;InfamousQ&lt;/a&gt; posted a photo:&lt;/p&gt;\n\t\n&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/photos/infamousq/54774659725/&quot; title=&quot;Plan for Tervahovi LEGO display version 2&quot;&gt;&lt;img src=&quot;https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg&quot; width=&quot;240&quot; height=&quot;135&quot; alt=&quot;Plan for Tervahovi LEGO display version 2&quot; /&gt;&lt;/a&gt;&lt;/p&gt;\n\n&lt;p&gt;Further development of the Tervahovi harbor area&lt;/p&gt;"
                @?= "\n\t\n<p><a href=\"https://www.flickr.com/photos/infamousq/54774659725/\" title=\"Plan for Tervahovi LEGO display version 2\"><img src=\"https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg\" width=\"240\" height=\"135\" alt=\"Plan for Tervahovi LEGO display version 2\"></img></a></p>\n\n<p>Further development of the Tervahovi harbor area</p>"
        , testCase "cleanTitle removes trailing hashtags" $
            cleanTitle "My post #tag1 #tag2" @?= "My post"
        , testCase "cleanTitle keeps numeric hashtags" $
            cleanTitle "My post #123 #tag" @?= "My post #123"
        , testCase "getFlickrMediaDescription skips first paragraph" $ do
            let item = atomItemWithContent "<p>first</p><p>second</p>"
            getFlickrMediaDescription item @?= Just "<p>second</p>"
        , testCase "getAtomMediaDescription keeps full HTML content" $ do
            let item = atomItemWithContent "<p>first</p><p>second</p>"
            getAtomMediaDescription item @?= Just "<p>first</p><p>second</p>"
        , testCase "getContentEncoded extracts content:encoded from RSS item" $ do
            let item = rssItemWithContentEncoded "<p>Hello <img src=\"http://example.com/img.jpg\"> world</p>"
            getContentEncoded item @?= Just "<p>Hello <img src=\"http://example.com/img.jpg\"> world</p>"
        , testCase "getContentEncoded returns Nothing for Atom item" $ do
            let item = atomItemWithContent "<p>content</p>"
            getContentEncoded item @?= Nothing
        , testCase "extractFirstImage finds image in content:encoded" $ do
            let item = rssItemWithContentEncoded "<p><img src=\"http://example.com/thumb.jpg\"></p>"
            (getContentEncoded item >>= extractFirstImage) @?= Just "http://example.com/thumb.jpg"
        , testCase "parseItem extracts thumbnail from description when mediaDesc has no image" $ do
            let entry =
                    (Atom.nullEntry "id" (Atom.TextString "Title") (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryContent = Just (Atom.HTMLContent "<p>no images here</p>")
                        , Atom.entrySummary = Just (Atom.HTMLString "<img src=\"http://example.com/desc-thumb.jpg\">")
                        , Atom.entryLinks = [Atom.nullLink "http://example.com/link"]
                        }
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
            fmap itemThumbnail (parseItem feedConfig Nothing (AtomItem entry))
                @?= Just (Just "http://example.com/desc-thumb.jpg")
        , testCase "parseItem prefers Atom published date" $ do
            let publishedDate = "2025-12-31T23:55:00Z"
                updatedDate = "2026-01-01T17:45:09Z"
                entry =
                    (Atom.nullEntry "id" (Atom.TextString "Test Atom Title") (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryPublished = Just publishedDate
                        , Atom.entryUpdated = updatedDate
                        , Atom.entryLinks = [Atom.nullLink "http://example.com/atom-link"]
                        }
                expectedDate = iso8601ParseM (T.unpack publishedDate)
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
            parseItem feedConfig Nothing (AtomItem entry)
                @?= Just
                    ( AppItem
                        "Test Atom Title"
                        "http://example.com/atom-link"
                        expectedDate
                        Nothing
                        Nothing
                        Nothing
                        Nothing
                        "Test Feed"
                        Nothing
                        Feed
                        "fi"
                    )
        , testCase "parseItem uses updated date when published missing" $ do
            let updatedDate = "2026-01-01T17:45:09Z"
                entry =
                    (Atom.nullEntry "id" (Atom.TextString "Test Atom Title") (read "2000-01-01 00:00:00 UTC"))
                        { Atom.entryPublished = Nothing
                        , Atom.entryUpdated = updatedDate
                        , Atom.entryLinks = [Atom.nullLink "http://example.com/atom-link"]
                        }
                expectedDate = iso8601ParseM (T.unpack updatedDate)
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
            parseItem feedConfig Nothing (AtomItem entry)
                @?= Just
                    ( AppItem
                        "Test Atom Title"
                        "http://example.com/atom-link"
                        expectedDate
                        Nothing
                        Nothing
                        Nothing
                        Nothing
                        "Test Feed"
                        Nothing
                        Feed
                        "fi"
                    )
        , testCase "parseItem replaces api.follow.it link with Continue reading target from description" $ do
            let trackingLink = "https://api.follow.it/track-rss-story-click/v1/abc123"
                realLink = "https://www.newelementary.com/2026/04/review-71052-series-29-from-lego.html#more"
                resolvedLink = "https://www.newelementary.com/2026/04/review-71052-series-29-from-lego.html"
                description =
                    "<p>Guest writer <a href=\"https://fourbrickstall.com/\">Four Bricks Tall</a>.</p><p>Other links <a href=\"https://www.instagram.com/fourbrickstall\">Instagram</a>.</p><a href=\""
                        <> realLink
                        <> "\">Continue reading \187</a>"
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
                item = rssItemWithLinkAndDescription trackingLink description
            fmap itemLink (parseItem feedConfig Nothing item) @?= Just resolvedLink
        , testCase "parseItem keeps api.follow.it link when no safe article link can be extracted" $ do
            let trackingLink = "https://api.follow.it/track-rss-story-click/v1/abc123"
                description = "<p>No anchors here, just text and an image.</p>"
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
                item = rssItemWithLinkAndDescription trackingLink description
            fmap itemLink (parseItem feedConfig Nothing item) @?= Just trackingLink
        , testCase "parseItem keeps normal non-follow.it link unchanged" $ do
            let normalLink = "https://example.com/posts/123"
                description = "<a href=\"https://elsewhere.example/path\">Continue reading</a>"
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com" "fi" [] Nothing
                item = rssItemWithLinkAndDescription normalLink description
            fmap itemLink (parseItem feedConfig Nothing item) @?= Just normalLink
        , testCase "debugBodyPreview normalizes whitespace and truncates output" $ do
            let longText =
                    T.replicate 200 "abc "
                        |> (\t -> "\n\t" <> t <> "\r\nline2")
                preview = debugBodyPreview (LBS.fromStrict (encodeUtf8 longText))
            assertBool "preview should remove newline/tab characters" (not (T.any (\c -> c == '\n' || c == '\r' || c == '\t') preview))
            assertBool "preview should be truncated to at most 320 chars" (T.length preview <= 320)
        , testCase "debugBodyPreview tolerates invalid UTF-8 bytes" $ do
            let preview = debugBodyPreview (LBS.pack [0xFF, 0xFE, 0x41])
            assertBool "preview should contain surviving ASCII bytes" ("A" `T.isInfixOf` preview)
        ]
  where
    (|>) = flip ($)

    mediaNs = "http://search.yahoo.com/mrss/"

    mediaDescriptionElement textValue =
        Element (Name "description" (Just mediaNs) Nothing) [] [NodeContent (ContentText textValue)]

    mediaThumbnailElement url =
        Element (Name "thumbnail" (Just mediaNs) Nothing) [(Name "url" Nothing Nothing, [ContentText url])] []

    atomItemWithContent content =
        AtomItem $
            (Atom.nullEntry "tag:example.com,2023:test" (Atom.TextString "Title") (read "2023-01-01 00:00:00 UTC"))
                { Atom.entryContent = Just (Atom.HTMLContent content)
                }

    rssItemWithContentEncoded content =
        let base = RSS.nullItem "Title"
            encoded =
                Element
                    (Name "encoded" (Just "http://purl.org/rss/1.0/modules/content/") Nothing)
                    []
                    [NodeContent (ContentText content)]
         in RSSItem $ base{RSS.rssItemOther = [encoded]}

    rssItemWithLinkAndDescription link description =
        let base = RSS.nullItem "Title"
         in RSSItem $
                base
                    { RSS.rssItemLink = Just link
                    , RSS.rssItemDescription = Just description
                    }
