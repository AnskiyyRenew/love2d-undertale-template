-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

shadertoy = require("Scripts.Libraries.ShaderToy")
local raincode = shadertoy.convert([[
float random(in float x) 
{
    return fract(sin(x)*1e4);
}

float random(in vec2 st) 
{
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

mat2 rotate2D(float angle)
{
    return mat2(cos(angle), -sin(angle), 
                sin(angle), cos(angle));
}

float flower(vec2 uv, vec2 center, float r, int petals, float smoothR)
{
    vec2 v = uv - center;
    float d = length(v);
    float theta = atan(v.y, v.x);   
    float curve = abs(sin(theta * float(petals))) * (r * 0.85);
    return 1.0 - smoothstep(r - curve - smoothR, r - curve, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    const vec2 TILES = vec2(400.0, 300.0);
    const float PI = 3.141592653589793;
    float RATIO = iResolution.x / iResolution.y;
    vec2 TILES_RATIO = TILES * vec2(RATIO, 1.0);
    
    vec2 st = fragCoord.xy / iResolution.xy;   
    st *= TILES;
    st.x *= RATIO;
    
    vec2 ipos = floor(st);
 
    color = vec4(0.0, 0.0, 1.0, 0.9);
    
    vec2 vel = vec2(0.0, iTime * (0.08 + random(ipos.x)) * 100.0);    
    vec2 anim = floor(st + vel);
    color.b = random(anim) - random(ipos.x);
    
    vec2 rot = st - (TILES_RATIO * 0.5);
    rot = rotate2D(sin(iTime * 0.2) * PI) * rot;
    rot += (TILES_RATIO * 0.5);
    float f1 = flower(rot, TILES_RATIO * 0.5, TILES_RATIO.x * 0.9, 4, 100.0);
    
    rot = st - (TILES_RATIO * 0.5);
    rot = rotate2D(sin(iTime * 0.2 + 32.14) * -PI) * rot;
    rot += (TILES_RATIO * 0.5);
    float f2 = flower(rot, TILES_RATIO * 0.5, TILES_RATIO.x * 0.9, 2, 100.0);

    color.b += 0.3 * f1;
    color.b -= 0.35 * f2;
    color.r = step(0.96, color.g);
    color.g = step(0.9, color.g);
    
    float sm = 0.4;
    vec4 result = mix(vec4(0.0), color, smoothstep(0.0, sm, fract(st.x)));
    result = mix(result, vec4(0.0), smoothstep(1.0 - sm, 1.0, fract(st.x)));
    
    fragColor = result;
}
]])
raincode:printCode("final")
local rain = raincode.shader
rain:send("iResolution", {love.graphics.getWidth(), love.graphics.getHeight(), 0})

local bg = sprites.CreateSprite("px.png", 0)
bg:Scale(640, 480)
--bg.alpha = 0
bg.color = {1, 0, 0}
bg:SetShaders({rain})

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.
    rain:send("iTime", love.timer.getTime())
end

-- This function is called to draw the scene.
-- It is called after the main game loop has finished updating.
function SCENE.draw()
    -- Draw the scene here.
    -- For example, you might draw images, text, etc.
end

-- This function is called when the scene is switched away from.
function SCENE.clear()
    -- Clear any resources used by this scene here.
    -- For example, you might unload images, sounds, etc.
    layers.clear()
end

-- Don't touch this(just one line).
return SCENE