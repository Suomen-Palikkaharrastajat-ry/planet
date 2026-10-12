module I18n exposing (MsgKey(..), monthName, translate)

{-| Internationalization module

@docs MsgKey, monthName, translate

-}

import Lang exposing (Lang(..))


{-| Translation keys
-}
type MsgKey
    = Timeline
    | UndatedItems
    | ShowGroup
    | ReportInappropriateContentHref
    | UnknownMonth
    | Search
    | SearchPlaceholder
    | FeedFilters
    | Filters
    | View
    | Descriptions
    | DescriptionsText
    | Compiled
    | DownloadOpml
    | FeedName
    | YouTubeName
    | ImageName
    | OpenInNewWindow
    | NavigateTo
    | ReportInappropriateContent


{-| Translate a key to the given language
-}
translate : Lang -> MsgKey -> String
translate lang key =
    case lang of
        Fi ->
            case key of
                UndatedItems ->
                    "Vanhemmat / Päiväämättömät"

                ShowGroup ->
                    "Näytä ryhmä "

                ReportInappropriateContentHref ->
                    "mailto:palikkaharrastajatry@outlook.com?subject=Ilmoitus%20asiattomasta%20palikkalinkist%C3%A4"

                UnknownMonth ->
                    "Tuntematon"

                Timeline ->
                    "Aikajana"

                Search ->
                    "Haku"

                SearchPlaceholder ->
                    "Hae..."

                FeedFilters ->
                    "Syötesuodattimet"

                Filters ->
                    "Suodattimet"

                View ->
                    "Näkymä"

                Descriptions ->
                    "Kuvaukset"

                DescriptionsText ->
                    "Kuvaukset"

                Compiled ->
                    "Kooste päivitetty "

                DownloadOpml ->
                    "Lataa OPML"

                FeedName ->
                    "Syöte"

                YouTubeName ->
                    "YouTube-video"

                ImageName ->
                    "Kuva"

                OpenInNewWindow ->
                    " (avaa uudessa ikkunassa)"

                NavigateTo ->
                    "Siirry "

                ReportInappropriateContent ->
                    "Ilmoita asiattomasta sisällöstä."

        En ->
            case key of
                UndatedItems ->
                    "Older / undated"

                ShowGroup ->
                    "Show group "

                ReportInappropriateContentHref ->
                    "mailto:palikkaharrastajatry@outlook.com?subject=Report%20of%20inappropriate%20content%20on%20Palikkalinkit"

                UnknownMonth ->
                    "Unknown"

                Timeline ->
                    "Timeline"

                Search ->
                    "Search"

                SearchPlaceholder ->
                    "Search..."

                FeedFilters ->
                    "Feed filters"

                Filters ->
                    "Filters"

                View ->
                    "View"

                Descriptions ->
                    "Descriptions"

                DescriptionsText ->
                    "Descriptions"

                Compiled ->
                    "Compiled "

                DownloadOpml ->
                    "Download OPML"

                FeedName ->
                    "Feed"

                YouTubeName ->
                    "YouTube"

                ImageName ->
                    "Image"

                OpenInNewWindow ->
                    " (open in new window)"

                NavigateTo ->
                    "Navigate to "

                ReportInappropriateContent ->
                    "Report inappropriate content."


{-| Lower-case month name for a month number (1–12), as used in the timeline
headings ("tammikuu 2026").
-}
monthName : Lang -> Int -> String
monthName lang month =
    let
        names =
            case lang of
                Fi ->
                    [ "tammikuu", "helmikuu", "maaliskuu", "huhtikuu", "toukokuu", "kesäkuu", "heinäkuu", "elokuu", "syyskuu", "lokakuu", "marraskuu", "joulukuu" ]

                En ->
                    [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]
    in
    if month < 1 then
        translate lang UnknownMonth

    else
        names
            |> List.drop (month - 1)
            |> List.head
            |> Maybe.withDefault (translate lang UnknownMonth)
