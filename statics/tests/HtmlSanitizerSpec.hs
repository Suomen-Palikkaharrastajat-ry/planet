{-# LANGUAGE OverloadedStrings #-}

module HtmlSanitizerSpec (htmlSanitizerTests) where

import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))
import Text.HTML.TagSoup (Tag (..))
import Text.HTML.TagSoup.Tree (TagTree (..))

import HtmlSanitizer

htmlSanitizerTests :: TestTree
htmlSanitizerTests =
    testGroup
        "HtmlSanitizer"
        [ testCase "cleanAndTruncate keeps short text" $
            cleanAndTruncate 100 "<p>Short text</p>" @?= "<p>Short text</p>"
        , testCase "cleanAndTruncate truncates long text" $ do
            let input = T.pack ("<p>" ++ replicate 300 'a' ++ "</p>")
                result = cleanAndTruncate 160 input
            assertBool "Truncated output should be shorter" (T.length result < T.length input)
            assertBool "Truncated output should contain ellipsis" ("..." `T.isInfixOf` result)
        , testCase "normalizeVoids closes img tags" $ do
            let normalized = normalizeVoids [TagOpen "img" [("src", "test")]]
            length normalized @?= 2
        , testCase "pruneTree removes empty branches" $
            length (pruneTree [TagBranch "div" [] []]) @?= 0
        , testCase "pruneTree keeps text content" $
            length (pruneTree [TagBranch "p" [] [TagLeaf (TagText "content")]]) @?= 1
        , testCase "takeWithLimit exact length" $
            takeWithLimit 5 [] [TagText "hello"] @?= [TagText "hello"]
        , testCase "takeWithLimit truncates text" $
            takeWithLimit 5 [] [TagText "hello world"] @?= [TagText "hello..."]
        , testCase "isInvisibleFormat recognizes invisible format characters" $ do
            assertBool "zero-width space" (isInvisibleFormat '\x200B')
            assertBool "zero-width joiner" (isInvisibleFormat '\x200D')
            assertBool "rtl mark" (isInvisibleFormat '\x200F')
            assertBool "left-to-right embedding" (isInvisibleFormat '\x202A')
            assertBool "right-to-left override" (isInvisibleFormat '\x202E')
            assertBool "word joiner" (isInvisibleFormat '\x2060')
            assertBool "directional isolate" (isInvisibleFormat '\x2066')
            assertBool "BOM" (isInvisibleFormat '\xFEFF')
            assertBool "normal char 'a'" (not (isInvisibleFormat 'a'))
            assertBool "space" (not (isInvisibleFormat ' '))
            assertBool "newline" (not (isInvisibleFormat '\n'))
        , testCase "stripInvisibleCharacters removes invisible characters" $
            stripInvisibleCharacters "Hello\x200B World\x202E!\xFEFF" @?= "Hello World!"
        , testCase "decodeHtmlEntities decodes standard named entities" $
            decodeHtmlEntities "&quot;Tom &amp; Jerry &lt;3&gt;&apos;s cheese&quot;"
                @?= "\"Tom & Jerry <3>'s cheese\""
        , testCase "decodeHtmlEntities decodes typographic and symbol entities" $
            decodeHtmlEntities "&copy; 2026 &ndash; Palikka &mdash; &trade; &hellip; &bull; 10&deg;"
                @?= "© 2026 – Palikka — ™ … • 10°"
        , testCase "decodeHtmlEntities decodes decimal and hex entities" $ do
            decodeHtmlEntities "&#39;hello&#39;" @?= "'hello'"
            decodeHtmlEntities "&#x27;world&#x27;" @?= "'world'"
            decodeHtmlEntities "&#8212;" @?= "—"
            decodeHtmlEntities "&#x2014;" @?= "—"
        , testCase "decodeHtmlEntities handles double-escaped entities" $ do
            decodeHtmlEntities "&amp;quot;Title&amp;quot;" @?= "\"Title\""
            decodeHtmlEntities "&amp;amp;" @?= "&"
            decodeHtmlEntities "Q&amp;amp;A" @?= "Q&A"
        , testCase "decodeHtmlEntities refuses control characters" $ do
            decodeHtmlEntities "&#1;" @?= "&#1;"
            decodeHtmlEntities "&#x7F;" @?= "&#x7F;"
            decodeHtmlEntities "&#x00;" @?= "&#x00;"
        , testCase "decodeHtmlEntities refuses invisible format characters" $ do
            decodeHtmlEntities "&#x202E;" @?= "&#x202E;"
            decodeHtmlEntities "&#8203;" @?= "&#8203;"
            decodeHtmlEntities "&#xFEFF;" @?= "&#xFEFF;"
            decodeHtmlEntities "&amp;#x202E;" @?= "&#x202E;"
        , testCase "decodeHtmlEntities preserves unknown or malformed entities" $ do
            decodeHtmlEntities "&unknown; & incomplete" @?= "&unknown; & incomplete"
            decodeHtmlEntities "&#xyz;" @?= "&#xyz;"
        ]
