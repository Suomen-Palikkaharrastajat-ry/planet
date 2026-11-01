{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module PocketBase (
    BackendType (..),
    PocketBaseConfig (..),
    PBListResponse (..),
    PBGroupRecord (..),
    PBFeedExpand (..),
    PBFeedRecord (..),
    PBItemExpand (..),
    PBItemRecord (..),
    detectBackend,
    parsePocketBaseDate,
    toFeedConfig,
    toAppItem,
    fetchPocketBaseFeeds,
    fetchPocketBaseItems,
) where

import Control.Applicative ((<|>))
import Data.Aeson (
    FromJSON (..),
    eitherDecode,
    withObject,
    (.!=),
    (.:),
    (.:?),
 )
import qualified Data.ByteString.Char8 as BS8
import Data.Char (isSpace, toLower)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (UTCTime)
import Data.Time.Format (defaultTimeLocale, formatTime, parseTimeM)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Network.HTTP.Client (
    Manager,
    Request (..),
    httpLbs,
    parseRequest,
    responseBody,
    setQueryString,
 )

import Config (FeedConfig (..))
import FeedParser (cleanTitle)
import I18n (AppItem (..), FeedType (..))

data BackendType
    = TomlBackend
    | PocketBaseBackend !PocketBaseConfig
    deriving (Show, Eq)

data PocketBaseConfig = PocketBaseConfig
    { pbUrl :: !Text
    , pbToken :: !(Maybe Text)
    , pbFeedsCollection :: !Text
    , pbItemsCollection :: !Text
    , pbSince :: !(Maybe UTCTime)
    }
    deriving (Show, Eq)

detectBackend :: [(String, String)] -> BackendType
detectBackend env =
    case lookup "PLANET_BACKEND" env of
        Just rawBackend
            | not (null (trim rawBackend)) ->
                case map toLower (trim rawBackend) of
                    "toml" -> TomlBackend
                    "file" -> TomlBackend
                    "pocketbase" -> PocketBaseBackend (buildConfig env)
                    "pb" -> PocketBaseBackend (buildConfig env)
                    _ -> TomlBackend
        _ ->
            case lookup "POCKETBASE_URL" env of
                Just url
                    | not (null (trim url)) -> PocketBaseBackend (buildConfig env)
                _ -> TomlBackend
  where
    trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

buildConfig :: [(String, String)] -> PocketBaseConfig
buildConfig env =
    let rawUrl = case lookup "POCKETBASE_URL" env of
            Just u | not (null (trim u)) -> T.pack (stripTrailingSlash (trim u))
            _ -> "http://127.0.0.1:8090"
        mToken = case lookup "POCKETBASE_TOKEN" env <|> lookup "POCKETBASE_ADMIN_TOKEN" env <|> lookup "PB_TOKEN" env of
            Just t | not (null (trim t)) -> Just (T.pack (trim t))
            _ -> Nothing
        feedsCol = case lookup "POCKETBASE_FEEDS_COLLECTION" env of
            Just f | not (null (trim f)) -> T.pack (trim f)
            _ -> "feeds"
        itemsCol = case lookup "POCKETBASE_ITEMS_COLLECTION" env of
            Just i | not (null (trim i)) -> T.pack (trim i)
            _ -> "feed_items"
        mSince = case lookup "POCKETBASE_SINCE" env
            <|> lookup "PLANET_POCKETBASE_SINCE" env
            <|> lookup "POCKETBASE_FIRST_DATE" env
            <|> lookup "PLANET_SINCE" env of
            Just s | not (null (trim s)) -> parsePocketBaseDate (T.pack (trim s))
            _ -> Nothing
     in PocketBaseConfig
            { pbUrl = rawUrl
            , pbToken = mToken
            , pbFeedsCollection = feedsCol
            , pbItemsCollection = itemsCol
            , pbSince = mSince
            }
  where
    stripTrailingSlash s = reverse (dropWhile (== '/') (reverse s))
    trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

parsePocketBaseDate :: Text -> Maybe UTCTime
parsePocketBaseDate t =
    let s = T.unpack (T.strip t)
     in iso8601ParseM s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%d %H:%M:%S%QZ" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%d %H:%M:%SZ" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%d %H:%M:%S%Q" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%d %H:%M:%S" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" s
            <|> parseTimeM True defaultTimeLocale "%a, %d %b %Y %H:%M:%S %Z" s
            <|> parseTimeM True defaultTimeLocale "%a, %d %b %Y %H:%M:%S %z" s
            <|> parseTimeM True defaultTimeLocale "%Y-%m-%d" s

data PBListResponse a = PBListResponse
    { pblPage :: !Int
    , pblPerPage :: !Int
    , pblTotalItems :: !Int
    , pblTotalPages :: !Int
    , pblItems :: ![a]
    }
    deriving (Show, Eq)

instance (FromJSON a) => FromJSON (PBListResponse a) where
    parseJSON = withObject "PBListResponse" $ \o ->
        PBListResponse
            <$> o .:? "page" .!= 1
            <*> o .:? "perPage" .!= 500
            <*> o .:? "totalItems" .!= 0
            <*> o .:? "totalPages" .!= 1
            <*> o .:? "items" .!= []

data PBGroupRecord = PBGroupRecord
    { pbgId :: !(Maybe Text)
    , pbgName :: !Text
    , pbgTitle :: !(Maybe Text)
    }
    deriving (Show, Eq)

instance FromJSON PBGroupRecord where
    parseJSON = withObject "PBGroupRecord" $ \o ->
        PBGroupRecord
            <$> o .:? "id"
            <*> o .: "name"
            <*> o .:? "title"

newtype PBFeedExpand = PBFeedExpand
    { pbfeGroups :: Maybe [PBGroupRecord]
    }
    deriving stock (Show, Eq)

instance FromJSON PBFeedExpand where
    parseJSON = withObject "PBFeedExpand" $ \o -> do
        mgrps <-
            Just <$> o .: "groups"
                <|> fmap (: []) <$> o .: "groups"
                <|> pure Nothing
        return $ PBFeedExpand mgrps

data PBFeedRecord = PBFeedRecord
    { pbfId :: !Text
    , pbfUrl :: !Text
    , pbfTitle :: !(Maybe Text)
    , pbfSiteUrl :: !(Maybe Text)
    , pbfFeedType :: !(Maybe Text)
    , pbfGroups :: !(Maybe [Text])
    , pbfEnabled :: !(Maybe Bool)
    , pbfExcludeKeywords :: !(Maybe [Text])
    , pbfExcludeUrls :: !(Maybe [Text])
    , pbfExpand :: !(Maybe PBFeedExpand)
    }
    deriving (Show, Eq)

instance FromJSON PBFeedRecord where
    parseJSON = withObject "PBFeedRecord" $ \o ->
        PBFeedRecord
            <$> o .:? "id" .!= ""
            <*> o .: "url"
            <*> o .:? "title"
            <*> o .:? "site_url"
            <*> o .:? "feed_type"
            <*> (Just <$> o .: "groups" <|> fmap (: []) <$> o .: "groups" <|> pure Nothing)
            <*> o .:? "enabled"
            <*> o .:? "exclude_keywords"
            <*> (o .:? "exclude_urls" <|> o .:? "exclude_list")
            <*> o .:? "expand"

newtype PBItemExpand = PBItemExpand
    { pbieFeed :: Maybe PBFeedRecord
    }
    deriving stock (Show, Eq)

instance FromJSON PBItemExpand where
    parseJSON = withObject "PBItemExpand" $ \o ->
        PBItemExpand
            <$> o .:? "feed"

data PBItemRecord = PBItemRecord
    { pbiId :: !Text
    , pbiFeed :: !(Maybe Text)
    , pbiGuid :: !(Maybe Text)
    , pbiLink :: !Text
    , pbiTitle :: !Text
    , pbiDescription :: !(Maybe Text)
    , pbiSnippet :: !(Maybe Text)
    , pbiAuthor :: !(Maybe Text)
    , pbiPublishedAt :: !Text
    , pbiThumbnail :: !(Maybe Text)
    , pbiMediaType :: !(Maybe Text)
    , pbiIsHidden :: !(Maybe Bool)
    , pbiExpand :: !(Maybe PBItemExpand)
    }
    deriving (Show, Eq)

instance FromJSON PBItemRecord where
    parseJSON = withObject "PBItemRecord" $ \o ->
        PBItemRecord
            <$> o .:? "id" .!= ""
            <*> o .:? "feed"
            <*> o .:? "guid"
            <*> o .: "link"
            <*> o .: "title"
            <*> o .:? "description"
            <*> o .:? "snippet"
            <*> o .:? "author"
            <*> (o .: "published_at" <|> o .: "created" <|> pure "")
            <*> o .:? "thumbnail"
            <*> o .:? "media_type"
            <*> o .:? "is_hidden"
            <*> o .:? "expand"

toFeedConfig :: PBFeedRecord -> FeedConfig
toFeedConfig feed =
    let ft = case fmap (T.toLower . T.strip) (pbfFeedType feed) of
            Just "youtube" -> YouTube
            Just "flickr" -> Image
            Just "kuvatfi" -> Image
            _ -> Feed
        mTitle = case pbfTitle feed of
            Just t | not (T.null (T.strip t)) -> Just (T.strip t)
            _ -> Nothing
        mLink = case pbfSiteUrl feed of
            Just l | not (T.null (T.strip l)) -> Just (T.strip l)
            _ -> Nothing
        exUrls = fromMaybe [] (pbfExcludeUrls feed)
        exKw = fromMaybe [] (pbfExcludeKeywords feed)
        groupName = case pbfExpand feed >>= pbfeGroups of
            Just (g : _) -> pbgName g
            _ -> "fi"
     in FeedConfig
            { feedType = ft
            , feedTitle = mTitle
            , feedUrl = pbfUrl feed
            , feedGroup = groupName
            , feedExcludeList = exUrls
            , feedExcludeKeywords = exKw
            , feedLink = mLink
            }

toAppItem :: PBItemRecord -> AppItem
toAppItem item =
    let mFeed = pbiExpand item >>= pbieFeed
        cleanT = cleanTitle (pbiTitle item)
        mDate = parsePocketBaseDate (pbiPublishedAt item)
        mDesc = pbiDescription item >>= cleanText
        mSnip = pbiSnippet item >>= cleanText
        mDescText = mSnip <|> mDesc
        mThumb = pbiThumbnail item >>= cleanText

        sourceTitle =
            fromMaybe "Feed" $
                (mFeed >>= pbfTitle >>= cleanText)
                    <|> (pbiAuthor item >>= cleanText)

        sourceLink =
            mFeed >>= \f -> (pbfSiteUrl f >>= cleanText) <|> cleanText (pbfUrl f)

        ft = case fmap (T.toLower . T.strip) (pbiMediaType item) of
            Just "video" -> YouTube
            Just "image" -> Image
            Just "article" -> Feed
            _ -> case mFeed >>= pbfFeedType of
                Just t | T.toLower (T.strip t) == "youtube" -> YouTube
                Just t | T.toLower (T.strip t) `elem` ["flickr", "kuvatfi"] -> Image
                _ -> Feed

        groupName = case mFeed >>= pbfExpand >>= pbfeGroups of
            Just (g : _) -> pbgName g
            _ -> "fi"
     in AppItem
            { itemTitle = cleanT
            , itemLink = pbiLink item
            , itemDate = mDate
            , itemDesc = mDesc
            , itemDescText = mDescText
            , itemDescSnippet = mSnip
            , itemThumbnail = mThumb
            , itemSourceTitle = sourceTitle
            , itemSourceLink = sourceLink
            , itemType = ft
            , itemGroup = groupName
            }
  where
    cleanText t
        | not (T.null (T.strip t)) = Just (T.strip t)
        | otherwise = Nothing

fetchPocketBaseFeeds :: Manager -> PocketBaseConfig -> IO [FeedConfig]
fetchPocketBaseFeeds manager config = do
    records <-
        fetchPaginated
            manager
            config
            (pbFeedsCollection config)
            [ ("perPage", Just "500")
            , ("expand", Just "groups")
            , ("sort", Just "created")
            ]
    let activeRecords = filter (\r -> pbfEnabled r /= Just False) records
    return (map toFeedConfig activeRecords)

fetchPocketBaseItems :: Manager -> PocketBaseConfig -> IO [AppItem]
fetchPocketBaseItems manager config = do
    let baseFilter = "is_hidden=false"
        filterParam = case pbSince config of
            Nothing -> "(" <> baseFilter <> ")"
            Just sinceTime ->
                let formatted = T.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S.000Z" sinceTime)
                 in "(" <> baseFilter <> " && published_at >= '" <> formatted <> "')"
    records <-
        fetchPaginated
            manager
            config
            (pbItemsCollection config)
            [ ("filter", Just (encodeUtf8 filterParam))
            , ("sort", Just "-published_at")
            , ("expand", Just "feed,feed.groups")
            , ("perPage", Just "500")
            ]
    let visibleRecords = filter (\r -> pbiIsHidden r /= Just True) records
        allItems = map toAppItem visibleRecords
        filteredItems = case pbSince config of
            Nothing -> allItems
            Just sinceTime -> filter (maybe False (>= sinceTime) . itemDate) allItems
    return filteredItems

fetchPaginated
    :: (FromJSON a)
    => Manager
    -> PocketBaseConfig
    -> Text
    -> [(BS8.ByteString, Maybe BS8.ByteString)]
    -> IO [a]
fetchPaginated manager config collection extraParams = go (1 :: Int) []
  where
    cleanUrl = T.dropWhileEnd (== '/') (pbUrl config)
    endpoint = T.unpack cleanUrl ++ "/api/collections/" ++ T.unpack collection ++ "/records"

    go page acc = do
        let pageParam = [("page", Just (BS8.pack (show page)))]
            allParams = pageParam ++ filter (\(k, _) -> k /= "page") extraParams

        req0 <- parseRequest endpoint
        let authHeader = case pbToken config of
                Just tok ->
                    let rawTok = encodeUtf8 tok
                     in [("Authorization", if "Bearer " `T.isPrefixOf` tok then rawTok else "Bearer " <> rawTok)]
                Nothing -> []
            req =
                setQueryString
                    allParams
                    req0
                        { requestHeaders = ("Accept", "application/json") : authHeader
                        }

        resp <- httpLbs req manager
        let body = responseBody resp
        case eitherDecode body of
            Left err -> do
                putStrLn $ "Error parsing PocketBase response from " ++ endpoint ++ ": " ++ err
                return acc
            Right listResp -> do
                let newAcc = acc ++ pblItems listResp
                if page < pblTotalPages listResp && not (null (pblItems listResp))
                    then go (page + 1) newAcc
                    else return newAcc
