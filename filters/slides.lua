-- Keep the same content readable on the smaller Beamer canvas.
-- RevealJS uses its original image widths and CSS source-note typography.
local beamer = FORMAT == "beamer"

function Image(image)
  if beamer then
    image.attributes.width = "80%"
    image.attributes.height = nil
  end
  return image
end

function Div(div)
  if beamer and div.classes:includes("source") then
    local blocks = pandoc.List({pandoc.RawBlock("latex", "\\begingroup\\scriptsize")})
    blocks:extend(div.content)
    blocks:insert(pandoc.RawBlock("latex", "\\par\\endgroup"))
    return blocks
  end
  return div
end
