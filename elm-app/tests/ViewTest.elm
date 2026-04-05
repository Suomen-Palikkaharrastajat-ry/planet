module ViewTest exposing (suite)

{-| Tests for View module

-}

import Data exposing (AppItem, FeedType(..))
import Expect
import Html exposing (Html)
import Html.Attributes
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (Lang(..), Model, Msg(..), ViewMode(..), ViewModel)
import View


suite : Test
suite =
    describe "View module"
        [ describe "view function"
            [ test "renders main container" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.class "min-h-screen" ]
            , test "renders skip to content link" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Html.Attributes.href "#main-content") ]
            , test "renders main content area" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.id "main-content" ]
            , test "renders footer with generation timestamp and OPML link" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "footer" ]
                        |> Query.has [ Selector.text "Koottu 2026-01-09" ]
            , test "renders OPML download link in footer" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a", Selector.attribute (Html.Attributes.href "opml.xml") ]
                        |> Query.has [ Selector.text "Lataa OPML" ]
            , test "renders title as link to root" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "a", Selector.attribute (Html.Attributes.href "/") ]
                        |> Query.first
                        |> Query.has [ Selector.text "Palikkalinkit" ]
            , test "renders items in cards" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ { itemTitle = "Test Item"
                                  , itemLink = "https://example.com"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Test description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Test Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026"
                                  , monthId = "m-2026-01"
                                  , items =
                                        [ { itemTitle = "Test Item"
                                          , itemLink = "https://example.com"
                                          , itemDate = Just "2026-01-08T19:27:04Z"
                                          , itemDescSnippet = Just "Test description"
                                          , itemThumbnail = Nothing
                                          , itemSourceTitle = "Test Source"
                                          , itemSourceLink = Nothing
                                          , itemType = Feed
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Test Item" ]
            , test "renders navigation for multiple months" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ createTestItem "2026-01-08T19:27:04Z" "Item 1"
                                , createTestItem "2025-12-25T10:00:00Z" "Item 2"
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026", monthId = "m-2026-01", items = [ createTestItem "2026-01-08T19:27:04Z" "Item 1" ] }
                                , { monthLabel = "joulukuu 2025", monthId = "m-2025-12", items = [ createTestItem "2025-12-25T10:00:00Z" "Item 2" ] }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "nav" ]
                        |> Query.index 0
                        |> Query.has [ Selector.text "tammikuu 2026" ]
            , test "renders mobile sidebar search input when sidebar is visible" <|
                \_ ->
                    let
                        model : ViewModel
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = True
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.id "mobile-search-input" ]
            , test "renders card source title and formatted date" <|
                \_ ->
                    let
                        item =
                            { itemTitle = "Test Item"
                            , itemLink = "https://example.com"
                            , itemDate = Just "2026-01-08T19:27:04Z"
                            , itemDescSnippet = Just "Test description"
                            , itemThumbnail = Nothing
                            , itemSourceTitle = "Test Source"
                            , itemSourceLink = Nothing
                            , itemType = Feed
                            }

                        model =
                            { items = [ item ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = [ { monthLabel = "tammikuu 2026", monthId = "m-2026-01", items = [ item ] } ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Test Source", Selector.text "2026-01-08" ]
            , test "filters items based on selected feed types - shows selected" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ { itemTitle = "RSS Item"
                                  , itemLink = "https://example.com/rss"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "RSS description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "RSS Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                , { itemTitle = "YouTube Item"
                                  , itemLink = "https://example.com/yt"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "YouTube description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "YouTube Source"
                                  , itemSourceLink = Nothing
                                  , itemType = YouTube
                                  }
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ] -- Only Feed selected
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026"
                                  , monthId = "m-2026-01"
                                  , items =
                                        [ { itemTitle = "RSS Item"
                                          , itemLink = "https://example.com/rss"
                                          , itemDate = Just "2026-01-08T19:27:04Z"
                                          , itemDescSnippet = Just "RSS description"
                                          , itemThumbnail = Nothing
                                          , itemSourceTitle = "RSS Source"
                                          , itemSourceLink = Nothing
                                          , itemType = Feed
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "RSS Item" ]
            , test "filters items based on selected feed types - hides unselected" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ { itemTitle = "RSS Item"
                                  , itemLink = "https://example.com/rss"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "RSS description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "RSS Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                , { itemTitle = "YouTube Item"
                                  , itemLink = "https://example.com/yt"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "YouTube description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "YouTube Source"
                                  , itemSourceLink = Nothing
                                  , itemType = YouTube
                                  }
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ] -- Only Feed selected
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026"
                                  , monthId = "m-2026-01"
                                  , items =
                                        [ { itemTitle = "RSS Item"
                                          , itemLink = "https://example.com/rss"
                                          , itemDate = Just "2026-01-08T19:27:04Z"
                                          , itemDescSnippet = Just "RSS description"
                                          , itemThumbnail = Nothing
                                          , itemSourceTitle = "RSS Source"
                                          , itemSourceLink = Nothing
                                          , itemType = Feed
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.hasNot [ Selector.text "YouTube Item" ]
            , test "renders search input in feed filter nav" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Html.Attributes.placeholder "Hae...") ]
            , test "filters items based on search text - matches title" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ { itemTitle = "Unique Title"
                                  , itemLink = "https://example.com"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Some description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                , { itemTitle = "Other Item"
                                  , itemLink = "https://example.com/other"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Other description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Other Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ]
                            , searchText = "unique"
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026"
                                  , monthId = "m-2026-01"
                                  , items =
                                        [ { itemTitle = "Unique Title"
                                          , itemLink = "https://example.com"
                                          , itemDate = Just "2026-01-08T19:27:04Z"
                                          , itemDescSnippet = Just "Some description"
                                          , itemThumbnail = Nothing
                                          , itemSourceTitle = "Source"
                                          , itemSourceLink = Nothing
                                          , itemType = Feed
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Unique Title" ]
            , test "filters items based on search text - hides non-matches" <|
                \_ ->
                    let
                        model =
                            { items =
                                [ { itemTitle = "Unique Title"
                                  , itemLink = "https://example.com"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Some description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                , { itemTitle = "Other Item"
                                  , itemLink = "https://example.com/other"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Other description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Other Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  }
                                ]
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ]
                            , searchText = "unique"
                            , viewMode = Types.Full
                            , visibleGroups =
                                [ { monthLabel = "tammikuu 2026"
                                  , monthId = "m-2026-01"
                                  , items =
                                        [ { itemTitle = "Unique Title"
                                          , itemLink = "https://example.com"
                                          , itemDate = Just "2026-01-08T19:27:04Z"
                                          , itemDescSnippet = Just "Some description"
                                          , itemThumbnail = Nothing
                                          , itemSourceTitle = "Source"
                                          , itemSourceLink = Nothing
                                          , itemType = Feed
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.hasNot [ Selector.text "Other Item" ]
            , test "renders feed type icons in filter nav" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "button", Selector.attribute (Html.Attributes.attribute "aria-label" "Syöte") ]
                        |> Query.first
                        |> Query.has [ Selector.class "cursor-pointer" ]
            , test "renders view mode toggle button with correct text" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Kuvaukset" ]
            , test "renders view mode toggle button with aria-label" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.attribute (Html.Attributes.attribute "aria-label" "👁️ Kuvaukset") ]
                        |> Query.first
                        |> Query.has [ Selector.text "Kuvaukset" ]
            , test "renders hamburger menu button on mobile" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-label" "Avaa valikko") ]
            , test "renders hamburger menu button as close when sidebar open" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = True
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-label" "Sulje valikko") ]
            , test "renders hamburger menu button with close icon when sidebar open" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = True
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "button", Selector.attribute (Html.Attributes.attribute "aria-label" "Sulje valikko"), Selector.containing [ Selector.tag "svg" ] ]
                        |> Query.first
                        |> Query.has [ Selector.class "rounded-lg" ]
            , test "renders mobile sidebar when visible" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = True
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.class "translate-x-0" ]
            , test "hides mobile sidebar when not visible" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.class "-translate-x-full" ]
            , test "renders overlay when sidebar is visible" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = True
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.class "bg-black/50" ]
            , test "does not render overlay when sidebar is hidden" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.hasNot [ Selector.class "bg-black/50" ]
            ]
        ]


{-| Helper to create a test item
-}
createTestItem : String -> String -> AppItem
createTestItem date title =
    { itemTitle = title
    , itemLink = "https://example.com"
    , itemDate = Just date
    , itemDescSnippet = Just "Test description"
    , itemThumbnail = Nothing
    , itemSourceTitle = "Test Source"
    , itemSourceLink = Nothing
    , itemType = Feed
    }
