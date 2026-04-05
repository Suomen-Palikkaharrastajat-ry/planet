module FeedParserSpec (feedTests) where

-- \| Tests for FeedParser module
--

import Test.Tasty
import Test.Tasty.HUnit

import Data.Text (Text)
import qualified Data.Text as T
import Data.XML.Types
import Text.HTML.TagSoup

import FeedParser

feedTests :: TestTree
feedTests =
    testGroup
        "Feed Tests"
        [ testCase "extractFirstImage" $ do
            let html = T.pack "<p>Some text <img src=\"http://example.com/image.jpg\" alt=\"test\"> more text</p>"
            extractFirstImage html @?= Just (T.pack "http://example.com/image.jpg")
        , testCase "extractFirstImage no image" $ do
            let html = T.pack "<p>Some text without image</p>"
            extractFirstImage html @?= Nothing
        , testCase "getMediaDescription" $ do
            let elements = [Element (Name (T.pack "description") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeContent (ContentText (T.pack "Test description"))]]
            getMediaDescription elements @?= Just (T.pack "Test description")
        , testCase "isMediaDescription true" $ do
            let e = Element (Name (T.pack "description") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            isMediaDescription e @?= True
        , testCase "isMediaDescription false" $ do
            let e = Element (Name (T.pack "description") Nothing Nothing) [] []
            isMediaDescription e @?= False
        , testCase "isMediaThumbnail true" $ do
            let e = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            isMediaThumbnail e @?= True
        , testCase "isMediaGroup true" $ do
            let e = Element (Name (T.pack "group") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] []
            isMediaGroup e @?= True
        , testCase "getUrlAttr" $ do
            let attrs = [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])]
                e = Element (Name (T.pack "thumbnail") Nothing Nothing) attrs []
            getUrlAttr e @?= Just (T.pack "http://example.com")
        , testCase "getUrlAttr no url" $ do
            let attrs = [(Name (T.pack "other") Nothing Nothing, [ContentText (T.pack "value")])]
                e = Element (Name (T.pack "thumbnail") Nothing Nothing) attrs []
            getUrlAttr e @?= Nothing
        , testCase "findMediaThumbnail" $ do
            let e = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])] []
                elements = [e]
            findMediaThumbnail elements @?= Just (T.pack "http://example.com")
        , testCase "findMediaGroupThumbnail" $ do
            let thumb = Element (Name (T.pack "thumbnail") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [(Name (T.pack "url") Nothing Nothing, [ContentText (T.pack "http://example.com")])] []
                group = Element (Name (T.pack "group") (Just (T.pack "http://search.yahoo.com/mrss/")) Nothing) [] [NodeElement thumb]
                elements = [group]
            findMediaGroupThumbnail elements @?= Just (T.pack "http://example.com")
        , testCase "join Just Just" $ join (Just (Just "test")) @?= Just "test"
        , testCase "join Just Nothing" $ (join (Just Nothing) :: Maybe String) @?= Nothing
        , testCase "join Nothing" $ (join Nothing :: Maybe String) @?= Nothing
        , testCase "stripFirstPTag with p tag" $ do
            let html = T.pack "<p>This is content</p><p>More</p>"
            stripFirstPTag html @?= T.pack "<p>More</p>"
        , testCase "stripFirstPTag flickr encoded content" $ do
            let html = T.pack "&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/people/infamousq/&quot;&gt;InfamousQ&lt;/a&gt; posted a photo:&lt;/p&gt;\n\t\n&lt;p&gt;&lt;a href=&quot;https://www.flickr.com/photos/infamousq/54774659725/&quot; title=&quot;Plan for Tervahovi LEGO display version 2&quot;&gt;&lt;img src=&quot;https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg&quot; width=&quot;240&quot; height=&quot;135&quot; alt=&quot;Plan for Tervahovi LEGO display version 2&quot; /&gt;&lt;/a&gt;&lt;/p&gt;\n\n&lt;p&gt;Further development of the Tervahovi harbor area&lt;/p&gt;"
            stripFirstPTag html @?= T.pack "\n\t\n<p><a href=\"https://www.flickr.com/photos/infamousq/54774659725/\" title=\"Plan for Tervahovi LEGO display version 2\"><img src=\"https://live.staticflickr.com/65535/54774659725_f267ce07b2_m.jpg\" width=\"240\" height=\"135\" alt=\"Plan for Tervahovi LEGO display version 2\" /></a></p>\n\n<p>Further development of the Tervahovi harbor area</p>"
        , testCase "stripFirstPTag without p tag" $ do
            let html = T.pack "<div>Content</div>"
            stripFirstPTag html @?= T.pack "<div>Content</div>"
        ]
