module View exposing (view)

{-| View rendering for the application

@docs view

-}

import Data exposing (AppItem, FeedType(..))
import DateUtils exposing (formatDate)
import FeatherIcons
import Html exposing (Html, a, button, div, footer, h2, h3, img, input, label, li, main_, nav, p, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Json.Decode as Decode
import I18n
import Types exposing (MonthGroup, Msg(..), ViewMode(..), ViewModel)


{-| Main view function
-}
view : ViewModel -> Html Msg
view model =
    div [ Attr.class "min-h-screen bg-white" ]
        [ -- Skip to content link for accessibility
          a
            [ Attr.href "#main-content"
            , Attr.class "sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-brand focus:text-white focus:rounded-lg"
            ]
            [ text (I18n.translate model.lang I18n.SkipToContent) ]
        , -- Mobile top bar: logo + title on left, hamburger on right (same height)
          div [ Attr.class "flex items-center justify-between px-4 h-14 bg-white border-b border-gray-200 sticky top-0 z-40" ]
            [ a [ Attr.href "/", Events.preventDefaultOn "click" (Decode.succeed ( ScrollToTop, True )), Attr.class "flex items-center gap-2" ]
                [ img
                    [ Attr.src "/logo/square/square-smile.svg"
                    , Attr.alt ""
                    , Attr.attribute "aria-hidden" "true"
                    , Attr.class "h-8 w-8"
                    ]
                    []
                , span [ Attr.class "text-lg font-bold text-brand" ] [ text (I18n.translate model.lang I18n.Title) ]
                ]
            , button
                [ Events.onClick ToggleSidebar
                , Attr.class "md:hidden p-2 rounded-lg text-brand"
                , Attr.style "cursor" "pointer"
                , Attr.attribute "aria-label" (if model.isSidebarVisible then I18n.translate model.lang I18n.CloseMenu else I18n.translate model.lang I18n.OpenMenu)
                ]
                [ if model.isSidebarVisible then
                    FeatherIcons.x |> FeatherIcons.withSize 28 |> FeatherIcons.toHtml []
                  else
                    FeatherIcons.menu |> FeatherIcons.withSize 28 |> FeatherIcons.toHtml []
                ]
            ]
        , div [ Attr.class "flex" ]
            [ -- Timeline navigation
              renderTimelineNav model.lang model.visibleGroups
            , -- Main content
              main_
                [ Attr.id "main-content"
                , Attr.class "flex-1 p-6 max-w-5xl mx-auto px-4"
                ]
                [ 
                 Html.Keyed.node "div"
                    []
                    (List.map
                        (\group -> ( group.monthId, renderMonthSection model.lang model.viewMode group ))
                        model.visibleGroups
                    )
                , renderFooter model.lang model.generatedAt
                ]
            , -- Feed filter navigation
              renderFeedFilterNav model.lang model.selectedFeedTypes model.searchText model.viewMode
            ]
        , -- Mobile sidebar
          renderMobileSidebar model
        , -- Overlay for mobile sidebar
          if model.isSidebarVisible then
            div
                [ Attr.class "md:hidden fixed inset-0 z-30"
                , Events.onClick ToggleSidebar
                ]
                []
          else
            text ""
        , -- Scroll to top button
          if model.scrollY > 200 then
            button
                [ Events.onClick ScrollToTop
                , Attr.class "fixed bottom-4 md:right-52 right-4 z-50 p-3 text-white"
                , Attr.style "mix-blend-mode" "difference"
                , Attr.style "cursor" "pointer"
                , Attr.attribute "aria-label" (I18n.translate model.lang I18n.ScrollToTop)
                ]
                [ FeatherIcons.arrowUp |> FeatherIcons.withSize 28 |> FeatherIcons.toHtml [] ]
          else
            text ""
        ]


renderTimelineNav : Types.Lang -> List MonthGroup -> Html Msg
renderTimelineNav lang groups =
    nav [ Attr.class "hidden md:block w-48 bg-white shadow-lg p-4 sticky top-0 h-screen overflow-y-auto" ]
        [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.Timeline) ]
        , ul [ Attr.class "space-y-2" ]
            (List.map
                (\group ->
                    li []
                        [ button
                            [ Events.onClick (NavigateToSection group.monthId)
                            , Attr.class "text-sm text-gray-600 hover:text-brand hover:underline text-left w-full"
                            , Attr.style "cursor" "pointer"
                            , Attr.attribute "aria-label" (I18n.translate lang I18n.NavigateTo ++ group.monthLabel)
                            ]
                            [ text group.monthLabel ]
                        ]
                )
                groups
            )
        ]


renderFeedFilterNav : Types.Lang -> List FeedType -> String -> ViewMode -> Html Msg
renderFeedFilterNav lang selectedFeedTypes searchText viewMode =
    nav [ Attr.class "hidden md:block w-48 bg-white shadow-lg p-4 sticky top-0 h-screen overflow-y-auto" ]
        [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.FeedFilters) ]
        , div [ Attr.class "mb-4" ]
            [ label [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.Search) ]
            , input
                [ Attr.type_ "text"
                , Attr.placeholder (I18n.translate lang I18n.SearchPlaceholder)
                , Attr.value searchText
                , Events.onInput UpdateSearchText
                , Attr.class "w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                ]
                []
            ]
        , div [ Attr.class "flex flex-wrap gap-2 mb-4" ]
            (List.map
                (\feedType ->
                    button
                        [ Events.onClick (ToggleFeedType feedType)
                        , Attr.class ("cursor-pointer p-2 rounded-lg border font-semibold transition-colors duration-150 " ++
                            if List.member feedType selectedFeedTypes then
                                "border-brand text-brand"
                            else
                                "border-transparent text-gray-400 opacity-50 hover:opacity-100 hover:text-brand"
                            )
                        , Attr.title (feedTypeToString lang feedType)
                        , Attr.attribute "aria-label" (feedTypeToString lang feedType)
                        , Attr.attribute "aria-pressed" (if List.member feedType selectedFeedTypes then "true" else "false")
                        ]
                        [ feedTypeIcon feedType ]
                )
                [ Feed, YouTube, Image ]
            )
        , div [ Attr.class "mb-4" ]
            [ label [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.View) ]
            , button
                [ Events.onClick (ToggleViewMode (if viewMode == Full then Thumbnail else Full))
                , Attr.class ("cursor-pointer flex items-center justify-center gap-2 px-3 py-1 text-sm rounded-lg border w-full font-semibold transition-colors duration-150 " ++
                    if viewMode == Full then
                        "border-brand text-brand"
                    else
                        "border-transparent text-gray-400 opacity-50 hover:opacity-100 hover:text-brand"
                    )
                , Attr.attribute "aria-label" (I18n.translate lang I18n.Descriptions)
                , Attr.attribute "aria-pressed" (if viewMode == Full then "true" else "false")
                ]
                [ span [] [ text "👁️" ]
                , span [] [ text (I18n.translate lang I18n.DescriptionsText) ]
                ]
            ]
        ]


renderMobileSidebar : ViewModel -> Html Msg
renderMobileSidebar model =
    div
        [ Attr.class ("md:hidden fixed inset-y-0 left-0 w-64 bg-white shadow-lg z-40 transform overflow-y-auto transition-transform duration-300 ease-in-out motion-reduce:transition-none " ++
            if model.isSidebarVisible then
                "translate-x-0"
            else
                "-translate-x-full"
            )
        ]
        [ -- Close button
          button
            [ Events.onClick ToggleSidebar
            , Attr.class "sr-only"
            , Attr.attribute "aria-label" (I18n.translate model.lang I18n.CloseMenu)
            ]
            [ text (I18n.translate model.lang I18n.Close) ]
        , -- Feed filter navigation
          nav [ Attr.class "p-4" ]
            [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Filters) ]
            , div [ Attr.class "mb-4" ]
                [ label [ Attr.for "mobile-search-input", Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Search) ]
                , input
                    [ Attr.type_ "text"
                    , Attr.id "mobile-search-input"
                    , Attr.placeholder (I18n.translate model.lang I18n.SearchPlaceholder)
                    , Attr.value model.searchText
                    , Events.onInput UpdateSearchText
                    , Attr.class "w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                    ]
                    []
                ]
            , div [ Attr.class "flex flex-wrap gap-2 mb-4" ]
                (List.map
                    (\feedType ->
                        button
                            [ Events.onClick (ToggleFeedType feedType)
                            , Attr.class ("cursor-pointer p-2 rounded-lg border font-semibold transition-colors duration-150 " ++
                                if List.member feedType model.selectedFeedTypes then
                                    "border-brand text-brand"
                                else
                                    "border-transparent text-gray-400 opacity-50 hover:opacity-100 hover:text-brand"
                                )
                            , Attr.title (feedTypeToString model.lang feedType)
                            , Attr.attribute "aria-label" (feedTypeToString model.lang feedType)
                            , Attr.attribute "aria-pressed" (if List.member feedType model.selectedFeedTypes then "true" else "false")
                            ]
                            [ feedTypeIcon feedType ]
                    )
                    [ Feed, YouTube, Image ]
                )
            , div [ Attr.class "mb-4" ]
                [ label [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.View) ]
                , button
                    [ Events.onClick (ToggleViewMode (if model.viewMode == Full then Thumbnail else Full))
                    , Attr.class ("cursor-pointer flex items-center justify-center gap-2 px-3 py-1 text-sm rounded-lg border w-full font-semibold transition-colors duration-150 " ++
                        if model.viewMode == Full then
                            "border-brand text-brand"
                        else
                            "border-transparent text-gray-400 opacity-50 hover:opacity-100 hover:text-brand"
                        )
                    , Attr.attribute "aria-label" (I18n.translate model.lang I18n.Descriptions)
                    , Attr.attribute "aria-pressed" (if model.viewMode == Full then "true" else "false")
                    ]
                    [ span [] [ text "👁️" ]
                    , span [] [ text (I18n.translate model.lang I18n.DescriptionsText) ]
                    ]
                ]
            ]
        , -- Timeline navigation
          nav [ Attr.class "p-4 border-t border-gray-200" ]
            [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Timeline) ]
            , ul [ Attr.class "space-y-2" ]
                (List.map
                    (\group ->
                        li []
                            [ button
                                [ Events.onClick (NavigateToSection group.monthId)
                                , Attr.class "text-sm text-gray-600 hover:text-brand hover:underline text-left w-full"
                                , Attr.style "cursor" "pointer"
                                , Attr.attribute "aria-label" (I18n.translate model.lang I18n.NavigateTo ++ group.monthLabel)
                                ]
                                [ text group.monthLabel ]
                            ]
                    )
                    model.visibleGroups
                )
            ]
        ]


feedTypeToString : Types.Lang -> FeedType -> String
feedTypeToString lang feedType =
    case feedType of
        Feed ->
            I18n.translate lang I18n.FeedName

        YouTube ->
            I18n.translate lang I18n.YouTubeName

        Image ->
            I18n.translate lang I18n.ImageName


renderIntro : Types.Lang -> Html Msg
renderIntro lang =
    div [ Attr.class "mb-8 hidden md:block" ]
        [ a [ Attr.href "/", Events.preventDefaultOn "click" (Decode.succeed ( ScrollToTop, True )), Attr.class "flex items-center gap-4 w-fit" ]
            [ -- Square-smile-full logo (official page-header lockup per design guide logos.jsonld#contextMapping.pageHeader)
              img
                [ Attr.src "/logo/square/square-smile.svg"
                , Attr.alt ""
                , Attr.attribute "aria-hidden" "true"
                , Attr.class "w-20 h-20"
                ]
                []
            , span [ Attr.class "text-3xl font-bold tracking-tight text-brand" ] [ text (I18n.translate lang I18n.Title) ]
            ]
        ]


renderMonthSection : Types.Lang -> ViewMode -> MonthGroup -> Html Msg
renderMonthSection lang viewMode group =
    div
        [ Attr.id group.monthId
        , Attr.class "mb-8"
        , Attr.style "scroll-margin-top" "80px"
        ]
        [ h2 [ Attr.class "text-2xl font-bold text-brand mb-4 border-b border-gray-200 pb-2" ]
            [ text group.monthLabel ]
        , Html.Keyed.node "div"
            [ Attr.class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4" ]
            (List.map
                (\item -> ( item.itemLink, renderCard lang viewMode item ))
                group.items
            )
        ]


renderCard : Types.Lang -> ViewMode -> AppItem -> Html Msg
renderCard lang viewMode item =
    case viewMode of
        Full ->
            renderFullCard lang item

        Thumbnail ->
            renderThumbnailCard lang item


renderFullCard : Types.Lang -> AppItem -> Html Msg
renderFullCard lang item =
    div [ Attr.class "bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow" ]
        [ -- Card image
          case item.itemThumbnail of
            Just url ->
                div [ Attr.class "aspect-[4/3] bg-gray-50" ]
                    [ a [ Attr.href item.itemLink, Attr.target "_blank", Attr.rel "noopener noreferrer", Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow) ]
                        [ img
                            [ Attr.src url
                            , Attr.alt item.itemTitle
                            , Attr.class ("w-full h-full object-cover" ++ (if item.itemType /= YouTube then " object-top" else ""))
                            ]
                            []
                        ]
                    ]

            Nothing ->
                div [ Attr.class "aspect-[4/3] bg-gray-50 flex items-center justify-center" ]
                    [ span
                        [ Attr.class "text-gray-400"
                        , Attr.attribute "aria-label" (feedTypeName lang item.itemType)
                        ]
                        [ feedTypeIcon item.itemType ]
                    ]
        , -- Card content
          div [ Attr.class "p-4" ]
            [ -- Source link (Overline style)
              case item.itemSourceLink of
                Just url ->
                    a
                        [ Attr.href url
                        , Attr.target "_blank"
                        , Attr.rel "noopener noreferrer"
                        , Attr.attribute "aria-label" (item.itemSourceTitle ++ I18n.translate lang I18n.OpenInNewWindow)
                        , Attr.class "text-xs font-semibold uppercase tracking-widest text-gray-500 hover:underline"
                        ]
                        [ text item.itemSourceTitle ]

                Nothing ->
                    span [ Attr.class "text-xs font-semibold uppercase tracking-widest text-gray-500" ] [ text item.itemSourceTitle ]
            , -- Title
              h3 [ Attr.class "text-xl font-semibold text-brand mt-1 line-clamp-2" ]
                [ a
                    [ Attr.href item.itemLink
                    , Attr.target "_blank"
                    , Attr.rel "noopener noreferrer"
                    , Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow)
                    , Attr.class "hover:underline"
                    ]
                    [ text item.itemTitle ]
                ]
            , -- Description (truncated)
              case item.itemDescSnippet of
                Just desc ->
                    p [ Attr.class "text-sm font-medium text-gray-500 mt-2 line-clamp-2" ]
                        [ text desc ]

                Nothing ->
                    text ""
            ]
        , -- Card meta (date and type icon)
          div [ Attr.class "px-4 pb-3 flex justify-between items-center" ]
            [ case item.itemDate of
                Just date ->
                    span [ Attr.class "text-sm font-medium text-gray-500" ] [ text (formatDate date) ]

                Nothing ->
                    text ""
            , span
                [ Attr.class "text-gray-400"
                , Attr.title (feedTypeName lang item.itemType)
                , Attr.attribute "aria-label" (feedTypeName lang item.itemType)
                ]
                [ feedTypeIcon item.itemType ]
            ]
        ]


renderThumbnailCard : Types.Lang -> AppItem -> Html Msg
renderThumbnailCard lang item =
    div [ Attr.class "bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow" ]
        [ -- Card image only
          case item.itemThumbnail of
            Just url ->
                div [ Attr.class "aspect-[4/3] bg-gray-50" ]
                    [ a [ Attr.href item.itemLink, Attr.target "_blank", Attr.rel "noopener noreferrer", Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow) ]
                        [ img
                            [ Attr.src url
                            , Attr.alt item.itemTitle
                            , Attr.class ("w-full h-full object-cover" ++ (if item.itemType /= YouTube then " object-top" else ""))
                            ]
                            []
                        ]
                    ]

            Nothing ->
                div [ Attr.class "aspect-[4/3] bg-gray-50 flex items-center justify-center" ]
                    [ a [ Attr.href item.itemLink, Attr.target "_blank", Attr.rel "noopener noreferrer", Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow) ]
                        [ span
                            [ Attr.class "text-gray-400"
                            , Attr.attribute "aria-label" (feedTypeName lang item.itemType)
                            ]
                            [ feedTypeIcon item.itemType ]
                        ]
                    ]
        ]


{-| Get feather icon for feed type
-}
feedTypeIcon : FeedType -> Html Msg
feedTypeIcon feedType =
    case feedType of
        Feed ->
            FeatherIcons.rss |> FeatherIcons.withSize 24 |> FeatherIcons.toHtml []

        YouTube ->
            FeatherIcons.youtube |> FeatherIcons.withSize 24 |> FeatherIcons.toHtml []

        Image ->
            FeatherIcons.camera |> FeatherIcons.withSize 24 |> FeatherIcons.toHtml []


{-| Get human-readable name for feed type
-}
feedTypeName : Types.Lang -> FeedType -> String
feedTypeName lang feedType =
    case feedType of
        Feed ->
            I18n.translate lang I18n.FeedName

        YouTube ->
            I18n.translate lang I18n.YouTubeName

        Image ->
            I18n.translate lang I18n.ImageName


renderFooter : Types.Lang -> String -> Html Msg
renderFooter lang timestamp =
    footer [ Attr.class "mt-12 pt-6 border-t border-gray-200 text-center text-gray-500 text-sm" ]
        [ p [] [ text (I18n.translate lang I18n.Description) ]
        , p [ Attr.class "mt-1"
                , Attr.style "cursor" "pointer"
     ] [ text (I18n.translate lang I18n.Compiled ++ timestamp ++ " | "), a [ Attr.href "opml.xml", Attr.download "" ] [ text (I18n.translate lang I18n.DownloadOpml) ] ]
        ]
