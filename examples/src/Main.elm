module Main exposing (Model, Msg, main)


import Browser
import Html exposing (Html)
import Curtissimo.SplitPane exposing (SplitPane)


type alias Model =
    { splitPane : SplitPane
    }


type Msg
    = SplitPaneMsg Curtissimo.SplitPane.Msg


main : Program () Model Msg
main =
  Browser.element
    { init = init 
    , subscriptions = subscriptions
    , update = update 
    , view = view 
    }


init : () -> (Model, Cmd Msg)
init _ =
    let
        (created, createdCmd) =
            Curtissimo.SplitPane.init
    in 
    ( { splitPane = created }
    , createdCmd |> Cmd.map SplitPaneMsg
    )


subscriptions : Model -> Sub Msg 
subscriptions model =
    Curtissimo.SplitPane.subscriptions model.splitPane
        |> Sub.map SplitPaneMsg


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SplitPaneMsg splitPaneMsg ->
            let
                (updated, updatedMsg) =
                    model.splitPane
                        |> Curtissimo.SplitPane.update splitPaneMsg 
            in 
            ( { model | splitPane = updated }
            , updatedMsg |> Cmd.map SplitPaneMsg
            )



view : Model -> Html Msg 
view model =
    Curtissimo.SplitPane.view model.splitPane
        |> Html.map SplitPaneMsg
