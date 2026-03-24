module Curtissimo.SplitPane exposing
    ( init, Orientation(..), Position(..), Unit(..)
    , assignPanes, setPrimaryPane, setSecondaryPane, view
    , subscriptions, update
    , setSecondaryPaneMeasure, setSecondaryPaneVisible, useThickGutters
    , getSecondaryPaneMeasure, hasThickGutters, isReady, isSecondaryPaneVisible
    , Msg, SplitPane, SplitPaneRenderable
    )

{-| `Curtissimo.SplitPane` provides a nestable split pane for Elm.

    import Curtissimo.SplitPane as SplitPane exposing (SplitPane)
    import Html exposing (Html, text)

    type alias Model =
        { splitPane : SplitPane Msg }

    type Msg
        = SplitPaneMsg SplitPane.Msg
        | SplitPaneReady

    init : () -> ( Model, Cmd Msg )
    init _ =
        let
            ( splitPane, splitPaneCmd ) =
                SplitPane.init
                    SplitPane.VerticalOrientation
                    (SplitPane.Px 200)
                    SplitPane.After
                    "split-pane"
                    SplitPaneMsg
                    SplitPaneReady
        in
        ( { splitPane = splitPane }
        , splitPaneCmd
        )

    subscriptions : Model -> Sub Msg
    subscriptions model =
        SplitPane.subscriptions model.splitPane

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            SplitPaneMsg splitPaneMsg ->
                let
                    ( updated, updatedMsg ) =
                        model.splitPane
                            |> SplitPane.update splitPaneMsg
                in
                ( { splitPane = updated }
                , updatedMsg
                )

            SplitPaneReady ->
                ( model, Cmd.none )

    view : Model -> Browser.Document Msg
    view model =
        { title = "My Split Pane Page"
        , body =
            model.splitPane
                |> SplitPane.assignPanes
                |> SplitPane.setPrimaryPane
                    (text "Primary pane")
                |> SplitPane.setSecondaryPane
                    (text "Secondary pane")
                |> SplitPane.view
        }

**NOTE:** Don't forget to include the `subscriptions`!


## Inititalization

@docs init, Orientation, Position, Unit


## Rendering

@docs assignPanes, setPrimaryPane, setSecondaryPane, view


## Updates

@docs subscriptions, update


## Modifications

@docs setSecondaryPaneMeasure, setSecondaryPaneVisible, useThickGutters


## Getters

@docs getSecondaryPaneMeasure, hasThickGutters, isReady, isSecondaryPaneVisible


## Opaque types

@docs Msg, SplitPane, SplitPaneRenderable

-}

import Browser.Dom
import Browser.Events
import Cmd.Extra
import Html exposing (Html, div, span, text)
import Html.Attributes exposing (attribute, class, classList, style)
import Html.Events exposing (on)
import Json.Decode as Decode exposing (Decoder)
import Maybe.Extra
import Process
import Task
import Tuple.Extra



-- PUBLIC TYPES


{-| The messages the split pane uses.
-}
type Msg
    = ActivateGutter MousePosition
    | MoveGutter MousePosition
    | ReceiveContainerElement (Result Browser.Dom.Error Browser.Dom.Element)
    | ReceiveWindowResize
    | ReleaseGutter


{-| The state of the split pane.
-}
type SplitPane msg
    = SplitPane (SplitPaneConfig msg)


{-| Orientations the split pane can have.
-}
type Orientation
    = Horizontal
    | Vertical


{-| Indicator if the secondary pane is before or after the primary pane.
-}
type Position
    = Before
    | After


{-| The bridge between states and rendering.
-}
type SplitPaneRenderable msg
    = SplitPaneRenderable (SplitPaneRenderableConfig msg)


{-| The way to specify the measure of the secondary pane.
-}
type Unit
    = Pct Float
    | Px Int



-- PRIVATE TYPES


type alias ActiveGutterInfo a =
    { originalClick : MousePositionAxis
    , secondary : a
    }


type alias MousePositionAxis =
    { client : Int
    , offset : Int
    , page : Int
    , screen : Int
    }


type MousePositionButton
    = AuxiliaryButton
    | PrimaryButton
    | SecondaryButton
    | UnknownButton


type alias MousePosition =
    { button : MousePositionButton
    , horizontal : MousePositionAxis
    , vertical : MousePositionAxis
    }


type alias SplitPaneConfig msg =
    { config : SubpaneConfig msg
    , ready : Bool
    , readyAttempt : Int
    , readyMsg : msg
    , thickGutters : Bool
    }


type alias SplitPaneMeasure a =
    { active : Maybe (ActiveGutterInfo a)
    , primary : a
    , secondary : a
    }


type SplitPaneMeasures
    = PctMeasure (SplitPaneMeasure Float)
    | PxMeasure (SplitPaneMeasure Int)


type alias SplitPaneRenderableConfig msg =
    { definition : SubpaneConfig msg
    , panes : ( Maybe (Html msg), Maybe (Html msg) )
    , thickGutters : Bool
    }


type alias SubpaneConfig msg =
    { containerId : String
    , measures : SplitPaneMeasures
    , orientation : Orientation
    , secondaryPosition : Position
    , secondaryVisible : Bool
    , toMsg : Msg -> msg
    , totalCrossMeasure : Int
    , totalMeasure : Int
    }



-- PUBLIC FUNCTIONS


{-| Change `SplitPane` into `SplitPaneRenderable` to prepare it to render.
-}
assignPanes : SplitPane msg -> SplitPaneRenderable msg
assignPanes (SplitPane { config, thickGutters }) =
    SplitPaneRenderable
        { definition = config, panes = ( Nothing, Nothing ), thickGutters = thickGutters }


{-| Get the current measure of the secondary pane.
-}
getSecondaryPaneMeasure : SplitPane msg -> Int
getSecondaryPaneMeasure (SplitPane { config }) =
    case config.measures of
        PctMeasure { secondary } ->
            round secondary

        PxMeasure { secondary } ->
            secondary


hasActiveGutter : SubpaneConfig msg -> Bool
hasActiveGutter config =
    splitPaneIsActive config


{-| Initialize a new split pane.
-}
init : Orientation -> Unit -> Position -> String -> (Msg -> msg) -> msg -> ( SplitPane msg, Cmd msg )
init splitPaneOrientation splitPaneUnit splitPanePosition containerId toMsg splitPaneReadyMsg =
    let
        measures : SplitPaneMeasures
        measures =
            case splitPaneUnit of
                Pct n ->
                    PctMeasure
                        { active = Nothing
                        , primary = 100 - n
                        , secondary = n
                        }

                Px n ->
                    PxMeasure
                        { active = Nothing
                        , primary = -1
                        , secondary = n
                        }

        config : SubpaneConfig msg
        config =
            { containerId = containerId
            , measures = measures
            , orientation = splitPaneOrientation
            , secondaryPosition = splitPanePosition
            , secondaryVisible = True
            , toMsg = toMsg
            , totalCrossMeasure = -1
            , totalMeasure = -1
            }
    in
    { config = config
    , ready = False
    , readyAttempt = 0
    , readyMsg = splitPaneReadyMsg
    , thickGutters = False
    }
        |> SplitPane
        |> Tuple.Extra.pairWith
            (Task.attempt
                (ReceiveContainerElement >> toMsg)
                (Browser.Dom.getElement containerId)
            )


{-| Query the state to determine if the split pane uses thick gutters
-}
hasThickGutters : SplitPane msg -> Bool
hasThickGutters (SplitPane { thickGutters }) =
    thickGutters


{-| Query the state to determine if the split pane is ready to use.
-}
isReady : SplitPane msg -> Bool
isReady (SplitPane { ready }) =
    ready


{-| Query the state to determine if the secondary pane is visible.
-}
isSecondaryPaneVisible : SplitPane msg -> Bool
isSecondaryPaneVisible (SplitPane { config }) =
    config.secondaryVisible


{-| Set the content of the primary pane of the split pane.
-}
setPrimaryPane : Html msg -> SplitPaneRenderable msg -> SplitPaneRenderable msg
setPrimaryPane pane (SplitPaneRenderable config) =
    SplitPaneRenderable { config | panes = ( Just pane, Tuple.second config.panes ) }


{-| Set the content of the secondary pane of the split pane.
-}
setSecondaryPane : Html msg -> SplitPaneRenderable msg -> SplitPaneRenderable msg
setSecondaryPane pane (SplitPaneRenderable config) =
    SplitPaneRenderable { config | panes = ( Tuple.first config.panes, Just pane ) }


{-| Set the secondary pane to a specific measure based on how the split pane
was initialized. If the split pane was initialized as a percentage, then the
integer value is clamped to 0 and 100 inclusive.
-}
setSecondaryPaneMeasure : Int -> SplitPane msg -> SplitPane msg
setSecondaryPaneMeasure value (SplitPane { config, ready, readyAttempt, readyMsg, thickGutters }) =
    let
        measures : SplitPaneMeasures
        measures =
            case config.measures of
                PctMeasure pctMeasure ->
                    PctMeasure
                        { pctMeasure
                            | primary = 100 - toFloat value |> min 100 |> max 0
                            , secondary = toFloat value |> min 100 |> max 0
                        }

                PxMeasure pxMeasure ->
                    PxMeasure
                        { pxMeasure
                            | primary = -1
                            , secondary = value
                        }
    in
    SplitPane
        { config = { config | measures = measures }
        , ready = ready
        , readyAttempt = readyAttempt
        , readyMsg = readyMsg
        , thickGutters = thickGutters
        }


{-| Set the visibility of the secondary pane.

When set to `False`, the secondary pane and the resize gutter are not visible.

-}
setSecondaryPaneVisible : Bool -> SplitPane msg -> SplitPane msg
setSecondaryPaneVisible value (SplitPane { config, ready, readyAttempt, readyMsg, thickGutters }) =
    SplitPane
        { config = { config | secondaryVisible = value }
        , ready = ready
        , readyAttempt = readyAttempt
        , readyMsg = readyMsg
        , thickGutters = thickGutters
        }


{-| The subscriptions used to monitor mouse movements when a split pane resize
is active, as well as window resizing.
-}
subscriptions : SplitPane msg -> Sub msg
subscriptions (SplitPane { config }) =
    let
        mouseUpEvent : Sub msg
        mouseUpEvent =
            if hasActiveGutter config then
                Browser.Events.onMouseUp
                    (ReleaseGutter
                        |> config.toMsg
                        |> Decode.succeed
                    )

            else
                Sub.none

        mouseMoveEvent : Sub msg
        mouseMoveEvent =
            if hasActiveGutter config then
                Browser.Events.onMouseMove
                    (mousePositionDecoder
                        |> Decode.map MoveGutter
                        |> Decode.map config.toMsg
                    )

            else
                Sub.none
    in
    Sub.batch
        [ Browser.Events.onResize (\_ _ -> ReceiveWindowResize) |> Sub.map config.toMsg
        , mouseMoveEvent
        , mouseUpEvent
        ]


{-| Update the state of the split pane.
-}
update : Msg -> SplitPane msg -> ( SplitPane msg, Cmd msg )
update msg ((SplitPane { config, ready, readyAttempt, readyMsg, thickGutters }) as model) =
    case msg of
        ActivateGutter mousePosition ->
            if mousePosition.button /= PrimaryButton then
                ( model, Cmd.none )

            else
                let
                    active : MousePositionAxis
                    active =
                        case config.orientation of
                            Horizontal ->
                                mousePosition.vertical

                            Vertical ->
                                mousePosition.horizontal

                    measures : SplitPaneMeasures
                    measures =
                        case config.measures of
                            PctMeasure pctMeasure ->
                                PctMeasure { pctMeasure | active = Just { originalClick = active, secondary = pctMeasure.secondary } }

                            PxMeasure pxMesaure ->
                                PxMeasure { pxMesaure | active = Just { originalClick = active, secondary = pxMesaure.secondary } }
                in
                ( SplitPane
                    { config = { config | measures = measures }
                    , ready = ready
                    , readyAttempt = readyAttempt
                    , readyMsg = readyMsg
                    , thickGutters = thickGutters
                    }
                , Cmd.none
                )

        MoveGutter mousePosition ->
            let
                current : MousePositionAxis
                current =
                    case config.orientation of
                        Horizontal ->
                            mousePosition.vertical

                        Vertical ->
                            mousePosition.horizontal

                measures : SplitPaneMeasures
                measures =
                    case config.measures of
                        PctMeasure pctMeasure ->
                            case ( pctMeasure.active, config.secondaryPosition ) of
                                ( Nothing, _ ) ->
                                    config.measures

                                ( Just active, After ) ->
                                    let
                                        secondary : Float
                                        secondary =
                                            active.secondary
                                                - (toFloat (current.client - active.originalClick.client + active.originalClick.offset) * 100 / toFloat config.totalMeasure)
                                                |> max 0
                                                |> min 100
                                    in
                                    PctMeasure { pctMeasure | secondary = secondary }

                                ( Just active, Before ) ->
                                    let
                                        secondary : Float
                                        secondary =
                                            active.secondary
                                                + (toFloat (current.client - active.originalClick.client + active.originalClick.offset) * 100 / toFloat config.totalMeasure)
                                                |> max 0
                                                |> min 100
                                    in
                                    PctMeasure { pctMeasure | secondary = secondary }

                        PxMeasure pxMeasure ->
                            case ( pxMeasure.active, config.secondaryPosition ) of
                                ( Nothing, _ ) ->
                                    config.measures

                                ( Just active, After ) ->
                                    let
                                        secondary : Int
                                        secondary =
                                            active.secondary
                                                - (current.client - active.originalClick.client + active.originalClick.offset)
                                                |> max 0
                                                |> min config.totalMeasure
                                    in
                                    PxMeasure { pxMeasure | secondary = secondary }

                                ( Just active, Before ) ->
                                    let
                                        secondary : Int
                                        secondary =
                                            active.secondary
                                                + (current.client - active.originalClick.client + active.originalClick.offset)
                                                |> max 0
                                                |> min config.totalMeasure
                                    in
                                    PxMeasure { pxMeasure | secondary = secondary }
            in
            ( SplitPane
                { config = { config | measures = measures }
                , ready = ready
                , readyAttempt = readyAttempt
                , readyMsg = readyMsg
                , thickGutters = thickGutters
                }
            , Cmd.none
            )

        ReceiveContainerElement (Err _) ->
            let
                cmd : Cmd msg
                cmd =
                    if readyAttempt < 10 then
                        Process.sleep 10
                            |> Task.andThen (\() -> Browser.Dom.getElement config.containerId)
                            |> Task.attempt (ReceiveContainerElement >> config.toMsg)

                    else
                        Cmd.none
            in
            ( SplitPane
                { config = config
                , ready = ready
                , readyAttempt = readyAttempt + 1
                , readyMsg = readyMsg
                , thickGutters = thickGutters
                }
            , cmd
            )

        ReceiveContainerElement (Ok result) ->
            let
                height : Int
                height =
                    floor result.element.height

                width : Int
                width =
                    floor result.element.width

                ( totalMeasure, totalCrossMeasure ) =
                    case config.orientation of
                        Horizontal ->
                            ( height, width )

                        Vertical ->
                            ( width, height )

                cmd : Cmd msg
                cmd =
                    if not ready then
                        Cmd.Extra.fromMaybe identity (Just readyMsg)

                    else
                        Cmd.none
            in
            ( SplitPane
                { config = { config | totalCrossMeasure = totalCrossMeasure, totalMeasure = totalMeasure }
                , ready = True
                , readyAttempt = readyAttempt
                , readyMsg = readyMsg
                , thickGutters = thickGutters
                }
            , cmd
            )

        ReceiveWindowResize ->
            ( model
            , Task.attempt
                (ReceiveContainerElement >> config.toMsg)
                (Browser.Dom.getElement config.containerId)
            )

        ReleaseGutter ->
            let
                measures : SplitPaneMeasures
                measures =
                    case config.measures of
                        PctMeasure pctMeasure ->
                            PctMeasure { pctMeasure | active = Nothing }

                        PxMeasure pxMeasure ->
                            PxMeasure { pxMeasure | active = Nothing }
            in
            ( SplitPane
                { config = { config | measures = measures }
                , ready = ready
                , readyAttempt = readyAttempt
                , readyMsg = readyMsg
                , thickGutters = thickGutters
                }
            , Cmd.none
            )


{-| Changes the layout of the resize gutter to be thin or thick based
on the flag provided.
-}
useThickGutters : Bool -> SplitPane msg -> SplitPane msg
useThickGutters value (SplitPane config) =
    SplitPane { config | thickGutters = value }


{-| Render the split pane.
-}
view : SplitPaneRenderable msg -> Html msg
view (SplitPaneRenderable { definition, panes, thickGutters }) =
    let
        measure : Int
        measure =
            case definition.measures of
                PctMeasure { secondary } ->
                    definition.totalMeasure - round secondary

                PxMeasure { secondary } ->
                    definition.totalMeasure - secondary

        splitPanePrimaryWidthClasses : String
        splitPanePrimaryWidthClasses =
            List.range 1 (measure // 100)
                |> List.map (\n -> n * 100)
                |> List.map (\n -> "curtissimo-split-pane-measure-" ++ String.fromInt n)
                |> String.join " "

        primaryPane : Html msg
        primaryPane =
            div
                [ class "curtissimo-split-pane-primary", class splitPanePrimaryWidthClasses ]
                [ Tuple.first panes |> Maybe.withDefault (text "") ]
    in
    if definition.secondaryVisible then
        let
            splitPaneClasses : Html.Attribute msg
            splitPaneClasses =
                classList
                    [ ( "curtissimo-split-pane-horizontal", definition.orientation == Horizontal )
                    , ( "curtissimo-split-pane-vertical", definition.orientation == Vertical )
                    , ( "curtissimo-split-pane-active", splitPaneIsActive definition )
                    , ( "curtissimo-split-pane-secondary-after", definition.secondaryPosition == After )
                    , ( "curtissimo-split-pane-secondary-before", definition.secondaryPosition == Before )
                    ]

            gutterClass : String
            gutterClass =
                if thickGutters then
                    "curtissimo-split-pane-gutter curtissimo-split-pane-gutter-thick"

                else
                    "curtissimo-split-pane-gutter curtissimo-split-pane-gutter-thin"

            secondaryMeasureStyle : String -> Html.Attribute msg
            secondaryMeasureStyle =
                case definition.orientation of
                    Horizontal ->
                        style "height"

                    Vertical ->
                        style "width"

            secondaryMeasure : Html.Attribute msg
            secondaryMeasure =
                case definition.measures of
                    PctMeasure { secondary } ->
                        secondaryMeasureStyle (String.fromFloat secondary ++ "%")

                    PxMeasure { secondary } ->
                        secondaryMeasureStyle (String.fromInt secondary ++ "px")

            splitPaneSecondaryMeasure : Int
            splitPaneSecondaryMeasure =
                case definition.measures of
                    PctMeasure { secondary } ->
                        round secondary

                    PxMeasure { secondary } ->
                        secondary

            splitPaneSecondaryWidthClasses : String
            splitPaneSecondaryWidthClasses =
                List.range 1 (splitPaneSecondaryMeasure // 100)
                    |> List.map (\n -> n * 100)
                    |> List.map (\n -> "curtissimo-split-pane-measure-" ++ String.fromInt n)
                    |> String.join " "
        in
        div
            [ class "curtissimo-split-pane curtissimo-split-pane-secondary-visible"
            , splitPaneClasses
            , attribute "id" definition.containerId
            ]
            [ primaryPane
            , div [ class gutterClass, on "mousedown" (mousePositionDecoder |> Decode.map ActivateGutter |> Decode.map definition.toMsg) ]
                [ span [ class "curtissimo-split-pane-gutter-handle" ] []
                , span [ class "curtissimo-split-pane-gutter-handle" ] []
                , span [ class "curtissimo-split-pane-gutter-handle" ] []
                ]
            , div
                [ class "curtissimo-split-pane-secondary"
                , class splitPaneSecondaryWidthClasses
                , secondaryMeasure
                ]
                [ Tuple.second panes |> Maybe.withDefault (text "") ]
            ]

    else
        div
            [ class "curtissimo-split-pane curtissimo-split-pane-secondary-hidden"
            , attribute "data-id" definition.containerId
            ]
            [ primaryPane ]



-- PRIVATE FUNCTIONS


mousePositionAxisDecoder : String -> Decoder MousePositionAxis
mousePositionAxisDecoder suffix =
    Decode.map4 MousePositionAxis
        (Decode.field ("client" ++ suffix) Decode.int)
        (Decode.field ("offset" ++ suffix) Decode.int)
        (Decode.field ("page" ++ suffix) Decode.int)
        (Decode.field ("screen" ++ suffix) Decode.int)


mousePositionButtonDecoder : Decoder MousePositionButton
mousePositionButtonDecoder =
    Decode.field "button" Decode.int
        |> Decode.map
            (\value ->
                case value of
                    0 ->
                        PrimaryButton

                    1 ->
                        AuxiliaryButton

                    2 ->
                        SecondaryButton

                    _ ->
                        UnknownButton
            )


mousePositionDecoder : Decoder MousePosition
mousePositionDecoder =
    Decode.map3 MousePosition
        mousePositionButtonDecoder
        (mousePositionAxisDecoder "X")
        (mousePositionAxisDecoder "Y")


splitPaneIsActive : SubpaneConfig msg -> Bool
splitPaneIsActive config =
    case config.measures of
        PctMeasure { active } ->
            Maybe.Extra.isJust active

        PxMeasure { active } ->
            Maybe.Extra.isJust active
