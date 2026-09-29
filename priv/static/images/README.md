# App icon assets

`app-icon.svg` is the source of truth. Everything else in this directory
is a raster export of it, generated for the environments that don't take
SVG:

| File                      | Size    | Used as                                       |
| ------------------------- | ------- | --------------------------------------------- |
| `app-icon.svg`            | vector  | `rel="icon"` (modern browsers) + PWA manifest |
| `apple-touch-icon.png`    | 180×180 | iOS home screen (`rel="apple-touch-icon"`)    |
| `icon-192.png`            | 192×192 | PWA manifest (Android home screen)            |
| `icon-512.png`            | 512×512 | PWA manifest splash, install prompt           |
| `favicon-32.png`          |  32×32  | `rel="icon"` (older browsers)                 |
| `favicon-16.png`          |  16×16  | `rel="icon"` (older browsers)                 |
| `../favicon.ico`          | multi   | Legacy Windows favicon                        |

## Regenerating after editing `app-icon.svg`

Requires `rsvg-convert` (from `librsvg`) and ImageMagick (`magick`).
Both are on Homebrew: `brew install librsvg imagemagick`.

```bash
cd priv/static/images

rsvg-convert -w 180 -h 180 app-icon.svg -o apple-touch-icon.png
rsvg-convert -w 192 -h 192 app-icon.svg -o icon-192.png
rsvg-convert -w 512 -h 512 app-icon.svg -o icon-512.png
rsvg-convert -w  32 -h  32 app-icon.svg -o favicon-32.png
rsvg-convert -w  16 -h  16 app-icon.svg -o favicon-16.png

magick icon-192.png -define icon:auto-resize=16,32,48,64 ../favicon.ico
```

The colors in `app-icon.svg` are hex mirrors of the tokens in
`assets/css/app.css` (`ink`, `tint`, `accent`). When the theme moves,
update the SVG's hex values in one commit with the token move.
