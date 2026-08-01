-- 自动生成 by love-api (https://github.com/love2d-community/love-api)
-- LOVE2D version: 11.5
local se = {}

-- top
se._top = {
    getVersion = false,
    hasDeprecationOutput = false,
    isVersionCompatible = false,
    setDeprecationOutput = false,
}

-- love.audio
se.audio = {
    getActiveEffects = false,
    getActiveSourceCount = false,
    getDistanceModel = false,
    getDopplerScale = false,
    getEffect = false,
    getMaxSceneEffects = false,
    getMaxSourceEffects = false,
    getOrientation = false,
    getPosition = false,
    getRecordingDevices = false,
    getVelocity = false,
    getVolume = false,
    isEffectsSupported = false,
    newQueueableSource = false,
    newSource = false,
    pause = false,
    play = false,
    setDistanceModel = false,
    setDopplerScale = false,
    setEffect = false,
    setMixWithSystem = false,
    setOrientation = false,
    setPosition = false,
    setVelocity = false,
    setVolume = false,
    stop = false,
}

--[[ se.audio 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  RecordingDevice: getBitDepth, getChannelCount, getData, getName, getSampleCount, getSampleRate, isRecording, start, stop
  Source: clone, getActiveEffects, getAirAbsorption, getAttenuationDistances, getChannelCount, getCone, getDirection, getDuration, getEffect, getFilter, getFreeBufferCount, getPitch, getPosition, getRolloff, getType, getVelocity, getVolume, getVolumeLimits, isLooping, isPlaying, isRelative, pause, play, queue, seek, setAirAbsorption, setAttenuationDistances, setCone, setDirection, setEffect, setFilter, setLooping, setPitch, setPosition, setRelative, setRolloff, setVelocity, setVolume, setVolumeLimits, stop, tell
]]

-- love.data
se.data = {
    compress = false,
    decode = false,
    decompress = false,
    encode = false,
    getPackedSize = false,
    hash = false,
    newByteData = false,
    newDataView = false,
    pack = false,
    unpack = false,
}

--[[ se.data 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  ByteData: 
  CompressedData: getFormat
]]

-- love.event
se.event = {
    clear = false,
    poll = false,
    pump = false,
    push = false,
    quit = false,
    wait = false,
}

-- love.filesystem
se.filesystem = {
    append = false,
    areSymlinksEnabled = false,
    createDirectory = false,
    getAppdataDirectory = false,
    getCRequirePath = false,
    getDirectoryItems = false,
    getIdentity = false,
    getInfo = false,
    getRealDirectory = false,
    getRequirePath = false,
    getSaveDirectory = false,
    getSource = false,
    getSourceBaseDirectory = false,
    getUserDirectory = false,
    getWorkingDirectory = false,
    init = false,
    isFused = false,
    lines = false,
    load = false,
    mount = false,
    newFile = false,
    newFileData = false,
    read = false,
    remove = false,
    setCRequirePath = false,
    setIdentity = false,
    setRequirePath = false,
    setSource = false,
    setSymlinksEnabled = false,
    unmount = false,
    write = false,
}

--[[ se.filesystem 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  DroppedFile: 
  File: close, flush, getBuffer, getFilename, getMode, getSize, isEOF, isOpen, lines, open, read, seek, setBuffer, tell, write
  FileData: getExtension, getFilename
]]

-- love.font
se.font = {
    newBMFontRasterizer = false,
    newGlyphData = false,
    newImageRasterizer = false,
    newRasterizer = false,
    newTrueTypeRasterizer = false,
}

--[[ se.font 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  GlyphData: getAdvance, getBearing, getBoundingBox, getDimensions, getFormat, getGlyph, getGlyphString, getHeight, getWidth
  Rasterizer: getAdvance, getAscent, getDescent, getGlyphCount, getGlyphData, getHeight, getLineHeight, hasGlyphs
]]

-- love.graphics
se.graphics = {
    applyTransform = false,
    arc = false,
    captureScreenshot = false,
    circle = false,
    clear = false,
    discard = false,
    draw = false,
    drawInstanced = false,
    drawLayer = false,
    ellipse = false,
    flushBatch = false,
    getBackgroundColor = false,
    getBlendMode = false,
    getCanvas = false,
    getCanvasFormats = false,
    getColor = false,
    getColorMask = false,
    getDPIScale = false,
    getDefaultFilter = false,
    getDepthMode = false,
    getDimensions = false,
    getFont = false,
    getFrontFaceWinding = false,
    getHeight = false,
    getImageFormats = false,
    getLineJoin = false,
    getLineStyle = false,
    getLineWidth = false,
    getMeshCullMode = false,
    getPixelDimensions = false,
    getPixelHeight = false,
    getPixelWidth = false,
    getPointSize = false,
    getRendererInfo = false,
    getScissor = false,
    getShader = false,
    getStackDepth = false,
    getStats = false,
    getStencilTest = false,
    getSupported = false,
    getSystemLimits = false,
    getTextureTypes = false,
    getWidth = false,
    intersectScissor = false,
    inverseTransformPoint = false,
    isActive = false,
    isGammaCorrect = false,
    isWireframe = false,
    line = false,
    newArrayImage = false,
    newCanvas = false,
    newCubeImage = false,
    newFont = false,
    newImage = false,
    newImageFont = false,
    newMesh = false,
    newParticleSystem = false,
    newQuad = false,
    newShader = false,
    newSpriteBatch = false,
    newText = false,
    newVideo = false,
    newVolumeImage = false,
    origin = false,
    points = false,
    polygon = false,
    pop = false,
    present = false,
    print = false,
    printf = false,
    push = false,
    rectangle = false,
    replaceTransform = false,
    reset = false,
    rotate = false,
    scale = false,
    setBackgroundColor = false,
    setBlendMode = false,
    setCanvas = false,
    setColor = false,
    setColorMask = false,
    setDefaultFilter = false,
    setDepthMode = false,
    setFont = false,
    setFrontFaceWinding = false,
    setLineJoin = false,
    setLineStyle = false,
    setLineWidth = false,
    setMeshCullMode = false,
    setNewFont = false,
    setPointSize = false,
    setScissor = false,
    setShader = false,
    setStencilState = false,
    setStencilTest = false,
    setWireframe = false,
    shear = false,
    stencil = false,
    transformPoint = false,
    translate = false,
    validateShader = false,
}

--[[ se.graphics 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Canvas: generateMipmaps, getMSAA, getMipmapMode, newImageData, renderTo
  Drawable: 
  Font: getAscent, getBaseline, getDPIScale, getDescent, getFilter, getHeight, getKerning, getLineHeight, getWidth, getWrap, hasGlyphs, setFallbacks, setFilter, setLineHeight
  Image: isCompressed, isFormatLinear, replacePixels
  Mesh: attachAttribute, detachAttribute, flush, getDrawMode, getDrawRange, getTexture, getVertex, getVertexAttribute, getVertexCount, getVertexFormat, getVertexMap, isAttributeEnabled, setAttributeEnabled, setDrawMode, setDrawRange, setTexture, setVertex, setVertexAttribute, setVertexMap, setVertices
  ParticleSystem: clone, emit, getBufferSize, getColors, getCount, getDirection, getEmissionArea, getEmissionRate, getEmitterLifetime, getInsertMode, getLinearAcceleration, getLinearDamping, getOffset, getParticleLifetime, getPosition, getQuads, getRadialAcceleration, getRotation, getSizeVariation, getSizes, getSpeed, getSpin, getSpinVariation, getSpread, getTangentialAcceleration, getTexture, hasRelativeRotation, isActive, isPaused, isStopped, moveTo, pause, reset, setBufferSize, setColors, setDirection, setEmissionArea, setEmissionRate, setEmitterLifetime, setInsertMode, setLinearAcceleration, setLinearDamping, setOffset, setParticleLifetime, setPosition, setQuads, setRadialAcceleration, setRelativeRotation, setRotation, setSizeVariation, setSizes, setSpeed, setSpin, setSpinVariation, setSpread, setTangentialAcceleration, setTexture, start, stop, update
  Quad: getTextureDimensions, getViewport, setViewport
  Shader: getWarnings, hasUniform, send, sendColor
  SpriteBatch: add, addLayer, attachAttribute, clear, flush, getBufferSize, getColor, getCount, getTexture, set, setColor, setDrawRange, setLayer, setTexture
  Text: add, addf, clear, getDimensions, getFont, getHeight, getWidth, set, setFont, setf
  Texture: getDPIScale, getDepth, getDepthSampleMode, getDimensions, getFilter, getFormat, getHeight, getLayerCount, getMipmapCount, getMipmapFilter, getPixelDimensions, getPixelHeight, getPixelWidth, getTextureType, getWidth, getWrap, isReadable, setDepthSampleMode, setFilter, setMipmapFilter, setWrap
  Video: getDimensions, getFilter, getHeight, getSource, getStream, getWidth, isPlaying, pause, play, rewind, seek, setFilter, setSource, tell
]]

-- love.image
se.image = {
    isCompressed = false,
    newCompressedData = false,
    newImageData = false,
}

--[[ se.image 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  CompressedImageData: getDimensions, getFormat, getHeight, getMipmapCount, getWidth
  ImageData: encode, getDimensions, getHeight, getPixel, getWidth, mapPixel, paste, setPixel, getFormat
]]

-- love.joystick
se.joystick = {
    getGamepadMappingString = false,
    getJoystickCount = false,
    getJoysticks = false,
    loadGamepadMappings = false,
    saveGamepadMappings = false,
    setGamepadMapping = false,
}

--[[ se.joystick 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Joystick: getAxes, getAxis, getAxisCount, getButtonCount, getDeviceInfo, getGUID, getGamepadAxis, getGamepadMapping, getGamepadMappingString, getHat, getHatCount, getID, getName, getVibration, isConnected, isDown, isGamepad, isGamepadDown, isVibrationSupported, setVibration
]]

-- love.keyboard
se.keyboard = {
    getKeyFromScancode = false,
    getScancodeFromKey = false,
    hasKeyRepeat = false,
    hasScreenKeyboard = false,
    hasTextInput = false,
    isDown = false,
    isScancodeDown = false,
    setKeyRepeat = false,
    setTextInput = false,
}

-- love.math
se.math = {
    colorFromBytes = false,
    colorToBytes = false,
    gammaToLinear = false,
    getRandomSeed = false,
    getRandomState = false,
    isConvex = false,
    linearToGamma = false,
    newBezierCurve = false,
    newRandomGenerator = false,
    newTransform = false,
    noise = false,
    random = false,
    randomNormal = false,
    setRandomSeed = false,
    setRandomState = false,
    triangulate = false,
}

--[[ se.math 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  BezierCurve: evaluate, getControlPoint, getControlPointCount, getDegree, getDerivative, getSegment, insertControlPoint, removeControlPoint, render, renderSegment, rotate, scale, setControlPoint, translate
  RandomGenerator: getSeed, getState, random, randomNormal, setSeed, setState
  Transform: apply, clone, getMatrix, inverse, inverseTransformPoint, isAffine2DTransform, reset, rotate, scale, setMatrix, setTransformation, shear, transformPoint, translate
]]

-- love.mouse
se.mouse = {
    getCursor = false,
    getPosition = false,
    getRelativeMode = false,
    getSystemCursor = false,
    getX = false,
    getY = false,
    isCursorSupported = false,
    isDown = false,
    isGrabbed = false,
    isVisible = false,
    newCursor = false,
    setCursor = false,
    setGrabbed = false,
    setPosition = false,
    setRelativeMode = false,
    setVisible = false,
    setX = false,
    setY = false,
}

--[[ se.mouse 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Cursor: getType
]]

-- love.physics
se.physics = {
    getDistance = false,
    getMeter = false,
    newBody = false,
    newChainShape = false,
    newCircleShape = false,
    newDistanceJoint = false,
    newEdgeShape = false,
    newFixture = false,
    newFrictionJoint = false,
    newGearJoint = false,
    newMotorJoint = false,
    newMouseJoint = false,
    newPolygonShape = false,
    newPrismaticJoint = false,
    newPulleyJoint = false,
    newRectangleShape = false,
    newRevoluteJoint = false,
    newRopeJoint = false,
    newWeldJoint = false,
    newWheelJoint = false,
    newWorld = false,
    setMeter = false,
}

--[[ se.physics 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Body: applyAngularImpulse, applyForce, applyLinearImpulse, applyTorque, destroy, getAngle, getAngularDamping, getAngularVelocity, getContacts, getFixtures, getGravityScale, getInertia, getJoints, getLinearDamping, getLinearVelocity, getLinearVelocityFromLocalPoint, getLinearVelocityFromWorldPoint, getLocalCenter, getLocalPoint, getLocalPoints, getLocalVector, getMass, getMassData, getPosition, getTransform, getType, getUserData, getWorld, getWorldCenter, getWorldPoint, getWorldPoints, getWorldVector, getX, getY, isActive, isAwake, isBullet, isDestroyed, isFixedRotation, isSleepingAllowed, isTouching, resetMassData, setActive, setAngle, setAngularDamping, setAngularVelocity, setAwake, setBullet, setFixedRotation, setGravityScale, setInertia, setLinearDamping, setLinearVelocity, setMass, setMassData, setPosition, setSleepingAllowed, setTransform, setType, setUserData, setX, setY
  ChainShape: getChildEdge, getNextVertex, getPoint, getPoints, getPreviousVertex, getVertexCount, setNextVertex, setPreviousVertex
  CircleShape: getPoint, getRadius, setPoint, setRadius
  Contact: getChildren, getFixtures, getFriction, getNormal, getPositions, getRestitution, isEnabled, isTouching, resetFriction, resetRestitution, setEnabled, setFriction, setRestitution
  DistanceJoint: getDampingRatio, getFrequency, getLength, setDampingRatio, setFrequency, setLength
  EdgeShape: getNextVertex, getPoints, getPreviousVertex, setNextVertex, setPreviousVertex
  Fixture: destroy, getBody, getBoundingBox, getCategory, getDensity, getFilterData, getFriction, getGroupIndex, getMask, getMassData, getRestitution, getShape, getUserData, isDestroyed, isSensor, rayCast, setCategory, setDensity, setFilterData, setFriction, setGroupIndex, setMask, setRestitution, setSensor, setUserData, testPoint
  FrictionJoint: getMaxForce, getMaxTorque, setMaxForce, setMaxTorque
  GearJoint: getJoints, getRatio, setRatio
  Joint: destroy, getAnchors, getBodies, getCollideConnected, getReactionForce, getReactionTorque, getType, getUserData, isDestroyed, setUserData
  MotorJoint: getAngularOffset, getLinearOffset, setAngularOffset, setLinearOffset
  MouseJoint: getDampingRatio, getFrequency, getMaxForce, getTarget, setDampingRatio, setFrequency, setMaxForce, setTarget
  PolygonShape: getPoints
  PrismaticJoint: areLimitsEnabled, getAxis, getJointSpeed, getJointTranslation, getLimits, getLowerLimit, getMaxMotorForce, getMotorForce, getMotorSpeed, getReferenceAngle, getUpperLimit, isMotorEnabled, setLimits, setLimitsEnabled, setLowerLimit, setMaxMotorForce, setMotorEnabled, setMotorSpeed, setUpperLimit
  PulleyJoint: getConstant, getGroundAnchors, getLengthA, getLengthB, getMaxLengths, getRatio, setConstant, setMaxLengths, setRatio
  RevoluteJoint: areLimitsEnabled, getJointAngle, getJointSpeed, getLimits, getLowerLimit, getMaxMotorTorque, getMotorSpeed, getMotorTorque, getReferenceAngle, getUpperLimit, hasLimitsEnabled, isMotorEnabled, setLimits, setLimitsEnabled, setLowerLimit, setMaxMotorTorque, setMotorEnabled, setMotorSpeed, setUpperLimit
  RopeJoint: getMaxLength, setMaxLength
  Shape: computeAABB, computeMass, getChildCount, getRadius, getType, rayCast, testPoint
  WeldJoint: getDampingRatio, getFrequency, getReferenceAngle, setDampingRatio, setFrequency
  WheelJoint: getAxis, getJointSpeed, getJointTranslation, getMaxMotorTorque, getMotorSpeed, getMotorTorque, getSpringDampingRatio, getSpringFrequency, isMotorEnabled, setMaxMotorTorque, setMotorEnabled, setMotorSpeed, setSpringDampingRatio, setSpringFrequency
  World: destroy, getBodies, getBodyCount, getCallbacks, getContactCount, getContactFilter, getContacts, getGravity, getJointCount, getJoints, isDestroyed, isLocked, isSleepingAllowed, queryBoundingBox, rayCast, setCallbacks, setContactFilter, setGravity, setSleepingAllowed, translateOrigin, update
]]

-- love.sound
se.sound = {
    newDecoder = false,
    newSoundData = false,
}

--[[ se.sound 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Decoder: clone, decode, getBitDepth, getChannelCount, getDuration, getSampleRate, seek
  SoundData: getBitDepth, getChannelCount, getDuration, getSample, getSampleCount, getSampleRate, setSample
]]

-- love.system
se.system = {
    getClipboardText = false,
    getOS = false,
    getPowerInfo = false,
    getProcessorCount = false,
    hasBackgroundMusic = false,
    openURL = false,
    setClipboardText = false,
    vibrate = false,
}

-- love.thread
se.thread = {
    getChannel = false,
    newChannel = false,
    newThread = false,
}

--[[ se.thread 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  Channel: clear, demand, getCount, hasRead, peek, performAtomic, pop, push, supply
  Thread: getError, isRunning, start, wait
]]

-- love.timer
se.timer = {
    getAverageDelta = false,
    getDelta = false,
    getFPS = false,
    getTime = false,
    sleep = false,
    step = false,
}

-- love.touch
se.touch = {
    getPosition = false,
    getPressure = false,
    getTouches = false,
}

-- love.video
se.video = {
    newVideoStream = false,
}

--[[ se.video 下相关对象类型的方法 (仅供参考,未注入到 se 表中):
  VideoStream: getFilename, isPlaying, pause, play, rewind, seek, tell
]]

-- love.window
se.window = {
    close = false,
    fromPixels = false,
    getDPIScale = false,
    getDesktopDimensions = false,
    getDisplayCount = false,
    getDisplayName = false,
    getDisplayOrientation = false,
    getFullscreen = false,
    getFullscreenModes = false,
    getIcon = false,
    getMode = false,
    getPosition = false,
    getSafeArea = false,
    getTitle = false,
    getVSync = false,
    hasFocus = false,
    hasMouseFocus = false,
    isDisplaySleepEnabled = false,
    isMaximized = false,
    isMinimized = false,
    isOpen = false,
    isVisible = false,
    maximize = false,
    minimize = false,
    requestAttention = false,
    restore = false,
    setDisplaySleepEnabled = false,
    setFullscreen = false,
    setIcon = false,
    setMode = false,
    setPosition = false,
    setTitle = false,
    setVSync = false,
    showMessageBox = false,
    toPixels = false,
    updateMode = false,
}


local proxy_mt = {
    __index = function(t, key)
        if type(love[key]) == "table" then
            -- 为这个模块创建代理表
            local module_proxy = setmetatable({}, {
                __index = function(_, func_name)
                    return function(...)
                        return love[key][func_name](...)
                    end
                end
            })
            rawset(t, key, module_proxy)
            return module_proxy
        end

        if type(love[key]) == "function" then
            return function(...)
                return love[key](...)
            end
        end

        return nil
    end
}

setmetatable(se, proxy_mt)

return se