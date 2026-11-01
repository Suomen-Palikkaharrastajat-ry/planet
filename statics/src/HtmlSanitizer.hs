{-# LANGUAGE OverloadedStrings #-}

module HtmlSanitizer (
    cleanAndTruncate,
    normalizeVoids,
    pruneTree,
    takeWithLimit,
    stripHtmlTags,
    isInvisibleFormat,
    stripInvisibleCharacters,
    decodeHtmlEntities,
) where

import Data.Char (chr, isControl, isDigit, isHexDigit, isSpace)
import Data.Text (Text)
import qualified Data.Text as T
import Numeric (readDec, readHex)
import Text.HTML.TagSoup (Tag (..), parseTags, renderTags)
import Text.HTML.TagSoup.Tree (TagTree (..), flattenTree, tagTree)

{- | Checks whether a character is an invisible formatting character:
zero-width spaces/joiners, bidi overrides/controls, word joiners, and BOM.
-}
isInvisibleFormat :: Char -> Bool
isInvisibleFormat c =
    c >= '\x200B' && c <= '\x200F'
        || c >= '\x202A' && c <= '\x202E'
        || c >= '\x2060' && c <= '\x206F'
        || c == '\xFEFF'

-- | Strips invisible formatting characters from text.
stripInvisibleCharacters :: Text -> Text
stripInvisibleCharacters = T.filter (not . isInvisibleFormat)

{- | Decodes HTML character references (named and numeric entities).
Handles double-escaped entities (e.g. &amp;quot; -> ", &amp;amp; -> &),
but strictly refuses to decode invisible format and control characters.
-}
decodeHtmlEntities :: Text -> Text
decodeHtmlEntities = decodeLoop (2 :: Int)
  where
    decodeLoop n t
        | n <= 0 = t
        | otherwise =
            let next = decodeSinglePass t
             in if next == t
                    then t
                    else decodeLoop (n - 1) next

    decodeSinglePass t
        | T.null t = ""
        | otherwise =
            let (before, rest) = T.break (== '&') t
             in if T.null rest
                    then before
                    else before <> decodeAmp (T.drop 1 rest)

    decodeAmp rest =
        let candidate = T.take 11 rest
         in case T.findIndex (== ';') candidate of
                Just semiIdx ->
                    let entityName = T.take semiIdx candidate
                        afterSemi = T.drop (semiIdx + 1) rest
                     in case entityChar entityName of
                            Just c -> T.cons c (decodeSinglePass afterSemi)
                            Nothing -> T.cons '&' (decodeSinglePass rest)
                Nothing -> T.cons '&' (decodeSinglePass rest)

    entityChar name
        | Just numStr <- T.stripPrefix "#" name =
            let (digits, radix) = case T.uncons numStr of
                    Just (x, rest) | x == 'x' || x == 'X' -> (rest, 16 :: Int)
                    _ -> (numStr, 10 :: Int)
             in if T.null digits || not (T.all (isValidDigit radix) digits)
                    then Nothing
                    else case parseRadix radix digits of
                        Just n
                            | n <= 0x10FFFF && not (n >= 0xD800 && n <= 0xDFFF) ->
                                let c = chr n
                                 in if isSpace c || not (isControl c || isInvisibleFormat c)
                                        then Just c
                                        else Nothing
                        _ -> Nothing
        | otherwise = case name of
            "quot" -> Just '"'
            "amp" -> Just '&'
            "apos" -> Just '\''
            "lt" -> Just '<'
            "gt" -> Just '>'
            "nbsp" -> Just '\xA0'
            "ndash" -> Just '–'
            "mdash" -> Just '—'
            "hellip" -> Just '…'
            "lsquo" -> Just '‘'
            "rsquo" -> Just '’'
            "ldquo" -> Just '“'
            "rdquo" -> Just '”'
            "laquo" -> Just '«'
            "raquo" -> Just '»'
            "copy" -> Just '©'
            "reg" -> Just '®'
            "trade" -> Just '™'
            "deg" -> Just '°'
            "times" -> Just '×'
            "middot" -> Just '·'
            "bull" -> Just '•'
            _ -> Nothing

    isValidDigit 16 c = isHexDigit c
    isValidDigit _ c = isDigit c

    parseRadix 16 s = case readHex (T.unpack s) of
        [(n, "")] -> Just n
        _ -> Nothing
    parseRadix 10 s = case readDec (T.unpack s) of
        [(n, "")] -> Just n
        _ -> Nothing
    parseRadix _ _ = Nothing

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
pruneTree =
    filter (not . isEmptyTree)
        . filter (not . isSeparator)
        . filter (not . isImageTree)
        . map pruneBranch
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
voidTags =
    [ "area"
    , "base"
    , "br"
    , "col"
    , "embed"
    , "hr"
    , "img"
    , "input"
    , "link"
    , "meta"
    , "param"
    , "source"
    , "track"
    , "wbr"
    , "video"
    , "audio"
    , "iframe"
    , "object"
    , "svg"
    ]

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
