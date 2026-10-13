module I18n exposing (MsgKey(..), monthName, reportContentMailto, translate)

{-| Internationalization module

@docs MsgKey, monthName, reportContentMailto, translate

-}

import Lang exposing (Lang(..))
import Url


{-| Translation keys
-}
type MsgKey
    = Timeline
    | UndatedItems
    | ShowGroup
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


{-| `mailto:` link for reporting inappropriate content to the given address,
with a subject in the language.
-}
reportContentMailto : Lang -> String -> String
reportContentMailto lang address =
    "mailto:"
        ++ address
        ++ "?subject="
        ++ Url.percentEncode
            (case lang of
                Fi ->
                    "Ilmoitus asiattomasta palikkalinkistä"

                En ->
                    "Report of inappropriate content on Palikkalinkit"
            )
