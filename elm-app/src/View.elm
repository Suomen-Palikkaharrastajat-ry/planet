module View exposing (view)

{-| View rendering for the application

@docs view

-}

import Component.MobileDrawer as MobileDrawer
import Data exposing (AppItem, FeedType(..))
import DateUtils exposing (formatDate)
import DesignTokens.Spacing as Spacing
import FeatherIcons
import Html exposing (Html, a, button, div, footer, h2, h3, header, img, input, label, li, main_, nav, p, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import I18n
import Json.Decode as Decode
import Types exposing (MonthGroup, Msg(..), ViewMode(..), ViewModel)


{-| Main view function
-}
view : ViewModel -> Html Msg
view model =
    div [ Attr.class "min-h-screen flex flex-col bg-bg-page" ]
        [ -- Skip to content link for accessibility
          a
            [ Attr.href "#main-content"
            , Attr.class "sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-brand focus:text-white focus:rounded-lg"
            ]
            [ text (I18n.translate model.lang I18n.SkipToContent) ]
        , header [ Attr.class "bg-brand border-b border-brand sticky top-0 z-40 md:static" ]
            [ div [ Attr.class "flex items-center justify-between px-4 h-14" ]
                [ a [ Attr.href "/", Events.preventDefaultOn "click" (Decode.succeed ( ScrollToTop, True )), Attr.class "flex items-center gap-2" ]
                    [ img
                        [ Attr.src "/logo/square/square-smile.svg"
                        , Attr.alt ""
                        , Attr.attribute "aria-hidden" "true"
                        , Attr.class "h-8 w-8"
                        ]
                        []
                    , span [ Attr.class "type-h4 text-white" ] [ text (I18n.translate model.lang I18n.Title) ]
                    ]
                , div [ Attr.class "flex items-center gap-2" ]
                    [ renderGroupToggle model.currentGroup
                    , button
                        [ Events.onClick ToggleSidebar
                        , Attr.class "md:hidden p-2 rounded-lg text-white"
                        , Attr.style "cursor" "pointer"
                        , Attr.attribute "aria-label"
                            (if model.isSidebarVisible then
                                I18n.translate model.lang I18n.CloseMenu

                             else
                                I18n.translate model.lang I18n.OpenMenu
                            )
                        ]
                        [ if model.isSidebarVisible then
                            FeatherIcons.x |> FeatherIcons.withSize 28 |> FeatherIcons.toHtml []

                          else
                            FeatherIcons.menu |> FeatherIcons.withSize 28 |> FeatherIcons.toHtml []
                        ]
                    ]
                ]
            ]
        , div [ Attr.class "flex flex-1" ]
            [ -- Timeline navigation
              renderTimelineNav model.lang model.visibleGroups
            , -- Main content
              main_
                [ Attr.id "main-content"
                , Attr.class "flex-1 max-w-5xl mx-auto w-full px-4 py-6"
                ]
                [ Html.Keyed.node "div"
                    []
                    (List.map
                        (\group -> ( group.monthId, renderMonthSection model.lang model.viewMode group ))
                        model.visibleGroups
                    )
                ]
            , -- Feed filter navigation
              renderFeedFilterNav model.lang model.selectedFeedTypes model.searchText model.viewMode
            ]
        , -- Mobile sidebar
          renderMobileSidebar model
        , -- Overlay for mobile sidebar
          MobileDrawer.viewOverlay
            { isOpen = model.isSidebarVisible
            , onClose = ToggleSidebar
            , breakpoint = MobileDrawer.Md
            }
        , -- Brand footer
          viewBrandFooter model.lang model.generatedAt model.currentGroup
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


viewBrandFooter : Types.Lang -> String -> String -> Html Msg
viewBrandFooter lang timestamp currentGroup =
    Html.footer
        [ Attr.class "bg-brand text-white py-12 px-4" ]
        [ Html.div [ Attr.class "max-w-5xl mx-auto" ]
            [ Html.div
                [ Attr.class "grid grid-cols-1 sm:grid-cols-[auto_1fr] gap-8 sm:items-end" ]
                [ -- Col 1: service links + logo
                  Html.div [ Attr.class "flex items-start gap-4" ]
                    [ Html.img
                        [ Attr.src "/logo/square/square-smile-full-dark-bold.svg"
                        , Attr.alt ""
                        , Attr.attribute "aria-hidden" "true"
                        , Attr.class "h-35 w-35 flex-shrink-0"
                        ]
                        []
                    , Html.div [ Attr.class "space-y-3" ]
                        [ Html.p [ Attr.class "text-xs font-semibold text-white/50 uppercase tracking-wider" ]
                            [ Html.text (I18n.translate lang I18n.FooterBrandName) ]
                        , Html.ul [ Attr.class "space-y-2 list-none m-0 p-0" ]
                            [ Html.li []
                                [ Html.a
                                    [ Attr.href "https://palikkaharrastajat.fi"
                                    , Attr.class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ Html.text (I18n.translate lang I18n.HomePage) ]
                                ]
                            , Html.li []
                                [ Html.a
                                    [ Attr.href "https://kalenteri.palikkaharrastajat.fi"
                                    , Attr.class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ Html.text (I18n.translate lang I18n.BrickCalendar) ]
                                ]
                            , Html.li []
                                [ Html.a
                                    [ Attr.href "https://linkit.palikkaharrastajat.fi"
                                    , Attr.class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ Html.text (I18n.translate lang I18n.BrickLinks) ]
                                ]
                            ]
                        ]
                    ]
                , -- Col 2: org name & legal
                  Html.div [ Attr.class "space-y-1 sm:text-right" ]
                    [ Html.div [ Attr.class "space-y-1 text-xs text-white/50" ]
                        [ Html.p [] [ Html.text (I18n.translate lang I18n.ContentOwnership) ]
                        , Html.p []
                            [ Html.a
                                [ Attr.href "mailto:palikkaharrastajatry@outlook.com?subject=Ilmoitus%20asiattomasta%20palikkalinkist%C3%A4"
                                , Attr.class "text-white/80 hover:text-white underline transition-colors"
                                ]
                                [ Html.text (I18n.translate lang I18n.ReportInappropriateContent) ]
                            ]
                        , Html.p []
                            [ Html.text (I18n.translate lang I18n.Compiled ++ timestamp ++ " | ")
                            , a [ Attr.class "hover:text-white underline", Attr.href ("/opml." ++ currentGroup ++ ".xml"), Attr.download "" ] [ text (I18n.translate lang I18n.DownloadOpml) ]
                            ]
                        , Html.p [] [ Html.text (I18n.translate lang I18n.LegoTrademark) ]
                        , Html.p [] [ Html.text (I18n.translate lang I18n.LegoDisclaimer) ]
                        ]
                    ]
                ]
            ]
        ]


renderGroupToggle : String -> Html Msg
renderGroupToggle currentGroup =
    div [ Attr.class "flex items-center gap-1 rounded-lg bg-white/10 p-1" ]
        [ groupToggleButton currentGroup "fi" [ finnishFlagIcon ]
        , groupToggleButton currentGroup "en" [ FeatherIcons.globe |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] ]
        ]


groupToggleButton : String -> String -> List (Html Msg) -> Html Msg
groupToggleButton currentGroup group iconContent =
    button
        [ Events.onClick (NavigateToGroup group)
        , Attr.class
            ("cursor-pointer rounded-md p-2 transition-colors "
                ++ (if currentGroup == group then
                        "bg-brand-yellow text-brand"

                    else
                        "text-white hover:bg-white/20"
                   )
            )
        , Attr.attribute "aria-label" ("Navigate to " ++ String.toUpper group ++ " group")
        , Attr.attribute "aria-pressed"
            (if currentGroup == group then
                "true"

             else
                "false"
            )
        ]
        iconContent


finnishFlagIcon : Html Msg
finnishFlagIcon =
    span
        [ Attr.class "relative block h-[18px] w-[18px] overflow-hidden rounded-sm border border-black/20 bg-white"
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-hidden" "true"
        ]
        [ span [ Attr.class "absolute left-[5px] top-0 h-full w-[4px] bg-[#003580]" ] []
        , span [ Attr.class "absolute left-0 top-[7px] h-[4px] w-full bg-[#003580]" ] []
        ]


renderTimelineNav : Types.Lang -> List MonthGroup -> Html Msg
renderTimelineNav lang groups =
    nav [ Attr.class "timeline-nav hidden md:block w-48 bg-white shadow-lg p-4 sticky top-0 h-screen overflow-y-auto" ]
        [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.Timeline) ]
        , ul [ Attr.class "space-y-2" ]
            (List.map
                (\group ->
                    li []
                        [ button
                            [ Events.onClick (NavigateToSection group.monthId)
                            , Attr.class "type-caption text-text-muted hover:text-brand hover:underline text-left w-full"
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
    nav [ Attr.class "timeline-nav hidden md:block w-48 bg-white shadow-lg p-4 sticky top-0 h-screen overflow-y-auto" ]
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
                        , Attr.class
                            ("cursor-pointer p-2 border font-semibold transition-colors duration-150 "
                                ++ (if List.member feedType selectedFeedTypes then
                                        "border-brand text-brand active:bg-brand-yellow"

                                    else
                                        "border-transparent opacity-50 hover:text-brand active:bg-brand-yellow"
                                   )
                            )
                        , Attr.title (feedTypeToString lang feedType)
                        , Attr.attribute "aria-label" (feedTypeToString lang feedType)
                        , Attr.attribute "aria-pressed"
                            (if List.member feedType selectedFeedTypes then
                                "true"

                             else
                                "false"
                            )
                        ]
                        [ feedTypeIcon feedType ]
                )
                [ Feed, YouTube, Image ]
            )
        , div [ Attr.class "mb-4" ]
            [ label [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.View) ]
            , button
                [ Events.onClick
                    (ToggleViewMode
                        (if viewMode == Full then
                            Thumbnail

                         else
                            Full
                        )
                    )
                , Attr.class
                    ("cursor-pointer flex items-center justify-center gap-2 px-3 py-1 text-sm border w-full font-semibold transition-colors duration-150 "
                        ++ (if viewMode == Full then
                                "border-brand text-brand active:bg-brand-yellow"

                            else
                                "border-transparent opacity-50 hover:text-brand active:bg-brand-yellow"
                           )
                    )
                , Attr.attribute "aria-label" (I18n.translate lang I18n.Descriptions)
                , Attr.attribute "aria-pressed"
                    (if viewMode == Full then
                        "true"

                     else
                        "false"
                    )
                ]
                [ span [] [ FeatherIcons.eye |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml [] ]
                , span [] [ text (I18n.translate lang I18n.DescriptionsText) ]
                ]
            ]
        ]


renderMobileSidebar : ViewModel -> Html Msg
renderMobileSidebar model =
    MobileDrawer.view
        { isOpen = model.isSidebarVisible
        , id = "mobile-sidebar"
        , onClose = ToggleSidebar
        , breakpoint = MobileDrawer.Md
        , content =
            [ nav [ Attr.class "p-4" ]
                [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Filters) ]
                , div [ Attr.class "mb-4" ]
                    [ label [ Attr.for "mobile-search-input", Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Search) ]
                    , input
                        [ Attr.type_ "text"
                        , Attr.id "mobile-search-input"
                        , Attr.placeholder (I18n.translate model.lang I18n.SearchPlaceholder)
                        , Attr.value model.searchText
                        , Events.onInput UpdateSearchText
                        , Attr.class "w-full px-3 py-2 border border-gray-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                        ]
                        []
                    ]
                , div [ Attr.class "flex flex-wrap gap-2 mb-4" ]
                    (List.map
                        (\feedType ->
                            button
                                [ Events.onClick (ToggleFeedType feedType)
                                , Attr.class
                                    ("cursor-pointer p-2 border font-semibold transition-colors duration-150 "
                                        ++ (if List.member feedType model.selectedFeedTypes then
                                                "border-brand text-brand active:bg-brand-yellow"

                                            else
                                                "border-transparent opacity-50 hover:text-brand active:bg-brand-yellow"
                                           )
                                    )
                                , Attr.title (feedTypeToString model.lang feedType)
                                , Attr.attribute "aria-label" (feedTypeToString model.lang feedType)
                                , Attr.attribute "aria-pressed"
                                    (if List.member feedType model.selectedFeedTypes then
                                        "true"

                                     else
                                        "false"
                                    )
                                ]
                                [ feedTypeIcon feedType ]
                        )
                        [ Feed, YouTube, Image ]
                    )
                , div [ Attr.class "mb-4" ]
                    [ label [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.View) ]
                    , button
                        [ Events.onClick
                            (ToggleViewMode
                                (if model.viewMode == Full then
                                    Thumbnail

                                 else
                                    Full
                                )
                            )
                        , Attr.class
                            ("cursor-pointer flex items-center justify-center gap-2 px-3 py-1 text-sm border w-full font-semibold transition-colors duration-150 "
                                ++ (if model.viewMode == Full then
                                        "border-brand text-brand active:bg-brand-yellow"

                                    else
                                        "border-transparent opacity-50 hover:text-brand active:bg-brand-yellow"
                                   )
                            )
                        , Attr.attribute "aria-label" (I18n.translate model.lang I18n.Descriptions)
                        , Attr.attribute "aria-pressed"
                            (if model.viewMode == Full then
                                "true"

                             else
                                "false"
                            )
                        ]
                        [ span [] [ FeatherIcons.eye |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml [] ]
                        , span [] [ text (I18n.translate model.lang I18n.DescriptionsText) ]
                        ]
                    ]
                ]
            , nav [ Attr.class "p-4 border-t border-gray-200" ]
                [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Timeline) ]
                , ul [ Attr.class "space-y-2" ]
                    (List.map
                        (\group ->
                            li []
                                [ button
                                    [ Events.onClick (NavigateToSection group.monthId)
                                    , Attr.class "type-caption text-text-muted hover:text-brand hover:underline text-left w-full"
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
        }


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
            , span [ Attr.class "type-h1 text-brand" ] [ text (I18n.translate lang I18n.Title) ]
            ]
        ]


renderMonthSection : Types.Lang -> ViewMode -> MonthGroup -> Html Msg
renderMonthSection lang viewMode group =
    div
        [ Attr.id group.monthId
        , Attr.class "mb-8"
        , Attr.style "scroll-margin-top" monthSectionScrollMarginTop
        ]
        [ h2 [ Attr.class "type-h2 text-brand mb-4 border-b border-gray-200 pb-2" ]
            [ text group.monthLabel ]
        , Html.Keyed.node "div"
            [ Attr.class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4" ]
            (List.map
                (\item -> ( item.itemLink, renderCard lang viewMode item ))
                group.items
            )
        ]


monthSectionScrollMarginTop : String
monthSectionScrollMarginTop =
    String.fromInt (Spacing.space16 + Spacing.space4) ++ "px"


renderCard : Types.Lang -> ViewMode -> AppItem -> Html Msg
renderCard lang viewMode item =
    case viewMode of
        Full ->
            renderFullCard lang item

        Thumbnail ->
            renderThumbnailCard lang item


renderFullCard : Types.Lang -> AppItem -> Html Msg
renderFullCard lang item =
    div [ Attr.class "card-hover bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow" ]
        [ -- Card image
          case item.itemThumbnail of
            Just url ->
                div [ Attr.class "aspect-[4/3] bg-gray-50" ]
                    [ a [ Attr.href item.itemLink, Attr.target "_blank", Attr.rel "noopener noreferrer", Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow) ]
                        [ img
                            [ Attr.src url
                            , Attr.alt item.itemTitle
                            , Attr.attribute "loading" "lazy"
                            , Attr.class
                                ("w-full h-full object-cover"
                                    ++ (if item.itemType /= YouTube then
                                            " object-top"

                                        else
                                            ""
                                       )
                                )
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
                        , Attr.class "type-overline text-text-muted hover:underline"
                        ]
                        [ text item.itemSourceTitle ]

                Nothing ->
                    span [ Attr.class "type-overline text-text-muted" ] [ text item.itemSourceTitle ]
            , -- Title
              h3 [ Attr.class "type-h4 text-brand mt-1 line-clamp-2" ]
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
                    p [ Attr.class "type-caption text-text-muted mt-2 line-clamp-2" ]
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
                            , Attr.attribute "loading" "lazy"
                            , Attr.class
                                ("w-full h-full object-cover"
                                    ++ (if item.itemType /= YouTube then
                                            " object-top"

                                        else
                                            ""
                                       )
                                )
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
