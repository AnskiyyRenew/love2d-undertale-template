local rules = {}

rules.CHANNEL_COUNT = 4
rules.DEFAULT_NOISE_SIZE = 256
rules.AUDIO_IMAGE_WIDTH = 512
rules.AUDIO_IMAGE_HEIGHT = 2

rules.EXTERNS_TEMPLATE = [[
extern number iTime;
extern number iTimeDelta;
extern number iFrame;

extern vec3 iResolution;
extern vec4 iMouse;

extern Image iChannel0;
extern Image iChannel1;
extern Image iChannel2;
extern Image iChannel3;

extern vec3 iChannelResolution[4];
]]

rules.UNIFORM_RULES = {
    { token = "iTime",               extern = "extern number iTime;",                                                        flag = "iTime" },
    { token = "iResolution",         extern = "extern vec3 iResolution;",                                                    flag = "iResolution" },
    { token = "iMouse",              extern = "extern vec4 iMouse;",                                                         flag = "iMouse" },
    { token = "iFrame",              extern = "extern int iFrame;",                                                          flag = "iFrame" },
    {
        token = "iChannelResolution",
        extern = "extern vec3 iChannelResolution0;\nextern vec3 iChannelResolution1;\nextern vec3 iChannelResolution2;\nextern vec3 iChannelResolution3;",
        flag = "iChannelResolution",
    },
}

rules.CHANNEL_RULES = {}
for i = 0, rules.CHANNEL_COUNT - 1 do
    table.insert(rules.CHANNEL_RULES, { id = i, name = "iChannel" .. i })
end

rules.REPLACEMENT_RULES = {
    { pattern = "iChannelResolution%[(%d)%]", replacement = "iChannelResolution%1" },
    { pattern = "fragColor%s*=",              replacement = "return " },
    { pattern = "texture%s*%(",               replacement = "Texel(" },
    { pattern = "gl_FragCoord",               replacement = "screen_coords" },
    { pattern = "precision%s+%w+%s+float%s*;", replacement = "" },
}

return rules
