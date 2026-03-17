module Main exposing (main, init, update, subscriptions, addAsterisks)

{-| Main entry point for the Palikkalinkit application

This module orchestrates the Elm application, delegating to specialized modules:

  - Types: Core type definitions
  - DateUtils: Date formatting and grouping utilities
  - View: UI rendering logic
  - Data: Feed data and types

-}

import Browser
import Browser.Navigation
import Data exposing (allAppItems, AppItem, FeedType(..))
import DateUtils exposing (groupByMonth)
import Html exposing (Html)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Process
import RemoteData
import Task
import Types exposing (Model, Msg(..), ViewMode(..), ViewModel, SearchItem, Lang(..))
import Url
import View


{-| Flags passed from JavaScript containing timestamp, saved view mode, and saved selected feed types
-}
type alias Flags =
    { timestamp : String
    , viewMode : String
    , selectedFeedTypes : String
    }


{-| Parse view mode string to ViewMode, defaulting to Full
-}
parseViewMode : String -> ViewMode
parseViewMode str =
    case str of
        "Thumbnail" ->
            Thumbnail

        _ ->
            Full


{-| Convert ViewMode to string for localStorage
-}
viewModeToString : ViewMode -> String
viewModeToString viewMode =
    case viewMode of
        Full ->
            "Full"

        Thumbnail ->
            "Thumbnail"


{-| Convert FeedType to string
-}
feedTypeToString : FeedType -> String
feedTypeToString feedType =
    case feedType of
        Feed ->
            "Feed"

        YouTube ->
            "YouTube"

        Image ->
            "Image"


{-| Parse string to FeedType, defaulting to Feed
-}
stringToFeedType : String -> FeedType
stringToFeedType str =
    case str of
        "YouTube" ->
            YouTube

        "Image" ->
            Image

        _ ->
            Feed


{-| Encode list of FeedType to JSON string
-}
encodeSelectedFeedTypes : List FeedType -> String
encodeSelectedFeedTypes feedTypes =
    feedTypes
        |> List.map feedTypeToString
        |> Encode.list Encode.string
        |> Encode.encode 0


{-| Decode JSON string to list of FeedType
-}
decodeSelectedFeedTypes : String -> List FeedType
decodeSelectedFeedTypes str =
    case Decode.decodeString (Decode.list Decode.string) str of
        Ok strings ->
            List.map stringToFeedType strings

        Err _ ->
            [ Feed, YouTube, Image ] -- default


{-| Decode SearchItem from JSON
-}
decodeSearchItem : Decode.Decoder SearchItem
decodeSearchItem =
    Decode.map4 SearchItem
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "source" Decode.string)


{-| Add asterisks around each search term for wildcard matching
-}
addAsterisks : String -> String
addAsterisks text =
    text
        |> String.words
        |> List.map (\word -> "*" ++ word ++ "*")
        |> String.join " "


{-| Main program entry point
-}
main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


{-| View function (delegate to View module)
-}
view : Model -> Browser.Document Msg
view model =
    { title = "Palikkalinkit — Suomen Palikkaharrastajat ry"
    , body = [ View.view (modelToViewModel model) ]
    }


{-| Convert Model to ViewModel for rendering
-}
modelToViewModel : Model -> ViewModel
modelToViewModel model =
    { items = model.items
    , generatedAt = model.generatedAt
    , selectedFeedTypes = model.selectedFeedTypes
    , searchText = model.searchText
    , viewMode = model.viewMode
    , visibleGroups = model.visibleGroups
    , isSidebarVisible = model.isSidebarVisible
    , searchIndex = model.searchIndex
    , searchedIds = model.searchedIds
    , scrollY = model.scrollY
    , lang = model.lang
    }



-- MODEL


{-| Initialize the model with feed items, generation timestamp, and all feed types selected
-}
init : Flags -> Url.Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags _ navKey =
    let
        model =
            { items = allAppItems
            , generatedAt = flags.timestamp
            , selectedFeedTypes = decodeSelectedFeedTypes flags.selectedFeedTypes
            , searchText = ""
            , viewMode = parseViewMode flags.viewMode
            , visibleGroups = []
            , isSidebarVisible = False
            , searchIndex = RemoteData.NotAsked
            , searchedIds = []
            , scrollY = 0
            , navKey = Just navKey
            , lang = Fi
            }
    in
    ( recalculateVisibleGroups { model | visibleGroups = groupByMonth allAppItems }, Cmd.none )



-- UPDATE


{-| Update function for the Elm Architecture
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ToggleFeedType feedType ->
            let
                newSelected =
                    if List.member feedType model.selectedFeedTypes then
                        List.filter ((/=) feedType) model.selectedFeedTypes

                    else
                        feedType :: model.selectedFeedTypes

                newModel =
                    { model | selectedFeedTypes = newSelected }
            in
            ( recalculateVisibleGroups newModel
            , Ports.saveSelectedFeedTypes (encodeSelectedFeedTypes newSelected)
            )

        UpdateSearchText text ->
            let
                cmd =
                    if String.isEmpty text then
                        Cmd.none
                    else
                        case model.searchIndex of
                            RemoteData.Success _ ->
                                Ports.performSearch (addAsterisks text)
                            RemoteData.NotAsked ->
                                Http.get
                                    { url = "/search-index.json"
                                    , expect = Http.expectJson OnSearchIndexFetch (Decode.list decodeSearchItem)
                                    }
                            _ ->
                                Cmd.none
            in
            ( { model | searchText = text, searchedIds = if String.isEmpty text then [] else model.searchedIds }
            , cmd
            )

        ApplySearch ->
            ( model, Cmd.none )

        OnSearchResults ids ->
            ( { model | searchedIds = ids } |> recalculateVisibleGroups, Cmd.none )

        ToggleViewMode viewMode ->
            ( { model | viewMode = viewMode }
            , Ports.saveViewMode (viewModeToString viewMode)
            )

        ToggleSidebar ->
            let
                newVisible = not model.isSidebarVisible
                cmd = if newVisible then Ports.focusMobileSearch () else Cmd.none
            in
            ( { model | isSidebarVisible = newVisible }, cmd )

        OnSearchIndexFetch result ->
            let
                newModel = { model | searchIndex = RemoteData.fromResult result }
            in
            ( recalculateVisibleGroups newModel, Cmd.none )

        LoadViewMode viewModeStr ->
            ( { model | viewMode = parseViewMode viewModeStr }, Cmd.none )

        LoadSelectedFeedTypes feedTypesStr ->
            ( { model | selectedFeedTypes = decodeSelectedFeedTypes feedTypesStr } |> recalculateVisibleGroups, Cmd.none )

        ScrollY y ->
            ( { model | scrollY = y }, Cmd.none )

        ScrollToTop ->
            ( model, Ports.scrollToTop () )

        NavigateToSection sectionId ->
            case model.navKey of
                Just key ->
                    ( { model | isSidebarVisible = False }, Cmd.batch [ Browser.Navigation.pushUrl key ("#" ++ sectionId), Ports.scrollToElement sectionId ] )
                Nothing ->
                    ( { model | isSidebarVisible = False }, Ports.scrollToElement sectionId )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case model.navKey of
                        Just key ->
                            ( model, Browser.Navigation.pushUrl key (Url.toString url) )
                        Nothing ->
                            ( model, Cmd.none )

                Browser.External href ->
                    ( model, Browser.Navigation.load href )

        UrlChanged url ->
            ( model, Cmd.none )


recalculateVisibleGroups : Model -> Model
recalculateVisibleGroups model =
    let
        baseItems =
            if String.isEmpty model.searchText then
                model.items
            else
                List.filterMap (\idx -> List.drop idx model.items |> List.head) model.searchedIds

        filteredItems =
            baseItems
                |> List.filter (\item -> List.member item.itemType model.selectedFeedTypes)
    in
    { model | visibleGroups = groupByMonth filteredItems }


{-| Check if an item matches the search text (case insensitive)
-}
matchesSearch : Model -> AppItem -> Bool
matchesSearch model item =
    case ( String.isEmpty model.searchText, model.searchIndex ) of
        ( True, _ ) ->
            True

        ( False, RemoteData.Success searchItems ) ->
            let
                lowerSearch = String.toLower model.searchText
                matchingIds = 
                    searchItems
                        |> List.filter (\si -> 
                            String.contains lowerSearch (String.toLower si.title) ||
                            String.contains lowerSearch (String.toLower si.description) ||
                            String.contains lowerSearch (String.toLower si.source)
                        )
                        |> List.map .id
            in
            List.member item.itemLink matchingIds

        ( False, _ ) ->
            -- Fallback to old logic if search index not loaded
            let
                lowerSearch = String.toLower model.searchText
                matches str = String.contains lowerSearch (String.toLower str)
            in
            matches item.itemSourceTitle
                || matches item.itemTitle
                || (item.itemDescSnippet |> Maybe.map matches |> Maybe.withDefault False)






-- SUBSCRIPTIONS


{-| Subscriptions for ports
-}
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.loadViewMode LoadViewMode
        , Ports.loadSelectedFeedTypes LoadSelectedFeedTypes
        , Ports.searchResults OnSearchResults
        , Ports.onScroll ScrollY
        ]
