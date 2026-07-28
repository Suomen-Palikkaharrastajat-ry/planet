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
        ]
