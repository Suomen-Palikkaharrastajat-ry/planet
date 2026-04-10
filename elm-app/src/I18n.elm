module I18n exposing (MsgKey(..), translate)

{-| Internationalization module

@docs MsgKey, translate

-}

import Types exposing (Lang)


{-| Translation keys
-}
type MsgKey
    = SkipToContent
    | Close
    | Open
    | CloseMenu
    | OpenMenu
    | Timeline
    | Search
    | SearchPlaceholder
    | FeedFilters
    | Filters
    | View
    | Descriptions
    | DescriptionsText
    | Title
    | Compiled
    | Description
    | DownloadOpml
    | ScrollToTop
    | FeedName
    | YouTubeName
    | ImageName
    | OpenInNewWindow
    | NavigateTo
    | OrgName
    | FooterBrandName
    | HomePage
    | BrickCalendar
    | BrickLinks
    | ContentOwnership
    | ReportInappropriateContent
    | LegoTrademark
    | LegoDisclaimer


{-| Translate a key to the given language
-}
translate : Types.Lang -> MsgKey -> String
translate lang key =
    case lang of
        Types.Fi ->
            case key of
                SkipToContent ->
                    "Siirry pääsisältöön"

                Close ->
                    "✕"

                Open ->
                    "≡"

                CloseMenu ->
                    "Sulje valikko"

                OpenMenu ->
                    "Avaa valikko"

                Timeline ->
                    "Aikajana"

                Search ->
                    "Haku"

                SearchPlaceholder ->
                    "Hae..."

                FeedFilters ->
                    "Feed filters"

                Filters ->
                    "Suodattimet"

                View ->
                    "Näkymä"

                Descriptions ->
                    "Kuvaukset"

                DescriptionsText ->
                    "Kuvaukset"

                Title ->
                    "Palikkalinkit"

                Compiled ->
                    "Kooste päivitetty "

                Description ->
                    "Suomen Palikkaharrastajat ry:n tuottama syötekooste"

                DownloadOpml ->
                    "Lataa OPML"

                ScrollToTop ->
                    "Siirry ylös"

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

                OrgName ->
                    "Suomen Palikkaharrastajat ry"

                FooterBrandName ->
                    "Palikkaharrastajat"

                HomePage ->
                    "Kotisivut"

                BrickCalendar ->
                    "Palikkakalenteri"

                BrickLinks ->
                    "Palikkalinkit"

                ContentOwnership ->
                    "Sisältö on tekijöidensä omistamaa."

                ReportInappropriateContent ->
                    "Ilmoita asiattomasta sisällöstä."

                LegoTrademark ->
                    "LEGO® on LEGO Groupin rekisteröity tavaramerkki."

                LegoDisclaimer ->
                    "Tämä sivusto ei ole LEGO Groupin virallinen sivusto."

        Types.En ->
            case key of
                SkipToContent ->
                    "Skip to main content"

                Close ->
                    "✕"

                Open ->
                    "≡"

                CloseMenu ->
                    "Close menu"

                OpenMenu ->
                    "Open menu"

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

                Title ->
                    "Palikkalinkit"

                Compiled ->
                    "Compiled "

                Description ->
                    "Feed aggregator produced by Suomen Palikkaharrastajat ry"

                DownloadOpml ->
                    "Download OPML"

                ScrollToTop ->
                    "Scroll to top"

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

                OrgName ->
                    "Suomen Palikkaharrastajat ry"

                FooterBrandName ->
                    "Palikkaharrastajat"

                HomePage ->
                    "Homepage"

                BrickCalendar ->
                    "Palikkakalenteri"

                BrickLinks ->
                    "Palikkalinkit"

                ContentOwnership ->
                    "Content is owned by its creators."

                ReportInappropriateContent ->
                    "Report inappropriate content."

                LegoTrademark ->
                    "LEGO® is a registered trademark of the LEGO Group."

                LegoDisclaimer ->
                    "This site is not an official LEGO Group site."
