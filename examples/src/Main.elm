module Main exposing (main)

import Browser
import Curtissimo.SplitPane as SplitPane exposing (SplitPane, useThickGutters)
import Html exposing (Html, b, button, div, input, label, text)
import Html.Attributes as Attrs exposing (checked, class, name, type_)
import Html.Events exposing (onCheck, onClick)


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { nextId : Int
    , pane : Pane
    , position : SplitPane.Position
    , thickGutters : Bool
    }


type Msg
    = SplitHorizontal Int
    | SplitPaneMsg Int SplitPane.Msg
    | SplitPanePositionChanged SplitPane.Position Bool
    | SplitPaneReady
    | SplitVertical Int
    | UseThickGuttersChanged Bool


type Pane
    = Split Paned
    | Splittable Int


type alias Paned =
    { pane : SplitPane Msg
    , id : Int
    , primary : Pane
    , secondary : Pane
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { nextId = 1
      , pane = Splittable 0
      , position = SplitPane.After
      , thickGutters = False
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Curtissimo.SplitPane Demo"
    , body =
        [ controlPanel model
        , renderPaneTree "Main" model.pane
        ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    paneSubscriptions model.pane


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SplitHorizontal target ->
            let
                ( pane, cmd ) =
                    splitPaneTree model.position model.thickGutters model.nextId target SplitPane.Horizontal model.pane
            in
            ( { model
                | nextId = model.nextId + 2
                , pane = pane
              }
            , cmd
            )

        SplitVertical target ->
            let
                ( pane, cmd ) =
                    splitPaneTree model.position model.thickGutters model.nextId target SplitPane.Vertical model.pane
            in
            ( { model
                | nextId = model.nextId + 2
                , pane = pane
              }
            , cmd
            )

        SplitPaneMsg target splitPaneMsg ->
            let
                ( pane, cmd ) =
                    updatePane target splitPaneMsg model.pane
            in
            ( { model | pane = pane }
            , cmd
            )

        SplitPanePositionChanged position _ ->
            ( { model | position = position }
            , Cmd.none
            )

        SplitPaneReady ->
            ( model, Cmd.none )

        UseThickGuttersChanged thickGutters ->
            ( { model
                | pane = updatePaneTreeGutters thickGutters model.pane
                , thickGutters = thickGutters
              }
            , Cmd.none
            )


controlPanel : Model -> Html Msg
controlPanel model =
    div [ class "control-panel" ]
        [ b [] [ text "Curtissimo.SplitPane" ]
        , div []
            [ label [ class "checkbox" ]
                [ input
                    [ type_ "checkbox"
                    , checked model.thickGutters
                    , onCheck UseThickGuttersChanged
                    ]
                    []
                , text " Use thick gutters"
                ]
            ]
        , div [ class "radios" ]
            [ div [] [ b [] [ text "Position:" ] ]
            , div [ class "control" ]
                [ label [ class "radio" ]
                    [ input [ type_ "radio", name "position", checked (model.position == SplitPane.Before), onCheck (SplitPanePositionChanged SplitPane.Before) ] []
                    , text " Before"
                    ]
                , label [ class "radio" ]
                    [ input [ type_ "radio", name "position", checked (model.position == SplitPane.After), onCheck (SplitPanePositionChanged SplitPane.After) ] []
                    , text " After"
                    ]
                ]
            ]
        ]


paneContent : String -> Int -> Html Msg
paneContent label id =
    div [ class "pane-content" ]
        [ div [] [ text label ]
        , div
            [ Attrs.id ("pane-" ++ String.fromInt id) ]
            [ text "Split:\u{00A0}"
            , button [ class "button is-small mr-2", onClick (SplitHorizontal id) ] [ text "H" ]
            , button [ class "button is-small", onClick (SplitVertical id) ] [ text "V" ]
            ]
        ]


paneSubscriptions : Pane -> Sub Msg
paneSubscriptions target =
    case target of
        Split { pane, primary, secondary } ->
            Sub.batch
                [ SplitPane.subscriptions pane
                , paneSubscriptions primary
                , paneSubscriptions secondary
                ]

        _ ->
            Sub.none


renderPaneTree : String -> Pane -> Html Msg
renderPaneTree label current =
    case current of
        Splittable id ->
            paneContent label id

        Split { pane, primary, secondary } ->
            let
                primaryContent : Html Msg
                primaryContent =
                    renderPaneTree "Primary" primary

                secondaryContent : Html Msg
                secondaryContent =
                    renderPaneTree "Secondary" secondary
            in
            pane
                |> SplitPane.assignPanes
                |> SplitPane.setPrimaryPane primaryContent
                |> SplitPane.setSecondaryPane secondaryContent
                |> SplitPane.view


updatePaneTreeGutters : Bool -> Pane -> Pane
updatePaneTreeGutters useThickGutters current =
    case current of
        Splittable _ ->
            current

        Split split ->
            let
                updatedPrimary : Pane
                updatedPrimary =
                    updatePaneTreeGutters useThickGutters split.primary

                updatedSecondary : Pane
                updatedSecondary =
                    updatePaneTreeGutters useThickGutters split.secondary

                updatedPane : SplitPane Msg
                updatedPane =
                    SplitPane.useThickGutters useThickGutters split.pane
            in
            Split { split | pane = updatedPane, primary = updatedPrimary, secondary = updatedSecondary }


splitPaneTree : SplitPane.Position -> Bool -> Int -> Int -> SplitPane.Orientation -> Pane -> ( Pane, Cmd Msg )
splitPaneTree position useThickGutters nextId target orientation parent =
    case parent of
        Split { id, pane, primary, secondary } ->
            let
                ( primaryPane, primaryCmd ) =
                    splitPaneTree position useThickGutters nextId target orientation primary

                ( secondaryPane, secondaryCmd ) =
                    splitPaneTree position useThickGutters nextId target orientation secondary
            in
            ( Split
                { pane = pane
                , id = id
                , primary = primaryPane
                , secondary = secondaryPane
                }
            , Cmd.batch [ primaryCmd, secondaryCmd ]
            )

        Splittable paneId ->
            if paneId == target then
                let
                    ( newPane, cmd ) =
                        SplitPane.init
                            orientation
                            (SplitPane.Pct 40)
                            position
                            ("pane-" ++ String.fromInt target)
                            (SplitPaneMsg target)
                            SplitPaneReady
                in
                ( Split
                    { pane = newPane |> SplitPane.useThickGutters useThickGutters
                    , id = target
                    , primary = Splittable nextId
                    , secondary = Splittable (nextId + 1)
                    }
                , cmd
                )

            else
                ( parent, Cmd.none )


updatePane : Int -> SplitPane.Msg -> Pane -> ( Pane, Cmd Msg )
updatePane target msg parent =
    case parent of
        Splittable _ ->
            ( parent, Cmd.none )

        Split split ->
            if split.id == target then
                let
                    ( updated, cmd ) =
                        SplitPane.update msg split.pane
                in
                ( Split { split | pane = updated }
                , cmd
                )

            else
                let
                    ( primaryPane, primaryCmd ) =
                        updatePane target msg split.primary

                    ( secondaryPane, secondaryCmd ) =
                        updatePane target msg split.secondary
                in
                ( Split
                    { split
                        | primary = primaryPane
                        , secondary = secondaryPane
                    }
                , Cmd.batch [ primaryCmd, secondaryCmd ]
                )
