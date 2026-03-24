# Curtissimo.SplitPane

[![Pipeline](https://gitlab.example.com/curtissimo/elm-split-pane/badges/main/pipeline.svg?ignore_skipped=true)](https://gitlab.com/curtissimo/elm-split-pane/-/pipelines/latest)

A nestable split pane for Elm.

Check out the [live example](https://curtissimo.gitlab.io/elm-split-pane).
Source for the examples can be found in the [`./examples`](https://gitlab.com/curtissimo/elm-split-pane/-/tree/main/examples)
directory.

## Design Goals

So, I needed a nestable split pane for an app I was building with the
following features:

- Sets the fewest style attributes possible in the DOM
- Provides CSS classes on child panes to indicate width
- Can handle absolute and relative measures
- Can handle nested split panes
- Can show and hide the secondary panes
- Can properly handle overflow
- Customizable via CSS

Turns out, that's a lot to ask of some split panes. There's a nice
version with
[whale9490/elm-split-pane](https://package.elm-lang.org/packages/whale9490/elm-split-pane/latest/),
but it unfortunately didn't meet the needs of what I wanted for the first,
second, and last items.

## Usage

The split pane relies on the size of the container that it's put in. So, either
set a fixed height/width on the container, or do some Grid Layout stuff (which
is what I do).

The following table shows the CSS variables available for customization with
their default values.

| Name                                                |  Default  |
| --------------------------------------------------- | :-------: |
| `--curtissimo-split-pane-gutter-width`              |   `8px`   |
| `--curtissimo-split-pane-gutter-border-color`       | `#aaaaaa` |
| `--curtissimo-split-pane-gutter-handle-color`       |  `black`  |
| `--curtissimo-split-pane-gutter-hover-color`        | `#f5c264` |
| `--curtissimo-split-pane-gutter-hover-handle-color` | `#333333` |

### NPM Package

This package relies on external styles.

Install the package from NPM using the following command.

```sh
npm install --save-dev @curtissimo/elm-split-pane
```

Then, as part of your build process, include the external
styles. To include the CSS, use the following import adapted to your
build's needs.

```css
@import url(@curtissimo/elm-split-pane/main.css);
```
