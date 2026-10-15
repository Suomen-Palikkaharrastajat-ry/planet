{-# LANGUAGE OverloadedStrings #-}

module FeedParser (
    FeedHandler (..),
    getFeedHandler,
    Download (..),
    fetchFeed,
    fetchFeedWith,
    maxCacheAge,
    parseFeedBody,
    filterExcludedItems,
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
    getContentEncoded,
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
    debugBodyPreview,
) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import Control.Monad (when)
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isDigit)
import Data.List (find)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With, encodeUtf8)
import Data.Text.Encoding.Error (lenientDecode)

-- Re-added missing import

import Data.Time (NominalDiffTime, diffUTCTime, getCurrentTime, nominalDay)
import Data.Time.Format (defaultTimeLocale, parseTimeM) -- Re-added missing import
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.XML.Types (Content (..), Element (..), Name (..), Node (..))
import Network.HTTP.Simple (
    Response,
    getResponseBody,
    getResponseHeader,
    getResponseStatusCode,
    httpLBS,
    parseRequest,
 )
import qualified Text.Atom.Feed as Atom
import Text.Feed.Import (parseFeedSource)
import Text.Feed.Query (
    getFeedItems,
    getItemDescription,
    getItemLink,
    getItemPublishDate,
    getItemTitle,
 )
import Text.Feed.Types (Feed (..), Item (..))
import Text.HTML.TagSoup (Tag (..), parseTags, renderTags)
import qualified Text.RSS.Syntax as RSS

import Config
import FeedCache
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

-- | A received HTTP response, reduced to what feed handling needs.
data Download = Download
    { downloadStatus :: Int
    , downloadContentType :: Text
    , downloadBody :: LBS.ByteString
    }

downloadFeed :: FeedConfig -> IO (Either Text Download)
downloadFeed fc = do
    result <- try $ do
        req <- parseRequest (T.unpack $ feedUrl fc)
        httpLBS req
    return $ case result :: Either SomeException (Response LBS.ByteString) of
        Left err -> Left (T.pack $ show err)
        Right response ->
            Right
                Download
                    { downloadStatus = getResponseStatusCode response
                    , downloadContentType =
                        case getResponseHeader "Content-Type" response of
                            ct : _ -> decodeUtf8With lenientDecode ct
                            [] -> "(missing)"
                    , downloadBody = getResponseBody response
                    }

{- | How long a cached copy may stand in for a failing feed. Outages last
hours; a feed failing for longer is probably gone and should drop out.
-}
maxCacheAge :: NominalDiffTime
maxCacheAge = 14 * nominalDay

{- | Fetch a feed, falling back to the copy in @cacheDir@ when the upstream
fails (error status, network error, or an unparseable or empty body).
-}
fetchFeed :: FilePath -> FeedConfig -> IO [AppItem]
fetchFeed = fetchFeedWith downloadFeed

fetchFeedWith :: (FeedConfig -> IO (Either Text Download)) -> FilePath -> FeedConfig -> IO [AppItem]
fetchFeedWith download cacheDir fc = do
    let displayTitle = T.unpack $ fromMaybe (feedUrl fc) (feedTitle fc)
        cachePath = feedCachePath cacheDir (feedUrl fc)
    putStrLn $ "Fetching " ++ displayTitle ++ "..."
    result <- download fc
    fresh <- case result of
        Left err -> do
            putStrLn $ "Error fetching " ++ displayTitle ++ ": " ++ T.unpack err
            return Nothing
        Right dl
            | downloadStatus dl < 200 || downloadStatus dl >= 300 -> do
                putStrLn $ "Error fetching " ++ displayTitle ++ ": HTTP " ++ show (downloadStatus dl)
                return Nothing
            | otherwise -> case parseFeedBody fc (downloadBody dl) of
                Nothing -> do
                    logParseFailure displayTitle dl
                    return Nothing
                Just items -> do
                    writeFeedCache cachePath (downloadBody dl)
                    return (Just items)
    items <- case fresh of
        Just items -> return items
        Nothing -> do
            cached <- readFeedCache cachePath
            case cached of
                Nothing -> do
                    putStrLn $ "  No cached copy of " ++ displayTitle ++ "; skipping it"
                    return []
                Just (stamp, body) -> do
                    now <- getCurrentTime
                    if diffUTCTime now stamp > maxCacheAge
                        then do
                            putStrLn $
                                "  WARNING: cached copy of "
                                    ++ displayTitle
                                    ++ " is from "
                                    ++ show stamp
                                    ++ ", older than the maximum age; the feed may be gone for good, skipping it"
                            return []
                        else case parseFeedBody fc body of
                            Nothing -> do
                                putStrLn $ "  Cached copy of " ++ displayTitle ++ " is unparseable; skipping it"
                                return []
                            Just items -> do
                                putStrLn $ "  Using cached copy of " ++ displayTitle ++ " from " ++ show stamp
                                return items
    return $ filterExcludedItems fc items
  where
    logParseFailure displayTitle dl = do
        putStrLn $
            "Failed to parse feed: " ++ displayTitle ++ ": invalid, unsupported or empty feed"
        putStrLn $
            "  Debug: url="
                ++ T.unpack (feedUrl fc)
                ++ ", status="
                ++ show (downloadStatus dl)
                ++ ", content-type="
                ++ T.unpack (downloadContentType dl)
        putStrLn $
            "  Debug: body-preview=\"" ++ T.unpack (debugBodyPreview $ downloadBody dl) ++ "\""
        when
            (T.isInfixOf "<html" (T.toLower (decodeUtf8With lenientDecode (LBS.toStrict (downloadBody dl)))))
            ( putStrLn
                "  Hint: response looks like HTML, which often indicates bot protection or an error page instead of RSS/Atom XML."
            )

{- | Parse a raw feed body into items (before exclusion filtering).
Nothing when the body is not a usable feed or has no items.
-}
parseFeedBody :: FeedConfig -> LBS.ByteString -> Maybe [AppItem]
parseFeedBody fc body = do
    let cleanedContent = T.replace "</media:keywords>" "" (decodeUtf8With lenientDecode (LBS.toStrict body))
    feed <- parseFeedSource (LBS.fromStrict $ encodeUtf8 cleanedContent)
    let altLink = feedLink fc <|> getFeedAlternateLink feed
        finalTitle = fromMaybe "Unknown Feed" (feedTitle fc <|> getFeedTitle feed)
        items = mapMaybe (parseItem (fc{feedTitle = Just finalTitle}) altLink) (getFeedItems feed)
    -- An empty result is not trusted: parseFeedSource accepts any
    -- well-formed XML (an XHTML error page, say), and upstreams sometimes
    -- serve an empty feed during an outage. Either would otherwise replace
    -- a good cached copy.
    if null items then Nothing else Just items

filterExcludedItems :: FeedConfig -> [AppItem] -> [AppItem]
filterExcludedItems fc items =
    let excludedLinks = feedExcludeList fc
        excludedWords = map T.toLower (feedExcludeKeywords fc)
        containsExcludedWord txt = any (`T.isInfixOf` T.toLower txt) excludedWords
        isNotExcluded i =
            itemLink i `notElem` excludedLinks
                && not (containsExcludedWord (itemTitle i))
                && not (maybe False containsExcludedWord (itemDescText i))
     in filter isNotExcluded items

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
    let date = case item of
            AtomItem entry -> case Atom.entryPublished entry of
                Just pub ->
                    parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Z" (T.unpack pub)
                        <|> iso8601ParseM (T.unpack pub)
                Nothing -> iso8601ParseM (T.unpack $ Atom.entryUpdated entry)
            _ -> join $ getItemPublishDate item
    let defaultDesc = getItemDescription item
    let mediaDesc = getMediaDescription fc item
    let desc = mediaDesc <|> defaultDesc
    originalLink <- normalizeUrl <$> getItemLink item
    let link = resolveFollowItTrackingLink originalLink desc
    let descText = fmap stripHtml desc
    let descSnippet = fmap (T.take 250) descText
    let thumb =
            getItemThumbnail item
                <|> (desc >>= extractFirstImage)
                <|> (defaultDesc >>= extractFirstImage)
                <|> (getContentEncoded item >>= extractFirstImage)
    let sourceTitle = case feedTitle fc of
            Just t -> t
            Nothing -> T.pack "Unknown Feed"
    return $
        AppItem
            title
            link
            date
            desc
            descText
            descSnippet
            thumb
            sourceTitle
            altLink
            (feedType fc)
            (feedGroup fc)

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

resolveFollowItTrackingLink :: Text -> Maybe Text -> Text
resolveFollowItTrackingLink originalLink maybeDescription
    | isApiFollowItTrackingLink originalLink =
        case maybeDescription >>= extractPreferredArticleLinkFromDescription of
            Just extractedLink -> stripUrlFragment $ normalizeUrl extractedLink
            Nothing -> originalLink
    | otherwise = originalLink

isApiFollowItTrackingLink :: Text -> Bool
isApiFollowItTrackingLink url =
    T.isInfixOf "//api.follow.it/" (T.toLower url)

extractPreferredArticleLinkFromDescription :: Text -> Maybe Text
extractPreferredArticleLinkFromDescription description =
    case continueReadingLinks of
        (u : _) -> Just u
        [] ->
            case reverse nonFollowLinks of
                (u : _) -> Just u
                [] -> Nothing
  where
    linksWithText = extractAnchorHrefsWithText description
    continueReadingLinks =
        [ href
        | (href, anchorText) <- linksWithText
        , isHttpUrl href
        , not (isFollowItLink href)
        , isContinueReadingText anchorText
        ]
    nonFollowLinks =
        [ href
        | (href, _) <- linksWithText
        , isHttpUrl href
        , not (isFollowItLink href)
        ]

extractAnchorHrefsWithText :: Text -> [(Text, Text)]
extractAnchorHrefsWithText html = go (parseTags html)
  where
    go [] = []
    go (TagOpen "a" attrs : rest) =
        let (inside, remaining) = break isAnchorCloseTag rest
            remainingAfterClose = drop 1 remaining
            anchorText = T.toLower $ T.strip $ T.concat [t | TagText t <- inside]
         in case lookup "href" attrs of
                Just href -> (href, anchorText) : go remainingAfterClose
                Nothing -> go remainingAfterClose
    go (_ : rest) = go rest

    isAnchorCloseTag (TagClose "a") = True
    isAnchorCloseTag _ = False

isContinueReadingText :: Text -> Bool
isContinueReadingText txt =
    T.isInfixOf "continue reading" txt
        || T.isInfixOf "read more" txt

isHttpUrl :: Text -> Bool
isHttpUrl url =
    "http://" `T.isPrefixOf` url || "https://" `T.isPrefixOf` url

isFollowItLink :: Text -> Bool
isFollowItLink url =
    let lower = T.toLower url
     in T.isInfixOf "//api.follow.it/" lower || T.isInfixOf "//follow.it/" lower

stripUrlFragment :: Text -> Text
stripUrlFragment = T.takeWhile (/= '#')

debugBodyPreview :: LBS.ByteString -> Text
debugBodyPreview body =
    body
        |> LBS.toStrict
        |> decodeUtf8With lenientDecode
        |> normalizeWhitespace
        |> T.take 320
  where
    normalizeWhitespace text =
        text
            |> T.map
                ( \c ->
                    if c == '\n' || c == '\r' || c == '\t'
                        then
                            ' '
                        else
                            c
                )
            |> T.words
            |> T.unwords

    (|>) = flip ($)

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
        imgTags = [attrs | TagOpen "img" attrs <- tags, not (isTrackingPixel attrs)]
     in case imgTags of
            (attrs : _) -> normalizeUrl <$> lookup "src" attrs
            _ -> Nothing
  where
    isTrackingPixel attrs = lookup "width" attrs == Just "1" && lookup "height" attrs == Just "1"

getContentEncoded :: Item -> Maybe Text
getContentEncoded (RSSItem rssItem) =
    case filter isContentEncoded (RSS.rssItemOther rssItem) of
        (e : _) ->
            let texts = [t | NodeContent (ContentText t) <- elementNodes e]
             in if null texts then Nothing else Just (T.concat texts)
        [] -> Nothing
  where
    isContentEncoded e =
        nameLocalName (elementName e) == "encoded"
            && nameNamespace (elementName e) == Just "http://purl.org/rss/1.0/modules/content/"
getContentEncoded _ = Nothing

-- Thumbnail extraction
getItemThumbnail :: Item -> Maybe Text
getItemThumbnail item = case item of
    AtomItem entry -> getAtomThumbnail entry
    RSSItem rssItem -> getRSSThumbnail rssItem
    XMLItem element ->
        findMediaThumbnail (elementChildren element) <|> findMediaGroupThumbnail (elementChildren element)
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
    case filter
        ( \l ->
            Atom.linkRel l == Just (Right (T.pack "enclosure"))
                && maybe False (T.isPrefixOf "image/") (Atom.linkType l)
        )
        links of
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
    Text.Feed.Types.AtomFeed af -> case find
        ( \l -> case Atom.linkRel l of
            Just (Left r) -> r == "alternate" || r == "http://www.iana.org/assignments/relation/alternate"
            Just (Right uri) -> uri == "alternate" || uri == "http://www.iana.org/assignments/relation/alternate"
            _ -> False
        )
        (Atom.feedLinks af) of
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
