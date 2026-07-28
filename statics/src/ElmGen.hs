{-# LANGUAGE OverloadedStrings #-}

{- | Generate an Elm data module from Haskell data types.
This module generates Elm source code that embeds feed data directly,
avoiding the need for JSON interchange (which would redistribute data).
-}
module ElmGen (generateElmModule, generateSearchIndex) where

import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy as LBS
import Data.List (nub)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Data.Time.Format.ISO8601 (iso8601Show)
import Config (Config (..), FeedConfig (..))
import I18n (AppItem (..), FeedType (..))

-- | Generate a complete Elm module containing type definitions and data.
generateElmModule :: Config -> [AppItem] -> Text
generateElmModule config items =
    let defGroup = configDefaultGroup config
        groups = nub (defGroup : map feedGroup (configFeeds config))
    in T.unlines
        [ "module Data exposing (allAppItems, AppItem, FeedType(..), defaultGroup, allGroups)"
        , ""
        , "type FeedType"
        , "    = Feed"
        , "    | YouTube"
        , "    | Image"
        , ""
        , "type alias AppItem ="
        , "    { itemTitle : String"
        , "    , itemLink : String"
        , "    , itemDate : Maybe String"
        , "    , itemDescSnippet : Maybe String"
        , "    , itemThumbnail : Maybe String"
        , "    , itemSourceTitle : String"
        , "    , itemSourceLink : Maybe String"
        , "    , itemType : FeedType"
        , "    , itemGroup : String"
        , "    }"
        , ""
        , "defaultGroup : String"
        , "defaultGroup = " <> renderString defGroup
        , ""
        , "allGroups : List String"
        , "allGroups = " <> renderStringList groups
        , ""
        , "allAppItems : List AppItem"
        , "allAppItems ="
        , renderItemList items
        ]

-- | Generate a search index as JSON.
generateSearchIndex :: [AppItem] -> LBS.ByteString
generateSearchIndex items = encode (map toSearchItem items)
  where
    toSearchItem item =
        object
            [ "id" .= itemLink item
            , "title" .= itemTitle item
            , "description" .= fromMaybe "" (itemDescText item)
            , "source" .= itemSourceTitle item
            ]

-- | Render a list of AppItems as an Elm list literal.
renderItemList :: [AppItem] -> Text
renderItemList [] = "    []"
renderItemList items =
    T.unlines $
        ["    [ " <> renderItem (head items)]
            ++ map (\i -> "    , " <> renderItem i) (tail items)
            ++ ["    ]"]

-- | Render a single AppItem as an Elm record literal.
renderItem :: AppItem -> Text
renderItem item =
    T.concat
        [ "{ itemTitle = "
        , renderString (itemTitle item)
        , ", itemLink = "
        , renderString (itemLink item)
        , ", itemDate = "
        , renderMaybeUTCTime (itemDate item)
        , ", itemDescSnippet = "
        , renderMaybeString (itemDescSnippet item)
        , ", itemThumbnail = "
        , renderMaybeString (itemThumbnail item)
        , ", itemSourceTitle = "
        , renderString (itemSourceTitle item)
        , ", itemSourceLink = "
        , renderMaybeString (itemSourceLink item)
        , ", itemType = "
        , renderFeedType (itemType item)
        , ", itemGroup = "
        , renderString (itemGroup item)
        , " }"
        ]

-- | Render a Text value as an Elm string literal.
renderString :: Text -> Text
renderString t = "\"" <> escapeElmString t <> "\""

-- | Render a Maybe Text as an Elm Maybe String.
renderMaybeString :: Maybe Text -> Text
renderMaybeString Nothing = "Nothing"
renderMaybeString (Just t) = "Just " <> renderString t

-- | Render a list of Text values as an Elm list of string literals.
renderStringList :: [Text] -> Text
renderStringList [] = "[]"
renderStringList ts = "[ " <> T.intercalate ", " (map renderString ts) <> " ]"

-- | Render a Maybe UTCTime as an Elm Maybe String (ISO8601 format).
renderMaybeUTCTime :: Maybe UTCTime -> Text
renderMaybeUTCTime Nothing = "Nothing"
renderMaybeUTCTime (Just t) = "Just \"" <> T.pack (iso8601Show t) <> "\""

-- | Render a FeedType as its Elm constructor name.
renderFeedType :: FeedType -> Text
renderFeedType Feed = "Feed"
renderFeedType YouTube = "YouTube"
renderFeedType Image = "Image"

-- | Escape special characters in an Elm string literal.
escapeElmString :: Text -> Text
escapeElmString = T.concatMap escapeChar
  where
    escapeChar '\\' = "\\\\"
    escapeChar '"' = "\\\""
    escapeChar '\n' = "\\n"
    escapeChar '\r' = "\\r"
    escapeChar '\t' = "\\t"
    escapeChar c = T.singleton c
