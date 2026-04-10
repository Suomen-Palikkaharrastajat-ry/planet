{-# LANGUAGE OverloadedStrings #-}

module FeedParserSpec (feedParserTests) where

import qualified Data.Text as T
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.XML.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import qualified Text.Atom.Feed as Atom
import Text.Feed.Types (Item (AtomItem))

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
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com"
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
                feedConfig = FeedConfig Feed (Just "Test Feed") "http://example.com"
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
                    )
        ]
  where
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
