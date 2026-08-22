local scene = {}

local shadertoy = ImportFile("ShaderToy")
local s = shadertoy.convert([[
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    // Time varying pixel color
    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));

    // Output to screen
    fragColor = vec4(col,1.0);
}
]])

local bg = Sprites.CreateSprite("px.png", 0)
bg:Scale(640, 480)
bg:SetShaders({s.shader})

function scene.update(dt)
    s:update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene