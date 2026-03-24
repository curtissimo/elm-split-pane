# Curtissimo.SplitPane Checklist

Go through the **Initial setup**. When you want to publish, go through the
**Before publishing** and **Publishing** steps.

## Initial setup

- [ ] Create an empty **GitLab** repo `curtissimo/elm-split-pane`
- [ ] Set up the GitHub mirror
  - Go to GitHub and create a repository for `curtissimo/elm-split-pane`
  - Get personal token with repository push privileges
  - Go to your GitLab repo and set up mirroring to the GitHub repo
- [ ] Initialize the local Git repository (`git init`)
- [ ] Set the `origin` remote
  - If you like using ssh, `npm run git:set-remote`
  - If you like using HTTP, `npm run git:set-remote:http`
- [ ] Publish an alpha version of the package to NPM using `npm publish --tag next --access public`
- [ ] Create a "Trusted Publisher" connection to the package from GitLab on the
  [Setings page](https://www.npmjs.com/package/@curtissimo/elm-split-pane/access)
  of your package using "production" as the environment value.

## Developing

You do you with your development process.

If you'd like, you can run `npm start` which will start up the main
[`./examples/src/index.html`](./examples/src/index.html) in a hot-reload
server. That way, you can get real-time feedback while building your
example.

## Before publishing

- [ ] Write documentation and preview it using `npm run docs`
- [ ] Make sure the correct modules are exposed in [`elm.json`](./elm.json)
- [ ] Run `npm run lint:format` to make sure code passes **elm-format**
- [ ] Run `npm run lint:review` to make sure code passes **elm-review**
- [ ] Run `npm run test:docs` to make sure code examples pass

## Publishing 

- [ ] Bump the version in [`elm.json`](./elm.json)
- [ ] Bump the version in [`package.json`](./package.json) to match the Elm version
- [ ] Add and commit those changes
- [ ] Create a Git tag for the new version and push it
