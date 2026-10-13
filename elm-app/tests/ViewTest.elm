module ViewTest exposing (suite)

{-| Tests for View module
-}

import Data exposing (AppItem, FeedType(..))
import Expect
import Html exposing (Html)
import Html.Attributes
import I18n
import Lang exposing (Lang(..))
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import TestSite
import Types exposing (Model, Msg(..), ViewMode(..), ViewModel)
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "footer" ]
                        |> Query.has [ Selector.text "Kooste päivitetty 2026-01-09" ]
            , test "footer links are the canonical family links without this site" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }

                        expected =
                            [ "https://palikkaharrastajat.fi"
                            , "https://kalenteri.palikkaharrastajat.fi"
                            , "https://kartta.palikkaharrastajat.fi"
                            , "https://forum.palikkaharrastajat.fi"
                            , "https://kortti.palikkaharrastajat.fi"
                            , "https://maksut.palikkaharrastajat.fi"
                            , "https://palikkaharrastajat.fi/tietosuoja"
                            ]
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "footer" ]
                        |> Query.find [ Selector.tag "ul" ]
                        |> Query.findAll [ Selector.tag "a" ]
                        |> Expect.all
                            (Query.count (Expect.equal (List.length expected))
                                :: List.indexedMap
                                    (\i href ->
                                        Query.index i
                                            >> Query.has [ Selector.attribute (Html.Attributes.href href) ]
                                    )
                                    expected
                            )
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a", Selector.attribute (Html.Attributes.href "/opml.fi.xml") ]
                        |> Query.has [ Selector.text "Lataa OPML" ]
            , test "renders group-specific OPML link for en group" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "en"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a", Selector.attribute (Html.Attributes.href "/opml.en.xml") ]
                        |> Query.has [ Selector.text "Lataa OPML" ]
            , test "renders fi and en top group toggle buttons" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute (Html.Attributes.attribute "aria-label" "Näytä ryhmä FI")
                            , Selector.attribute (Html.Attributes.attribute "aria-label" "Näytä ryhmä EN")
                            ]
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                                  , itemGroup = "fi"
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
                                          , itemGroup = "fi"
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , itemGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                                  , itemGroup = "fi"
                                  }
                                , { itemTitle = "YouTube Item"
                                  , itemLink = "https://example.com/yt"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "YouTube description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "YouTube Source"
                                  , itemSourceLink = Nothing
                                  , itemType = YouTube
                                  , itemGroup = "fi"
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
                                          , itemGroup = "fi"
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                                  , itemGroup = "fi"
                                  }
                                , { itemTitle = "YouTube Item"
                                  , itemLink = "https://example.com/yt"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "YouTube description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "YouTube Source"
                                  , itemSourceLink = Nothing
                                  , itemType = YouTube
                                  , itemGroup = "fi"
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
                                          , itemGroup = "fi"
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                                  , itemGroup = "fi"
                                  }
                                , { itemTitle = "Other Item"
                                  , itemLink = "https://example.com/other"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Other description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Other Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  , itemGroup = "fi"
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
                                          , itemGroup = "fi"
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                                  , itemGroup = "fi"
                                  }
                                , { itemTitle = "Other Item"
                                  , itemLink = "https://example.com/other"
                                  , itemDate = Just "2026-01-08T19:27:04Z"
                                  , itemDescSnippet = Just "Other description"
                                  , itemThumbnail = Nothing
                                  , itemSourceTitle = "Other Source"
                                  , itemSourceLink = Nothing
                                  , itemType = Feed
                                  , itemGroup = "fi"
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
                                          , itemGroup = "fi"
                                          }
                                        ]
                                  }
                                ]
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.attribute (Html.Attributes.attribute "aria-label" "Kuvaukset") ]
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.hasNot [ Selector.class "bg-black/50" ]
            , test "desktop search input has associated label and search type" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.tag "label"
                            , Selector.attribute (Html.Attributes.for "desktop-search-input")
                            ]
                        |> (\_ ->
                                View.view model
                                    |> Query.fromHtml
                                    |> Query.has
                                        [ Selector.tag "input"
                                        , Selector.id "desktop-search-input"
                                        , Selector.attribute (Html.Attributes.type_ "search")
                                        ]
                           )
            , test "mobile search input has associated label and search type" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.tag "label"
                            , Selector.attribute (Html.Attributes.for "mobile-search-input")
                            ]
                        |> (\_ ->
                                View.view model
                                    |> Query.fromHtml
                                    |> Query.has
                                        [ Selector.tag "input"
                                        , Selector.id "mobile-search-input"
                                        , Selector.attribute (Html.Attributes.type_ "search")
                                        ]
                           )
            , test "filter buttons expose aria-pressed attribute for selected and unselected states" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }

                        html =
                            View.view model
                                |> Query.fromHtml
                    in
                    Expect.all
                        [ \h ->
                            h
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-pressed" "true")
                                    , Selector.attribute (Html.Attributes.attribute "aria-label" "Syöte")
                                    ]
                        , \h ->
                            h
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-pressed" "false")
                                    , Selector.attribute (Html.Attributes.attribute "aria-label" "YouTube-video")
                                    ]
                        , \h ->
                            h
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-pressed" "false")
                                    , Selector.attribute (Html.Attributes.attribute "aria-label" "Kuva")
                                    ]
                        ]
                        html
            , test "renders scroll to top button when scrolled and hides when at top" <|
                \_ ->
                    let
                        scrolledModel =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed, YouTube, Image ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 300
                            , lang = Fi
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }

                        topModel =
                            { scrolledModel | scrollY = 0 }
                    in
                    Expect.all
                        [ \_ ->
                            View.view scrolledModel
                                |> Query.fromHtml
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-label" "Takaisin ylös")
                                    ]
                        , \_ ->
                            View.view topModel
                                |> Query.fromHtml
                                |> Query.hasNot
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-label" "Takaisin ylös")
                                    ]
                        ]
                        ()
            , test "renders skip to content link targeting main-content" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.tag "a"
                            , Selector.attribute (Html.Attributes.href "#main-content")
                            ]
            , test "view mode button exposes aria-pressed according to viewMode" <|
                \_ ->
                    let
                        fullModel =
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }

                        thumbModel =
                            { fullModel | viewMode = Types.Thumbnail }
                    in
                    Expect.all
                        [ \_ ->
                            View.view fullModel
                                |> Query.fromHtml
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-pressed" "true")
                                    , Selector.containing [ Selector.text "Kuvaukset" ]
                                    ]
                        , \_ ->
                            View.view thumbModel
                                |> Query.fromHtml
                                |> Query.has
                                    [ Selector.tag "button"
                                    , Selector.attribute (Html.Attributes.attribute "aria-pressed" "false")
                                    , Selector.containing [ Selector.text "Kuvaukset" ]
                                    ]
                        ]
                        ()
            ]
        , describe "English"
            [ test "chrome, footer and month headings are English when the language is" <|
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
                            , lang = En
                            , site = TestSite.site En
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ Selector.text "Skip to main content" ]
                            , Query.has [ Selector.text "Content is owned by its creators." ]
                            , Query.has [ Selector.text "LEGO® is a registered trademark of the LEGO Group." ]
                            , Query.has [ Selector.text "Homepage" ]
                            , Query.has [ Selector.text "Suomeksi", Selector.attribute (Html.Attributes.href "?lang=fi") ]
                            ]
            , test "the report link goes to the configured address with a subject in the language" <|
                \_ ->
                    ( I18n.reportContentMailto Fi "a@example.org", I18n.reportContentMailto En "a@example.org" )
                        |> Expect.equal
                            ( "mailto:a@example.org?subject=Ilmoitus%20asiattomasta%20palikkalinkist%C3%A4"
                            , "mailto:a@example.org?subject=Report%20of%20inappropriate%20content%20on%20Palikkalinkit"
                            )
            , test "the Finnish page links to the English one" <|
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
                            , site = TestSite.site Fi
                            , contactEmail = "toimisto@example.org"
                            , currentGroup = "fi"
                            }
                    in
                    View.view model
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "In English", Selector.attribute (Html.Attributes.href "?lang=en") ]
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
    , itemGroup = "fi"
    }
