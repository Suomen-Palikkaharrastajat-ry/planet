module UtilsSpec where

-- \| Tests for Utils module
--
-- Covers: US-001 (Aggregate Feeds)
-- Constrained by: ADR-0000-agent-guidance.md
--

import Test.Tasty
import Test.Tasty.HUnit

import Data.Text (Text)
import qualified Data.Text as T
import Text.Feed.Types
import Text.HTML.TagSoup
import Text.HTML.TagSoup.Tree (TagTree (..), flattenTree, tagTree)

import HtmlGen

utilityTests :: TestTree
utilityTests =
    testGroup
        "Utility Tests"
        [ testCase "cleanAndTruncate short text" $ do
            let text = T.pack "<p>Short text</p>"
            cleanAndTruncate 100 text @?= T.pack "<p>Short text</p>"
        , testCase "cleanAndTruncate long text" $ do
            let text = T.pack $ "<p>" ++ replicate 200 'a' ++ "</p>"
            let result = cleanAndTruncate 50 text
            assertBool "Truncated" (T.length result < 100)
            assertBool "Ends with ..." (T.isSuffixOf (T.pack "...") result)
        , testCase "normalizeVoids" $ do
            let tags = [TagOpen (T.pack "img") [(T.pack "src", T.pack "test")]]
                normalized = normalizeVoids tags
            length normalized @?= 2 -- Should add closing tag
        , testCase "pruneTree removes empty" $ do
            let tree = [TagBranch (T.pack "div") [] []]
                pruned = pruneTree tree
            length pruned @?= 0
        , testCase "pruneTree keeps content" $ do
            let tree = [TagBranch (T.pack "p") [] [TagLeaf (TagText (T.pack "content"))]]
                pruned = pruneTree tree
            length pruned @?= 1
        , testCase "takeWithLimit exact" $ do
            let tags = [TagText (T.pack "hello")]
                result = takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello")]
        , testCase "takeWithLimit truncate" $ do
            let tags = [TagText (T.pack "hello world")]
                result = takeWithLimit 5 [] tags
            result @?= [TagText (T.pack "hello...")]
        , testCase "showItemType Atom" $ showItemType (AtomItem undefined) @?= "Atom"
        , testCase "showItemType RSS" $ showItemType (RSSItem undefined) @?= "RSS"
        , testCase "showItemType XML" $ showItemType (XMLItem undefined) @?= "XML"
        ]
