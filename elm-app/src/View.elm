module View exposing (view)

{-| View rendering for the application

@docs view

-}

import Component.Button as Button
import Component.Form as Form
import Component.Layout as Layout
import Data exposing (AppItem, FeedType(..))
import DateUtils exposing (formatDate)
import DesignTokens.Spacing as Spacing
import FeatherIcons
import Html exposing (Html, a, button, div, h2, h3, img, li, main_, nav, p, span, text, ul)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import I18n
import Json.Decode as Decode
import Lang exposing (Lang)
import Tailwind as Tw exposing (classes)
import Tailwind.Breakpoints as Bp
import Tailwind.Theme as Th
import TailwindExtra as TwEx
import Types exposing (MonthGroup, Msg(..), ViewMode(..), ViewModel)
import UiStrings


{-| Main view function: the shared family shell around the feed timeline.
-}
view : ViewModel -> Html Msg
view model =
    let
        lang =
            model.lang
    in
    div []
        (Layout.view
            { site = model.site
            , strings = UiStrings.forLang lang
            , attributes = [ Attr.class "min-h-screen flex flex-col bg-bg-page" ]
            , home = { href = "/", onClick = Just ScrollToTop }
            , links = []
            , headerActions = [ renderGroupToggle lang model.currentGroup ]
            , showHeader = True
            , menu =
                Just
                    { isOpen = model.isSidebarVisible
                    , onToggle = ToggleSidebar
                    , onClose = ToggleSidebar
                    , content = \_ -> mobileSidebarContent model
                    }
            , main =
                div [ Attr.class "flex flex-1" ]
                    [ -- Timeline navigation
                      renderTimelineNav lang model.visibleGroups
                    , -- Main content
                      main_
                        [ Attr.id "main-content"
                        , Attr.class "flex-1 max-w-5xl mx-auto w-full px-4 py-6"
                        ]
                        [ Html.Keyed.node "div"
                            []
                            (List.map
                                (\group -> ( group.monthId, renderMonthSection lang model.viewMode group ))
                                model.visibleGroups
                            )
                        ]
                    , -- Feed filter navigation
                      renderFeedFilterNav lang model.selectedFeedTypes model.searchText model.viewMode
                    ]
            , aboveFooter = []
            , footer = Just { topMargin = False, extra = footerExtra lang model.contactEmail model.generatedAt model.currentGroup }
            , scrollToTop =
                Just
                    { visible = model.scrollY > 200
                    , onClick = ScrollToTop
                    , clearRightColumn = True
                    }
            , toasts = Nothing
            , overlays = []
            }
        )


{-| Lines under the footer's disclaimer: reporting, build time and OPML export.
-}
footerExtra : Lang -> String -> String -> String -> List (Html Msg)
footerExtra lang contactEmail timestamp currentGroup =
    let
        linkClasses =
            classes
                [ TwEx.text_white_80
                , Bp.hover [ Tw.text_simple Th.white ]
                , Tw.underline
                , Bp.withVariant "motion-safe" [ Tw.transition_colors ]
                , Bp.focus_visible [ Tw.outline_none, Tw.ring_2, TwEx.ring_brand_yellow ]
                ]
    in
    [ Html.p []
        [ Html.a
            [ Attr.href (I18n.reportContentMailto lang contactEmail), linkClasses ]
            [ Html.text (I18n.translate lang I18n.ReportInappropriateContent) ]
        ]
    , Html.p []
        [ Html.text (I18n.translate lang I18n.Compiled ++ timestamp ++ " | ")
        , Html.a
            [ linkClasses
            , Attr.href ("/opml." ++ currentGroup ++ ".xml")
            , Attr.download ""
            ]
            [ Html.text (I18n.translate lang I18n.DownloadOpml) ]
        ]
    ]


renderGroupToggle : Lang -> String -> Html Msg
renderGroupToggle lang currentGroup =
    div [ Attr.class "flex items-center gap-1 rounded-lg bg-white/10 p-1" ]
        [ groupToggleButton lang currentGroup "fi" [ finnishFlagIcon ]
        , groupToggleButton lang currentGroup "en" [ FeatherIcons.globe |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml decorativeIconAttrs ]
        ]


groupToggleButton : Lang -> String -> String -> List (Html Msg) -> Html Msg
groupToggleButton lang currentGroup group iconContent =
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
        , Attr.attribute "aria-label" (I18n.translate lang I18n.ShowGroup ++ String.toUpper group)
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


renderTimelineNav : Lang -> List MonthGroup -> Html Msg
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


renderFeedFilterNav : Lang -> List FeedType -> String -> ViewMode -> Html Msg
renderFeedFilterNav lang selectedFeedTypes searchText viewMode =
    let
        searchField =
            Form.defaultField "desktop-search-input" (I18n.translate lang I18n.Search)
    in
    nav [ Attr.class "timeline-nav hidden md:block w-48 bg-white shadow-lg p-4 sticky top-0 h-screen overflow-y-auto" ]
        [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate lang I18n.FeedFilters) ]
        , Form.textInput
            { searchField | labelHidden = True }
            { value = searchText
            , onInput = UpdateSearchText
            , inputType = Form.Search
            , placeholder = Just (I18n.translate lang I18n.SearchPlaceholder)
            }
        , div [ Attr.class "flex flex-wrap gap-2 mb-4" ]
            (List.map
                (\feedType ->
                    let
                        isSelected =
                            List.member feedType selectedFeedTypes
                    in
                    Button.new
                        { label = feedTypeToString lang feedType
                        , onClick = ToggleFeedType feedType
                        }
                        |> Button.withVariant
                            (if isSelected then
                                Button.Primary

                             else
                                Button.Ghost
                            )
                        |> Button.withSize Button.Medium
                        |> Button.withIcon (feedTypeFeatherIcon feedType)
                        |> Button.iconOnly
                        |> Button.withPressed (Just isSelected)
                        |> Button.toHtml
                )
                [ Feed, YouTube, Image ]
            )
        , div [ Attr.class "mb-4" ]
            [ button
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
                [ span [] [ FeatherIcons.eye |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml decorativeIconAttrs ]
                , span [] [ text (I18n.translate lang I18n.DescriptionsText) ]
                ]
            ]
        ]


decorativeIconAttrs : List (Html.Attribute msg)
decorativeIconAttrs =
    [ Attr.attribute "aria-hidden" "true", Attr.attribute "focusable" "false" ]


{-| What the mobile drawer shows: search, feed filters and the timeline.
-}
mobileSidebarContent : ViewModel -> List (Html Msg)
mobileSidebarContent model =
    let
        searchField =
            Form.defaultField "mobile-search-input" (I18n.translate model.lang I18n.Search)
    in
    [ nav [ Attr.class "p-4" ]
        [ h2 [ Attr.class "sr-only" ] [ text (I18n.translate model.lang I18n.Filters) ]
        , Form.textInput
            { searchField | labelHidden = True }
            { value = model.searchText
            , onInput = UpdateSearchText
            , inputType = Form.Search
            , placeholder = Just (I18n.translate model.lang I18n.SearchPlaceholder)
            }
        , div [ Attr.class "flex flex-wrap gap-2 mb-4" ]
            (List.map
                (\feedType ->
                    let
                        isSelected =
                            List.member feedType model.selectedFeedTypes
                    in
                    Button.new
                        { label = feedTypeToString model.lang feedType
                        , onClick = ToggleFeedType feedType
                        }
                        |> Button.withVariant
                            (if isSelected then
                                Button.Primary

                             else
                                Button.Ghost
                            )
                        |> Button.withSize Button.Medium
                        |> Button.withIcon (feedTypeFeatherIcon feedType)
                        |> Button.iconOnly
                        |> Button.withPressed (Just isSelected)
                        |> Button.toHtml
                )
                [ Feed, YouTube, Image ]
            )
        , div [ Attr.class "mb-4" ]
            [ button
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
                [ span [] [ FeatherIcons.eye |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml decorativeIconAttrs ]
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


feedTypeToString : Lang -> FeedType -> String
feedTypeToString lang feedType =
    case feedType of
        Feed ->
            I18n.translate lang I18n.FeedName

        YouTube ->
            I18n.translate lang I18n.YouTubeName

        Image ->
            I18n.translate lang I18n.ImageName


renderMonthSection : Lang -> ViewMode -> MonthGroup -> Html Msg
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


renderCard : Lang -> ViewMode -> AppItem -> Html Msg
renderCard lang viewMode item =
    case viewMode of
        Full ->
            renderFullCard lang item

        Thumbnail ->
            renderThumbnailCard lang item


renderFullCard : Lang -> AppItem -> Html Msg
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
                        [ span (itemLang lang item) [ text item.itemSourceTitle ] ]

                Nothing ->
                    span [ Attr.class "type-overline text-text-muted" ] [ span (itemLang lang item) [ text item.itemSourceTitle ] ]
            , -- Title
              h3 [ Attr.class "type-h4 text-brand mt-1 line-clamp-2" ]
                [ a
                    [ Attr.href item.itemLink
                    , Attr.target "_blank"
                    , Attr.rel "noopener noreferrer"
                    , Attr.attribute "aria-label" (item.itemTitle ++ I18n.translate lang I18n.OpenInNewWindow)
                    , Attr.class "hover:underline"
                    ]
                    [ span (itemLang lang item) [ text item.itemTitle ] ]
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


renderThumbnailCard : Lang -> AppItem -> Html Msg
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
feedTypeFeatherIcon : FeedType -> FeatherIcons.Icon
feedTypeFeatherIcon feedType =
    case feedType of
        Feed ->
            FeatherIcons.rss

        YouTube ->
            FeatherIcons.youtube

        Image ->
            FeatherIcons.camera


{-| Render feather icon HTML for feed type
-}
feedTypeIcon : FeedType -> Html Msg
feedTypeIcon feedType =
    feedTypeFeatherIcon feedType
        |> FeatherIcons.withSize 24
        |> FeatherIcons.toHtml decorativeIconAttrs


{-| Get human-readable name for feed type
-}
feedTypeName : Lang -> FeedType -> String
feedTypeName lang feedType =
    case feedType of
        Feed ->
            I18n.translate lang I18n.FeedName

        YouTube ->
            I18n.translate lang I18n.YouTubeName

        Image ->
            I18n.translate lang I18n.ImageName


{-| The `lang` attribute for a feed item's own text: items are in the language
of their group ("fi", "en"), which may differ from the interface language.
-}
itemLang : Lang -> AppItem -> List (Html.Attribute msg)
itemLang lang item =
    if item.itemGroup == Lang.toString lang then
        []

    else
        [ Attr.lang item.itemGroup ]
