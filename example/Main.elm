module Main exposing (..)

import Html exposing (Html, div, button, text)
import Html.Events exposing (onClick)
import Html.App as App
import Http.EventSource as EventSource


type alias Model =
    { events : List String
    , shortEnabled : Bool
    , longEnabled : Bool
    }


type Msg
    = ReceiveEvent String
    | ToggleShort
    | ToggleLong


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    Debug.log "update"
        <| case msg of
            ReceiveEvent data ->
                ( { model | events = data :: model.events }
                , Cmd.none
                )

            ToggleShort ->
                ( { model | shortEnabled = not model.shortEnabled }
                , Cmd.none
                )

            ToggleLong ->
                ( { model | longEnabled = not model.longEnabled }
                , Cmd.none
                )


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ button [ onClick ToggleShort ]
                [ text
                    <| if model.shortEnabled then
                        "Click to turn off short-timeout event"
                       else
                        "Click to turn on short-timeout event"
                ]
            , button [ onClick ToggleLong ]
                [ text
                    <| if model.longEnabled then
                        "Click to turn off long-timeout event"
                       else
                        "Click to turn on long-timeout event"
                ]
            ]
        , div [] (List.map (\data -> div [] [ text data ]) model.events)
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        short =
            if model.shortEnabled then
                EventSource.listen "/events" "short-timeout" ReceiveEvent
            else
                Sub.none

        long =
            if model.longEnabled then
                EventSource.listen "/events" "long-timeout" ReceiveEvent
            else
                Sub.none
    in
        Sub.batch
            [ short
            , long
            ]


main : Program Never
main =
    App.program
        { init = ( { events = [], shortEnabled = True, longEnabled = True }, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
