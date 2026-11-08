-- Visual check for the ShaderToy host-channel rewrite.
-- px.png is a white 1x1 texture: when iChannel0 reads the host texture,
-- src.r is 1 everywhere and the screen renders solid red.
local scene = {}

local shadertoy = ImportFile("ShaderToy")

local code = [[
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(iChannel0, uv);
    fragColor = vec4(src.r, 0.0, 0.0, 1.0);
}
]]

local s = shadertoy.convert(code, { hostChannel = 0 })

local bg = Sprites.CreateSprite("px.png", 0)
bg:Scale(640, 480)
bg:SetShaders({s.shader})

function scene.update(dt)
    s:update(dt)
end

function scene.draw() end

function scene.clear()
    Layers.clear()
end

return scene
