module Curtissimo.SplitPane exposing
    ( SplitPane
    , Msg
    , init, subscriptions, update, view
    )

{-| This is documentation.

@docs SplitPane
@docs Msg


## Usage

@docs init, subscriptions, update, view

-}

import Html exposing (Html, div, text)
import Html.Events exposing (onClick)


{-| The model for this module.
-}
type SplitPane
    = SplitPane SplitPaneConfig


type alias SplitPaneConfig =
    { count : Int }


{-| Messages forwarded to this model.
-}
type Msg
    = NoOp


{-| Create an initial value for SplitPane.
-}
init : ( SplitPane, Cmd Msg )
init =
    ( SplitPane { count = 0 }
    , Cmd.none
    )


{-| Subscriptions used to update SplitPane.
-}
subscriptions : SplitPane -> Sub Msg
subscriptions (SplitPane _) =
    Sub.none


{-| Update the state of SplitPane.
-}
update : Msg -> SplitPane -> ( SplitPane, Cmd Msg )
update msg (SplitPane { count }) =
    case msg of
        NoOp ->
            ( SplitPane { count = count }
            , Cmd.none
            )


{-| Generate the view for SplitPane.
-}
view : SplitPane -> Html Msg
view (SplitPane _) =
    div [ onClick NoOp ] [ text "Curtissimo.SplitPane" ]
