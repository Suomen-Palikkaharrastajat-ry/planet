{-# LANGUAGE OverloadedStrings #-}

module HtmlSanitizer (cleanAndTruncate, normalizeVoids, pruneTree, takeWithLimit, stripHtmlTags) where

import Data.Char (isSpace)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag (..), isTagText, parseTags, renderTags)
import Text.HTML.TagSoup.Tree (TagTree (..), flattenTree, tagTree)

-- HTML sanitization and cleaning utilities
cleanAndTruncate :: Int -> Text -> Text
cleanAndTruncate maxLength html =
    let tags = parseTags html
        normalized = normalizeVoids tags
        tree = tagTree normalized
        pruned = pruneTree tree
        flat = flattenTree pruned
     in renderTags $ takeWithLimit maxLength [] flat

-- Strips all HTML tags, leaving only plain text
stripHtmlTags :: Text -> Text
stripHtmlTags html =
    let
        tags = parseTags html
        textTags = [t | TagText t <- tags]
        cleanedText = T.intercalate "" textTags
     in
        T.take 200 $ T.replace "\n" " " cleanedText

-- Helper to ensure void tags are properly closed for tree construction
normalizeVoids :: [Tag Text] -> [Tag Text]
normalizeVoids [] = []
normalizeVoids (TagOpen name attrs : rest)
    | name `elem` voidTags =
        case rest of
            (TagClose name2 : rest2)
                | name == name2 ->
                    TagOpen name attrs : TagClose name : normalizeVoids rest2
            _ ->
                TagOpen name attrs : TagClose name : normalizeVoids rest
normalizeVoids (x : xs) = x : normalizeVoids xs

pruneTree :: [TagTree Text] -> [TagTree Text]
pruneTree = filter (not . isEmptyTree) . filter (not . isSeparator) . filter (not . isImageTree) . map pruneBranch
  where
    pruneBranch (TagBranch name attrs children) = TagBranch name attrs (pruneTree children)
    pruneBranch leaf = leaf

    isSeparator (TagBranch _ attrs _) =
        case lookup "class" attrs of
            Just cls -> "separator" `elem` T.words cls
            Nothing -> False
    isSeparator _ = False

    isImageTree (TagBranch name _ _) = name == "img"
    isImageTree _ = False

    isEmptyTree (TagBranch name _ []) = name `notElem` voidTags
    isEmptyTree (TagBranch name _ _) | name `elem` ["script", "style"] = True
    isEmptyTree (TagBranch _ _ children) = all isEmptyTree children
    isEmptyTree (TagLeaf tag) = not (isVisibleTag tag)

    isVisibleTag (TagText t) = not (T.all isSpace t)
    isVisibleTag (TagOpen name _) = name `elem` voidTags
    isVisibleTag _ = False

voidTags :: [Text]
voidTags = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr", "video", "audio", "iframe", "object", "svg"]

takeWithLimit :: Int -> [Text] -> [Tag Text] -> [Tag Text]
takeWithLimit _ stack [] = map TagClose stack
takeWithLimit remainingLen stack (t : ts)
    | remainingLen <= 0 = map TagClose stack
    | otherwise = case t of
        TagText text ->
            let len = T.length text
             in if len <= remainingLen
                    then t : takeWithLimit (remainingLen - len) stack ts
                    else TagText (T.take remainingLen text <> "...") : map TagClose stack
        TagOpen name _ ->
            if name `elem` voidTags
                then t : takeWithLimit remainingLen stack ts
                else t : takeWithLimit remainingLen (name : stack) ts
        TagClose name ->
            if not (null stack) && head stack == name
                then t : takeWithLimit remainingLen (tail stack) ts
                else t : takeWithLimit remainingLen stack ts
        _ -> t : takeWithLimit remainingLen stack ts
