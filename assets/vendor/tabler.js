const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function({matchComponents, theme}) {
  let iconsDir = path.join(__dirname, "../../deps/tabler_icons/icons")
  let values = {}
  let icons = [
    ["", "/outline"],
    ["-filled", "/filled"]
  ]
  icons.forEach(([suffix, dir]) => {
    fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
      let name = path.basename(file, ".svg") + suffix
      values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
    })
  })
  matchComponents({
    "tabler": ({name, fullPath}) => {
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      content = encodeURIComponent(content)
      let size = theme("spacing.6")
      return {
        [`--tabler-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--tabler-${name})`,
        "mask": `var(--tabler-${name})`,
        "mask-repeat": "no-repeat",
        "mask-position": "center",
        "mask-size": "contain",
        "-webkit-mask-repeat": "no-repeat",
        "-webkit-mask-position": "center",
        "-webkit-mask-size": "contain",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": size,
        "height": size
      }
    }
  }, {values})
})
