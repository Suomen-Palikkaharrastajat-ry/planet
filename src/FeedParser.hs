{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module FeedParser (
    FeedHandler (..),
    getFeedHandler,
    fetchFeed,
    parseItem,
    getMediaDescription,
    getYouTubeMediaDescription,
    getFlickrMediaDescription,
    getAtomMediaDescription,
    getKuvatfiMediaDescription,
    stripFirstPTag,
    cleanTitle,
    getMediaDescriptionFromElements,
    isMediaDescription,
    isMediaGroup,
    extractFirstImage,
    getItemThumbnail,
    elementChildren,
    getAtomThumbnail,
    findEnclosureImage,
    getRSSThumbnail,
    findMediaThumbnail,
    findMediaGroupThumbnail,
    isMediaThumbnail,
    getUrlAttr,
    join,
    getFeedTitle,
) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isDigit)
import Data.List (find)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)

-- Re-added missing import

import Data.Time.Format (defaultTimeLocale, parseTimeM) -- Re-added missing import
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.XML.Types (Content (..), Element (..), Name (..), Node (..))
import Network.HTTP.Simple (Response, getResponseBody, httpLBS, parseRequest)
import qualified Text.Atom.Feed as Atom
import Text.Feed.Import (parseFeedSource)
import Text.Feed.Query (getFeedItems, getItemDescription, getItemLink, getItemPublishDate, getItemTitle)
import Text.Feed.Types (Feed (..), Item (..))
import Text.HTML.TagSoup (Tag (..), parseTags, renderTags)
import qualified Text.RSS.Syntax as RSS

import Config
import I18n

-- Normalizes URLs by replacing multiple slashes in the protocol part
normalizeUrl :: Text -> Text
normalizeUrl =
    T.replace "https://///" "https://"
        . T.replace "http://///" "http://"

newtype FeedHandler = FeedHandler
    { fhGetMediaDescription :: Item -> Maybe Text
    }

getFeedHandler :: FeedType -> FeedHandler
getFeedHandler Feed = FeedHandler{fhGetMediaDescription = getAtomMediaDescription}
getFeedHandler YouTube = FeedHandler{fhGetMediaDescription = getYouTubeMediaDescription}
getFeedHandler Image = FeedHandler{fhGetMediaDescription = getFlickrMediaDescription}

-- Fetching
fetchFeed :: FeedConfig -> IO [AppItem]
fetchFeed fc = do
    let displayTitle = case feedTitle fc of
            Just t -> t
            Nothing -> feedUrl fc
    putStrLn $ "Fetching " ++ T.unpack displayTitle ++ "..."
    req <- parseRequest (T.unpack $ feedUrl fc)
    result <- try (httpLBS req) :: IO (Either SomeException (Response LBS.ByteString))
    case result of
        Left err -> do
            putStrLn $ "Error fetching " ++ T.unpack displayTitle ++ ": " ++ show err
            return []
        Right response -> do
            let content = LBS.toStrict $ getResponseBody response
            let cleanedContent = T.replace "</media:keywords>" "" (decodeUtf8 content)
            case parseFeedSource (LBS.fromStrict $ encodeUtf8 cleanedContent) of
                Nothing -> do
                    putStrLn $ "Failed to parse feed: " ++ T.unpack displayTitle ++ ": invalid or unsupported feed format"
                    return []
                Just feed ->
                    let altLink = getFeedAlternateLink feed
                        extractedTitle = getFeedTitle feed
                        finalTitle = case feedTitle fc of
                            Just t -> t
                            Nothing -> case extractedTitle of
                                Just t -> t
                                Nothing -> T.pack "Unknown Feed"
                     in return $ mapMaybe (parseItem (fc{feedTitle = Just finalTitle}) altLink) (getFeedItems feed)

-- Helper for date join
join :: Maybe (Maybe a) -> Maybe a
join (Just (Just x)) = Just x
join _ = Nothing

stripHtml :: Text -> Text
stripHtml = T.unwords . mapMaybe fromTagText . parseTags
  where
    fromTagText (TagText s) = Just s
    fromTagText _ = Nothing

-- Base parseItem function
parseItem :: FeedConfig -> Maybe Text -> Item -> Maybe AppItem
parseItem fc altLink item = do
    rawTitle <- getItemTitle item
    let title = cleanTitle rawTitle
    link <- normalizeUrl <$> getItemLink item
    let date = case item of
            AtomItem entry -> case Atom.entryPublished entry of
                Just pub -> parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Z" (T.unpack pub) <|> iso8601ParseM (T.unpack pub)
                Nothing -> iso8601ParseM (T.unpack $ Atom.entryUpdated entry)
            _ -> join $ getItemPublishDate item
    let defaultDesc = getItemDescription item
    let mediaDesc = getMediaDescription fc item
    let desc = mediaDesc <|> defaultDesc
    let descText = fmap stripHtml desc
    let descSnippet = fmap (T.take 250) descText
    let thumb = getItemThumbnail item <|> (desc >>= extractFirstImage)
    let sourceTitle = case feedTitle fc of
            Just t -> t
            Nothing -> T.pack "Unknown Feed"
    return $ AppItem title link date desc descText descSnippet thumb sourceTitle altLink (feedType fc)

-- Media Description Extraction (feed-type specific)
getMediaDescription :: FeedConfig -> Item -> Maybe Text
getMediaDescription fc = fhGetMediaDescription (getFeedHandler (feedType fc))

getYouTubeMediaDescription :: Item -> Maybe Text
getYouTubeMediaDescription item = case item of
    AtomItem entry -> getMediaDescriptionFromElements (Atom.entryOther entry)
    XMLItem element -> getMediaDescriptionFromElements (elementChildren element)
    _ -> Nothing

getFlickrMediaDescription :: Item -> Maybe Text
getFlickrMediaDescription item = case item of
    AtomItem entry ->
        case Atom.entryContent entry of
            Just (Atom.HTMLContent content) -> Just $ stripFirstPTag content
            _ -> fmap stripFirstPTag (getItemDescription item) -- fallback
    XMLItem element -> getMediaDescriptionFromElements (elementChildren element)
    _ -> Nothing

getKuvatfiMediaDescription :: Item -> Maybe Text
getKuvatfiMediaDescription = getItemDescription

getAtomMediaDescription :: Item -> Maybe Text
getAtomMediaDescription item = case item of
    AtomItem entry ->
        case Atom.entryContent entry of
            Just (Atom.HTMLContent content) -> Just content
            _ -> getItemDescription item -- fallback
    XMLItem element -> getMediaDescriptionFromElements (elementChildren element)
    _ -> Nothing

stripFirstPTag :: Text -> Text
stripFirstPTag html =
    let decodedHtml = decodeEntities html
        tags = parseTags decodedHtml
        remainingTags = skipToFirstPTag tags
     in renderTags remainingTags
  where
    decodeEntities :: Text -> Text
    decodeEntities = T.replace "&lt;" "<" . T.replace "&gt;" ">" . T.replace "&quot;" "\"" . T.replace "&amp;" "&"
    skipToFirstPTag :: [Tag Text] -> [Tag Text]
    skipToFirstPTag [] = []
    skipToFirstPTag (TagOpen "p" _ : rest) =
        let (_, remaining) = skipUntilClosingPTag rest
         in remaining
    skipToFirstPTag (_ : rest) = skipToFirstPTag rest
    skipUntilClosingPTag :: [Tag Text] -> ([Tag Text], [Tag Text])
    skipUntilClosingPTag [] = ([], [])
    skipUntilClosingPTag (TagClose "p" : rest) = ([], rest)
    skipUntilClosingPTag (tag : rest) =
        let (skipped, remaining) = skipUntilClosingPTag rest
         in (tag : skipped, remaining)

cleanTitle :: Text -> Text
cleanTitle title =
    let wordList = T.words title
        cleaned = reverse $ dropWhile isHashtagToRemove $ reverse wordList
     in T.unwords cleaned
  where
    isHashtagToRemove w = T.isPrefixOf "#" w && not (T.all isDigit (T.drop 1 w))

getMediaDescriptionFromElements :: [Element] -> Maybe Text
getMediaDescriptionFromElements elements =
    -- First check for descriptions directly in the elements
    case filter isMediaDescription elements of
        (d : _) -> elementText d
        [] ->
            -- Then check inside media groups
            let mediaGroups = filter isMediaGroup elements
             in case mediaGroups of
                    (g : _) ->
                        let descriptionElements = filter isMediaDescription (elementNodes g >>= nodeToElem)
                         in case descriptionElements of
                                (d : _) -> elementText d
                                _ -> Nothing
                    _ -> Nothing
  where
    nodeToElem (NodeElement e) = [e]
    nodeToElem _ = []

    elementText e =
        let texts = [t | NodeContent (ContentText t) <- elementNodes e]
         in if null texts then Nothing else Just (T.concat texts)

isMediaDescription :: Element -> Bool
isMediaDescription e =
    nameLocalName (elementName e) == "description"
        && nameNamespace (elementName e) == Just "http://search.yahoo.com/mrss/"

isMediaGroup :: Element -> Bool
isMediaGroup e =
    nameLocalName (elementName e) == "group"
        && nameNamespace (elementName e) == Just "http://search.yahoo.com/mrss/"

extractFirstImage :: Text -> Maybe Text
extractFirstImage html =
    let tags = parseTags html
        imgTags = filter (\case TagOpen "img" _ -> True; _ -> False) tags
     in case imgTags of
            (TagOpen "img" attrs : _) -> normalizeUrl <$> lookup "src" attrs
            _ -> Nothing

-- Thumbnail extraction
getItemThumbnail :: Item -> Maybe Text
getItemThumbnail item = case item of
    AtomItem entry -> getAtomThumbnail entry
    RSSItem rssItem -> getRSSThumbnail rssItem
    XMLItem element -> findMediaThumbnail (elementChildren element) <|> findMediaGroupThumbnail (elementChildren element)
    _ -> Nothing

elementChildren :: Element -> [Element]
elementChildren e = [c | NodeElement c <- elementNodes e]

getAtomThumbnail :: Atom.Entry -> Maybe Text
getAtomThumbnail entry =
    let others = Atom.entryOther entry
        enclosureImg = findEnclosureImage (Atom.entryLinks entry)
     in case findMediaThumbnail others of
            Just url -> Just url
            Nothing -> findMediaGroupThumbnail others <|> enclosureImg

findEnclosureImage :: [Atom.Link] -> Maybe Text
findEnclosureImage links =
    case filter (\l -> Atom.linkRel l == Just (Right (T.pack "enclosure")) && maybe False (T.isPrefixOf "image/") (Atom.linkType l)) links of
        (l : _) -> Just (normalizeUrl $ Atom.linkHref l)
        [] -> Nothing

getRSSThumbnail :: RSS.RSSItem -> Maybe Text
getRSSThumbnail item =
    case findMediaThumbnail (RSS.rssItemOther item) of
        Just url -> Just url
        Nothing -> findMediaGroupThumbnail (RSS.rssItemOther item)

findMediaThumbnail :: [Element] -> Maybe Text
findMediaThumbnail elems =
    case filter isMediaThumbnail elems of
        (e : _) -> normalizeUrl <$> getUrlAttr e
        [] -> Nothing

findMediaGroupThumbnail :: [Element] -> Maybe Text
findMediaGroupThumbnail elems =
    case filter isMediaGroup elems of
        (g : _) -> findMediaThumbnail (elementNodes g >>= nodeToElem)
        [] -> Nothing
  where
    nodeToElem (NodeElement e) = [e]
    nodeToElem _ = []

isMediaThumbnail :: Element -> Bool
isMediaThumbnail e =
    nameLocalName (elementName e) == "thumbnail"
        && nameNamespace (elementName e) == Just "http://search.yahoo.com/mrss/"

getUrlAttr :: Element -> Maybe Text
getUrlAttr e =
    case filter (\(n, _) -> nameLocalName n == "url") (elementAttributes e) of
        ((_, [ContentText t]) : _) -> Just t
        _ -> Nothing

getFeedAlternateLink :: Text.Feed.Types.Feed -> Maybe Text
getFeedAlternateLink feed = case feed of
    Text.Feed.Types.AtomFeed af -> case find (\l -> case Atom.linkRel l of Just (Left r) -> r == "alternate" || r == "http://www.iana.org/assignments/relation/alternate"; Just (Right uri) -> uri == "alternate" || uri == "http://www.iana.org/assignments/relation/alternate"; _ -> False) (Atom.feedLinks af) of
        Just l -> Just (Atom.linkHref l)
        Nothing -> findAlternateLink (map NodeElement (Atom.feedOther af))
    Text.Feed.Types.RSSFeed rf ->
        case findAlternateLink (map NodeElement (RSS.rssChannelOther (RSS.rssChannel rf))) of
            Just l -> Just l
            Nothing -> Just (normalizeUrl $ RSS.rssLink (RSS.rssChannel rf))
    Text.Feed.Types.XMLFeed e -> findAlternateLink (map NodeElement (elementChildren e))
    _ -> Nothing
  where
    findAlternateLink [] = Nothing
    findAlternateLink (n : ns) = case n of
        NodeElement e ->
            if nameLocalName (elementName e) == "link"
                then case getAttr "rel" e of
                    Just "alternate" -> getAttr "href" e
                    _ -> findAlternateLink ns
                else findAlternateLink ns
        _ -> findAlternateLink ns
    getAttr attr e =
        case filter (\(n, _) -> nameLocalName n == attr) (elementAttributes e) of
            ((_, [ContentText t]) : _) -> Just t
            _ -> Nothing

getFeedTitle :: Text.Feed.Types.Feed -> Maybe Text
getFeedTitle feed = case feed of
    Text.Feed.Types.AtomFeed af -> Just (T.pack $ Atom.txtToString $ Atom.feedTitle af)
    Text.Feed.Types.RSSFeed rf -> Just (RSS.rssTitle (RSS.rssChannel rf))
    Text.Feed.Types.XMLFeed e -> findTitle (elementChildren e)
    _ -> Nothing
  where
    findTitle [] = Nothing
    findTitle (e : es) = case elementName e of
        Name "title" _ _ -> case elementNodes e of
            (NodeContent (ContentText t) : _) -> Just t
            _ -> findTitle es
        _ -> findTitle es
