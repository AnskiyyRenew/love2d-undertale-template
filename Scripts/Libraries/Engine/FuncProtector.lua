local se = {
    physics = {
        setMeter = function(...)
            return love.physics.setMeter(...)
        end,
        newWorld = function(...)
            return love.physics.newWorld(...)
        end,
        newBody = function(...)
            return love.physics.newBody(...)
        end,
        newFixture = function(...)
            return love.physics.newFixture(...)
        end,
        newCircleShape = function(...)
            return love.physics.newCircleShape(...)
        end,
        newRectangleShape = function(...)
            return love.physics.newRectangleShape(...)
        end,
        newPolygonShape = function(...)
            return love.physics.newPolygonShape(...)
        end,
        newEdgeShape = function(...)
            return love.physics.newEdgeShape(...)
        end,
        newChainShape = function(...)
            return love.physics.newChainShape(...)
        end,
        newDistanceJoint = function(...)
            return love.physics.newDistanceJoint(...)
        end,
        newMouseJoint = function(...)
            return love.physics.newMouseJoint(...)
        end,
        newRevoluteJoint = function(...)
            return love.physics.newRevoluteJoint(...)
        end,
        newPrismaticJoint = function(...)
            return love.physics.newPrismaticJoint(...)
        end,
        newPulleyJoint = function(...)
            return love.physics.newPulleyJoint(...)
        end,
        newGearJoint = function(...)
            return love.physics.newGearJoint(...)
        end,
        newFrictionJoint = function(...)
            return love.physics.newFrictionJoint(...)
        end,
        newWeldJoint = function(...)
            return love.physics.newWeldJoint(...)
        end,
        newWheelJoint = function(...)
            return love.physics.newWheelJoint(...)
        end,
        newRopeJoint = function(...)
            return love.physics.newRopeJoint(...)
        end,
        newMotorJoint = function(...)
            return love.physics.newMotorJoint(...)
        end,
        getDistance = function(...)
            return love.physics.getDistance(...)
        end,
        getMeter = function(...)
            return love.physics.getMeter(...)
        end,
    },
    data = {
        newDataView = function(...)
            return love.data.newDataView(...)
        end,
        newByteData = function(...)
            return love.data.newByteData(...)
        end,
        compress = function(...)
            return love.data.compress(...)
        end,
        decompress = function(...)
            return love.data.decompress(...)
        end,
        encode = function(...)
            return love.data.encode(...)
        end,
        decode = function(...)
            return love.data.decode(...)
        end,
        hash = function(...)
            return love.data.hash(...)
        end,
        pack = function(...)
            return love.data.pack(...)
        end,
        getPackedSize = function(...)
            return love.data.getPackedSize(...)
        end,
        unpack = function(...)
            return love.data.unpack(...)
        end,
    },
    system = {
        hasBackgroundMusic = function(...)
            return love.system.hasBackgroundMusic(...)
        end,
        getOS = function(...)
            return love.system.getOS(...)
        end,
        getProcessorCount = function(...)
            return love.system.getProcessorCount(...)
        end,
        setClipboardText = function(...)
            return love.system.setClipboardText(...)
        end,
        getClipboardText = function(...)
            return love.system.getClipboardText(...)
        end,
        getPowerInfo = function(...)
            return love.system.getPowerInfo(...)
        end,
        openURL = function(...)
            return love.system.openURL(...)
        end,
        vibrate = function(...)
            return love.system.vibrate(...)
        end,
    },
    font = {
        newRasterizer = function(...)
            return love.font.newRasterizer(...)
        end,
        newTrueTypeRasterizer = function(...)
            return love.font.newTrueTypeRasterizer(...)
        end,
        newBMFontRasterizer = function(...)
            return love.font.newBMFontRasterizer(...)
        end,
        newImageRasterizer = function(...)
            return love.font.newImageRasterizer(...)
        end,
        newGlyphData = function(...)
            return love.font.newGlyphData(...)
        end,
    },
    video = {
        newVideoStream = function(...)
            return love.video.newVideoStream(...)
        end,
    },
    _top = {
        hasDeprecationOutput = function(...)
            return love._top.hasDeprecationOutput(...)
        end,
        getVersion = function(...)
            return love._top.getVersion(...)
        end,
        isVersionCompatible = function(...)
            return love._top.isVersionCompatible(...)
        end,
        setDeprecationOutput = function(...)
            return love._top.setDeprecationOutput(...)
        end,
    },
    math = {
        randomNormal = function(...)
            return love.math.randomNormal(...)
        end,
        getRandomState = function(...)
            return love.math.getRandomState(...)
        end,
        colorToBytes = function(...)
            return love.math.colorToBytes(...)
        end,
        colorFromBytes = function(...)
            return love.math.colorFromBytes(...)
        end,
        newRandomGenerator = function(...)
            return love.math.newRandomGenerator(...)
        end,
        newBezierCurve = function(...)
            return love.math.newBezierCurve(...)
        end,
        newTransform = function(...)
            return love.math.newTransform(...)
        end,
        triangulate = function(...)
            return love.math.triangulate(...)
        end,
        isConvex = function(...)
            return love.math.isConvex(...)
        end,
        gammaToLinear = function(...)
            return love.math.gammaToLinear(...)
        end,
        linearToGamma = function(...)
            return love.math.linearToGamma(...)
        end,
        noise = function(...)
            return love.math.noise(...)
        end,
        random = function(...)
            return love.math.random(...)
        end,
        setRandomSeed = function(...)
            return love.math.setRandomSeed(...)
        end,
        getRandomSeed = function(...)
            return love.math.getRandomSeed(...)
        end,
        setRandomState = function(...)
            return love.math.setRandomState(...)
        end,
    },
    graphics = {
        newVideo = function(...)
            return love.graphics.newVideo(...)
        end,
        newImageFont = function(...)
            return love.graphics.newImageFont(...)
        end,
        newSpriteBatch = function(...)
            return love.graphics.newSpriteBatch(...)
        end,
        newParticleSystem = function(...)
            return love.graphics.newParticleSystem(...)
        end,
        newShader = function(...)
            return love.graphics.newShader(...)
        end,
        newMesh = function(...)
            return love.graphics.newMesh(...)
        end,
        validateShader = function(...)
            return love.graphics.validateShader(...)
        end,
        setCanvas = function(...)
            return love.graphics.setCanvas(...)
        end,
        getCanvas = function(...)
            return love.graphics.getCanvas(...)
        end,
        getColor = function(...)
            return love.graphics.getColor(...)
        end,
        setBackgroundColor = function(...)
            return love.graphics.setBackgroundColor(...)
        end,
        setNewFont = function(...)
            return love.graphics.setNewFont(...)
        end,
        getFont = function(...)
            return love.graphics.getFont(...)
        end,
        scale = function(...)
            return love.graphics.scale(...)
        end,
        getColorMask = function(...)
            return love.graphics.getColorMask(...)
        end,
        setBlendMode = function(...)
            return love.graphics.setBlendMode(...)
        end,
        getBlendMode = function(...)
            return love.graphics.getBlendMode(...)
        end,
        getStencilTest = function(...)
            return love.graphics.getStencilTest(...)
        end,
        getDefaultFilter = function(...)
            return love.graphics.getDefaultFilter(...)
        end,
        setLineWidth = function(...)
            return love.graphics.setLineWidth(...)
        end,
        setLineStyle = function(...)
            return love.graphics.setLineStyle(...)
        end,
        setLineJoin = function(...)
            return love.graphics.setLineJoin(...)
        end,
        getLineWidth = function(...)
            return love.graphics.getLineWidth(...)
        end,
        newImage = function(...)
            return love.graphics.newImage(...)
        end,
        getLineJoin = function(...)
            return love.graphics.getLineJoin(...)
        end,
        setPointSize = function(...)
            return love.graphics.setPointSize(...)
        end,
        getPointSize = function(...)
            return love.graphics.getPointSize(...)
        end,
        getDepthMode = function(...)
            return love.graphics.getDepthMode(...)
        end,
        setMeshCullMode = function(...)
            return love.graphics.setMeshCullMode(...)
        end,
        getMeshCullMode = function(...)
            return love.graphics.getMeshCullMode(...)
        end,
        setFrontFaceWinding = function(...)
            return love.graphics.setFrontFaceWinding(...)
        end,
        getFrontFaceWinding = function(...)
            return love.graphics.getFrontFaceWinding(...)
        end,
        setWireframe = function(...)
            return love.graphics.setWireframe(...)
        end,
        isWireframe = function(...)
            return love.graphics.isWireframe(...)
        end,
        setShader = function(...)
            return love.graphics.setShader(...)
        end,
        getShader = function(...)
            return love.graphics.getShader(...)
        end,
        getSupported = function(...)
            return love.graphics.getSupported(...)
        end,
        getSystemLimits = function(...)
            return love.graphics.getSystemLimits(...)
        end,
        getTextureTypes = function(...)
            return love.graphics.getTextureTypes(...)
        end,
        getStats = function(...)
            return love.graphics.getStats(...)
        end,
        captureScreenshot = function(...)
            return love.graphics.captureScreenshot(...)
        end,
        drawLayer = function(...)
            return love.graphics.drawLayer(...)
        end,
        drawInstanced = function(...)
            return love.graphics.drawInstanced(...)
        end,
        isActive = function(...)
            return love.graphics.isActive(...)
        end,
        origin = function(...)
            return love.graphics.origin(...)
        end,
        clear = function(...)
            return love.graphics.clear(...)
        end,
        getBackgroundColor = function(...)
            return love.graphics.getBackgroundColor(...)
        end,
        draw = function(...)
            return love.graphics.draw(...)
        end,
        getPixelWidth = function(...)
            return love.graphics.getPixelWidth(...)
        end,
        getPixelHeight = function(...)
            return love.graphics.getPixelHeight(...)
        end,
        getPixelDimensions = function(...)
            return love.graphics.getPixelDimensions(...)
        end,
        setScissor = function(...)
            return love.graphics.setScissor(...)
        end,
        intersectScissor = function(...)
            return love.graphics.intersectScissor(...)
        end,
        getScissor = function(...)
            return love.graphics.getScissor(...)
        end,
        stencil = function(...)
            return love.graphics.stencil(...)
        end,
        points = function(...)
            return love.graphics.points(...)
        end,
        rectangle = function(...)
            return love.graphics.rectangle(...)
        end,
        circle = function(...)
            return love.graphics.circle(...)
        end,
        ellipse = function(...)
            return love.graphics.ellipse(...)
        end,
        arc = function(...)
            return love.graphics.arc(...)
        end,
        polygon = function(...)
            return love.graphics.polygon(...)
        end,
        flushBatch = function(...)
            return love.graphics.flushBatch(...)
        end,
        getStackDepth = function(...)
            return love.graphics.getStackDepth(...)
        end,
        rotate = function(...)
            return love.graphics.rotate(...)
        end,
        translate = function(...)
            return love.graphics.translate(...)
        end,
        shear = function(...)
            return love.graphics.shear(...)
        end,
        applyTransform = function(...)
            return love.graphics.applyTransform(...)
        end,
        replaceTransform = function(...)
            return love.graphics.replaceTransform(...)
        end,
        transformPoint = function(...)
            return love.graphics.transformPoint(...)
        end,
        inverseTransformPoint = function(...)
            return love.graphics.inverseTransformPoint(...)
        end,
        newArrayImage = function(...)
            return love.graphics.newArrayImage(...)
        end,
        newVolumeImage = function(...)
            return love.graphics.newVolumeImage(...)
        end,
        newCubeImage = function(...)
            return love.graphics.newCubeImage(...)
        end,
        newText = function(...)
            return love.graphics.newTextBatch(...)
        end,
        getCanvasFormats = function(...)
            return love.graphics.getCanvasFormats(...)
        end,
        getImageFormats = function(...)
            return love.graphics.getImageFormats(...)
        end,
        setStencilState = function(...)
            return love.graphics.setStencilState(...)
        end,
        setStencilTest = function(...)
            return love.graphics.setStencilTest(...)
        end,
        setFont = function(...)
            return love.graphics.setFont(...)
        end,
        setDepthMode = function(...)
            return love.graphics.setDepthMode(...)
        end,
        setDefaultFilter = function(...)
            return love.graphics.setDefaultFilter(...)
        end,
        setColorMask = function(...)
            return love.graphics.setColorMask(...)
        end,
        setColor = function(...)
            return love.graphics.setColor(...)
        end,
        reset = function(...)
            return love.graphics.reset(...)
        end,
        push = function(...)
            return love.graphics.push(...)
        end,
        printf = function(...)
            return love.graphics.printf(...)
        end,
        present = function(...)
            return love.graphics.present(...)
        end,
        print = function(...)
            return love.graphics.print(...)
        end,
        pop = function(...)
            return love.graphics.pop(...)
        end,
        getLineStyle = function(...)
            return love.graphics.getLineStyle(...)
        end,
        isGammaCorrect = function(...)
            return love.graphics.isGammaCorrect(...)
        end,
        getDPIScale = function(...)
            return love.graphics.getDPIScale(...)
        end,
        getHeight = function(...)
            return love.graphics.getHeight(...)
        end,
        getDimensions = function(...)
            return love.graphics.getDimensions(...)
        end,
        getRendererInfo = function(...)
            return love.graphics.getRendererInfo(...)
        end,
        getWidth = function(...)
            return love.graphics.getWidth(...)
        end,
        line = function(...)
            return love.graphics.line(...)
        end,
        discard = function(...)
            return love.graphics.discard(...)
        end,
        newCanvas = function(...)
            return love.graphics.newCanvas(...)
        end,
        newFont = function(...)
            return love.graphics.newFont(...)
        end,
        newQuad = function(...)
            return love.graphics.newQuad(...)
        end,
    },
    thread = {
        newThread = function(...)
            return love.thread.newThread(...)
        end,
        newChannel = function(...)
            return love.thread.newChannel(...)
        end,
        getChannel = function(...)
            return love.thread.getChannel(...)
        end,
    },
    window = {
        close = function(...)
            return love.window.close(...)
        end,
        showMessageBox = function(...)
            return love.window.showMessageBox(...)
        end,
        setIcon = function(...)
            return love.window.setIcon(...)
        end,
        setTitle = function(...)
            return love.window.setTitle(...)
        end,
        setMode = function(...)
            return love.window.setMode(...)
        end,
        getMode = function(...)
            return love.window.getMode(...)
        end,
        setVSync = function(...)
            return love.window.setVSync(...)
        end,
        isVisible = function(...)
            return love.window.isVisible(...)
        end,
        getDisplayCount = function(...)
            return love.window.getDisplayCount(...)
        end,
        getDisplayName = function(...)
            return love.window.getDisplayName(...)
        end,
        updateMode = function(...)
            return love.window.updateMode(...)
        end,
        getPosition = function(...)
            return love.window.getPosition(...)
        end,
        getDisplayOrientation = function(...)
            return love.window.getDisplayOrientation(...)
        end,
        getFullscreenModes = function(...)
            return love.window.getFullscreenModes(...)
        end,
        setFullscreen = function(...)
            return love.window.setFullscreen(...)
        end,
        getFullscreen = function(...)
            return love.window.getFullscreen(...)
        end,
        setPosition = function(...)
            return love.window.setPosition(...)
        end,
        getSafeArea = function(...)
            return love.window.getSafeArea(...)
        end,
        getIcon = function(...)
            return love.window.getIcon(...)
        end,
        getTitle = function(...)
            return love.window.getTitle(...)
        end,
        getVSync = function(...)
            return love.window.getVSync(...)
        end,
        setDisplaySleepEnabled = function(...)
            return love.window.setDisplaySleepEnabled(...)
        end,
        isDisplaySleepEnabled = function(...)
            return love.window.isDisplaySleepEnabled(...)
        end,
        hasFocus = function(...)
            return love.window.hasFocus(...)
        end,
        hasMouseFocus = function(...)
            return love.window.hasMouseFocus(...)
        end,
        isMaximized = function(...)
            return love.window.isMaximized(...)
        end,
        getDPIScale = function(...)
            return love.window.getDPIScale(...)
        end,
        isMinimized = function(...)
            return love.window.isMinimized(...)
        end,
        toPixels = function(...)
            return love.window.toPixels(...)
        end,
        requestAttention = function(...)
            return love.window.requestAttention(...)
        end,
        minimize = function(...)
            return love.window.minimize(...)
        end,
        maximize = function(...)
            return love.window.maximize(...)
        end,
        restore = function(...)
            return love.window.restore(...)
        end,
        fromPixels = function(...)
            return love.window.fromPixels(...)
        end,
        getDesktopDimensions = function(...)
            return love.window.getDesktopDimensions(...)
        end,
        isOpen = function(...)
            return love.window.isOpen(...)
        end,
    },
    filesystem = {
        unmount = function(...)
            return love.filesystem.unmount(...)
        end,
        setSource = function(...)
            return love.filesystem.setSource(...)
        end,
        setRequirePath = function(...)
            return love.filesystem.setRequirePath(...)
        end,
        read = function(...)
            return love.filesystem.read(...)
        end,
        write = function(...)
            return love.filesystem.write(...)
        end,
        getWorkingDirectory = function(...)
            return love.filesystem.getWorkingDirectory(...)
        end,
        getUserDirectory = function(...)
            return love.filesystem.getUserDirectory(...)
        end,
        getAppdataDirectory = function(...)
            return love.filesystem.getAppdataDirectory(...)
        end,
        getSaveDirectory = function(...)
            return love.filesystem.getSaveDirectory(...)
        end,
        getSourceBaseDirectory = function(...)
            return love.filesystem.getSourceBaseDirectory(...)
        end,
        createDirectory = function(...)
            return love.filesystem.createDirectory(...)
        end,
        getInfo = function(...)
            return love.filesystem.getInfo(...)
        end,
        getDirectoryItems = function(...)
            return love.filesystem.getDirectoryItems(...)
        end,
        init = function(...)
            return love.filesystem.init(...)
        end,
        setSymlinksEnabled = function(...)
            return love.filesystem.setSymlinksEnabled(...)
        end,
        areSymlinksEnabled = function(...)
            return love.filesystem.areSymlinksEnabled(...)
        end,
        newFileData = function(...)
            return love.filesystem.newFileData(...)
        end,
        getRequirePath = function(...)
            return love.filesystem.getRequirePath(...)
        end,
        getIdentity = function(...)
            return love.filesystem.getIdentity(...)
        end,
        getCRequirePath = function(...)
            return love.filesystem.getCRequirePath(...)
        end,
        setCRequirePath = function(...)
            return love.filesystem.setCRequirePath(...)
        end,
        newFile = function(...)
            return love.filesystem.newFile(...)
        end,
        setIdentity = function(...)
            return love.filesystem.setIdentity(...)
        end,
        remove = function(...)
            return love.filesystem.remove(...)
        end,
        isFused = function(...)
            return love.filesystem.isFused(...)
        end,
        load = function(...)
            return love.filesystem.load(...)
        end,
        lines = function(...)
            return love.filesystem.lines(...)
        end,
        getSource = function(...)
            return love.filesystem.getSource(...)
        end,
        mount = function(...)
            return love.filesystem.mount(...)
        end,
        append = function(...)
            return love.filesystem.append(...)
        end,
        getRealDirectory = function(...)
            return love.filesystem.getRealDirectory(...)
        end,
    },
    sound = {
        newDecoder = function(...)
            return love.sound.newDecoder(...)
        end,
        newSoundData = function(...)
            return love.sound.newSoundData(...)
        end,
    },
    event = {
        quit = function(...)
            return love.event.quit(...)
        end,
        clear = function(...)
            return love.event.clear(...)
        end,
        pump = function(...)
            return love.event.pump(...)
        end,
        push = function(...)
            return love.event.push(...)
        end,
        wait = function(...)
            return love.event.wait(...)
        end,
        poll = function(...)
            return love.event.poll(...)
        end,
    },
    keyboard = {
        setKeyRepeat = function(...)
            return love.keyboard.setKeyRepeat(...)
        end,
        hasKeyRepeat = function(...)
            return love.keyboard.hasKeyRepeat(...)
        end,
        setTextInput = function(...)
            return love.keyboard.setTextInput(...)
        end,
        hasTextInput = function(...)
            return love.keyboard.hasTextInput(...)
        end,
        hasScreenKeyboard = function(...)
            return love.keyboard.hasScreenKeyboard(...)
        end,
        isScancodeDown = function(...)
            return love.keyboard.isScancodeDown(...)
        end,
        getScancodeFromKey = function(...)
            return love.keyboard.getScancodeFromKey(...)
        end,
        getKeyFromScancode = function(...)
            return love.keyboard.getKeyFromScancode(...)
        end,
        isDown = function(...)
            return love.keyboard.isDown(...)
        end,
    },
    mouse = {
        newCursor = function(...)
            return love.mouse.newCursor(...)
        end,
        getSystemCursor = function(...)
            return love.mouse.getSystemCursor(...)
        end,
        getCursor = function(...)
            return love.mouse.getCursor(...)
        end,
        getX = function(...)
            return love.mouse.getX(...)
        end,
        getY = function(...)
            return love.mouse.getY(...)
        end,
        setX = function(...)
            return love.mouse.setX(...)
        end,
        setY = function(...)
            return love.mouse.setY(...)
        end,
        setVisible = function(...)
            return love.mouse.setVisible(...)
        end,
        setGrabbed = function(...)
            return love.mouse.setGrabbed(...)
        end,
        setRelativeMode = function(...)
            return love.mouse.setRelativeMode(...)
        end,
        getPosition = function(...)
            return love.mouse.getPosition(...)
        end,
        isGrabbed = function(...)
            return love.mouse.isGrabbed(...)
        end,
        getRelativeMode = function(...)
            return love.mouse.getRelativeMode(...)
        end,
        isCursorSupported = function(...)
            return love.mouse.isCursorSupported(...)
        end,
        isVisible = function(...)
            return love.mouse.isVisible(...)
        end,
        isDown = function(...)
            return love.mouse.isDown(...)
        end,
        setCursor = function(...)
            return love.mouse.setCursor(...)
        end,
        setPosition = function(...)
            return love.mouse.setPosition(...)
        end,
    },
    timer = {
        step = function(...)
            return love.timer.step(...)
        end,
        sleep = function(...)
            return love.timer.sleep(...)
        end,
        getDelta = function(...)
            return love.timer.getDelta(...)
        end,
        getFPS = function(...)
            return love.timer.getFPS(...)
        end,
        getAverageDelta = function(...)
            return love.timer.getAverageDelta(...)
        end,
        getTime = function(...)
            return love.timer.getTime(...)
        end,
    },
    joystick = {
        getJoystickCount = function(...)
            return love.joystick.getJoystickCount(...)
        end,
        getJoysticks = function(...)
            return love.joystick.getJoysticks(...)
        end,
        setGamepadMapping = function(...)
            return love.joystick.setGamepadMapping(...)
        end,
        loadGamepadMappings = function(...)
            return love.joystick.loadGamepadMappings(...)
        end,
        saveGamepadMappings = function(...)
            return love.joystick.saveGamepadMappings(...)
        end,
        getGamepadMappingString = function(...)
            return love.joystick.getGamepadMappingString(...)
        end,
    },
    touch = {
        getTouches = function(...)
            return love.touch.getTouches(...)
        end,
        getPressure = function(...)
            return love.touch.getPressure(...)
        end,
        getPosition = function(...)
            return love.touch.getPosition(...)
        end,
    },
    image = {
        newCompressedData = function(...)
            return love.image.newCompressedData(...)
        end,
        isCompressed = function(...)
            return love.image.isCompressed(...)
        end,
        newImageData = function(...)
            return love.image.newImageData(...)
        end,
    },
    audio = {
        stop = function(...)
            return love.audio.stop(...)
        end,
        getActiveSourceCount = function(...)
            return love.audio.getActiveSourceCount(...)
        end,
        setVelocity = function(...)
            return love.audio.setVelocity(...)
        end,
        isEffectsSupported = function(...)
            return love.audio.isEffectsSupported(...)
        end,
        getMaxSceneEffects = function(...)
            return love.audio.getMaxSceneEffects(...)
        end,
        getActiveEffects = function(...)
            return love.audio.getActiveEffects(...)
        end,
        setPosition = function(...)
            return love.audio.setPosition(...)
        end,
        play = function(...)
            return love.audio.play(...)
        end,
        getOrientation = function(...)
            return love.audio.getOrientation(...)
        end,
        getPosition = function(...)
            return love.audio.getPosition(...)
        end,
        getVelocity = function(...)
            return love.audio.getVelocity(...)
        end,
        setDopplerScale = function(...)
            return love.audio.setDopplerScale(...)
        end,
        getDopplerScale = function(...)
            return love.audio.getDopplerScale(...)
        end,
        setDistanceModel = function(...)
            return love.audio.setDistanceModel(...)
        end,
        getDistanceModel = function(...)
            return love.audio.getDistanceModel(...)
        end,
        getRecordingDevices = function(...)
            return love.audio.getRecordingDevices(...)
        end,
        setEffect = function(...)
            return love.audio.setEffect(...)
        end,
        getEffect = function(...)
            return love.audio.getEffect(...)
        end,
        newSource = function(...)
            return love.audio.newSource(...)
        end,
        newQueueableSource = function(...)
            return love.audio.newQueueableSource(...)
        end,
        getMaxSourceEffects = function(...)
            return love.audio.getMaxSourceEffects(...)
        end,
        pause = function(...)
            return love.audio.pause(...)
        end,
        setVolume = function(...)
            return love.audio.setVolume(...)
        end,
        getVolume = function(...)
            return love.audio.getVolume(...)
        end,
        setOrientation = function(...)
            return love.audio.setOrientation(...)
        end,
        setMixWithSystem = function(...)
            return love.audio.setMixWithSystem(...)
        end,
    },
}

se.draw_ = {}
function se.draw_.colorText(r, g, b, a, ...)
    se.graphics.setColor(r, g, b, a)
    se.graphics.print(...)
    se.graphics.setColor(1, 1, 1, 1)
end

se.tools = {}
function se.tools.hexColor(hexcode)
    if type(hexcode) ~= "string" then
        return nil
    end

    local value = hexcode:gsub("#", "")
    if #value == 3 then
        value = value:gsub("(.)", "%1%1")
    elseif #value ~= 6 then
        return nil
    end

    local r = tonumber(value:sub(1, 2), 16) or 0
    local g = tonumber(value:sub(3, 4), 16) or 0
    local b = tonumber(value:sub(5, 6), 16) or 0

    return { r / 255, g / 255, b / 255 }
end

se.preload = {}

local PRELOAD_GAME_ROOT = "Game/Resources/"

local PRELOAD_EXTS = {
    png = "image", jpg = "image", jpeg = "image", bmp = "image",
    tga = "image", hdr = "image", dds = "image",
    wav = "sound", ogg = "sound", mp3 = "sound", flac = "sound",
    aiff = "sound", it = "sound", xm = "sound", mod = "sound", s3m = "sound",
    ttf = "font", ttc = "font", otf = "font", fnt = "font",
}

local PRELOAD_TYPE_KIND = {
    Sprites = "image",
    Sounds = "sound",
    Music = "music",
    Fonts = "font",
}

--- Walk a love.filesystem directory recursively and collect every file path.
--- Order does not matter (each file is independent) and getDirectoryItems
--- ordering is not guaranteed anyway. Missing / unreadable dirs return empty.
---@param dir string love-fs directory to walk.
---@return table files List of full love-fs file paths.
local function collectPreloadFiles(dir)
    local files = {}
    local stack = { dir }
    while #stack > 0 do
        local current = table.remove(stack)
        local ok, items = pcall(function()
            return SE.filesystem.getDirectoryItems(current)
        end)
        if (ok and items) then
            for _, name in ipairs(items) do
                local sep = (current:sub(-1) == "/") and "" or "/"
                local full = current .. sep .. name
                local info = SE.filesystem.getInfo(full)
                if (info) then
                    if (info.type == "directory" or info.type == "symlink") then
                        table.insert(stack, full)
                    elseif (info.type == "file") then
                        table.insert(files, full)
                    end
                end
            end
        end
    end
    return files
end

--- Route one file to the matching engine cache. The folder kind wins when it
--- agrees with the extension; when they disagree the extension is trusted (a
--- .wav sitting inside Sprites/ is still a sound). Files with no known
--- extension (README, .md, .txt, ...) are silently skipped.
---@param full_path string Full love-fs file path.
---@param kind string|nil "image" | "sound" | "music" | "font" hint from the folder.
local function preloadOneFile(full_path, kind)
    local ext = full_path:match("%.([%w]+)$")
    local ext_kind = ext and PRELOAD_EXTS[ext:lower()] or nil

    local resolved = kind or ext_kind
    if (not resolved and not ext_kind) then return end
    if (kind and ext_kind and kind ~= ext_kind) then
        resolved = ext_kind
    end

    if (resolved == "image") then
        local Sprites = _G.Sprites
        if (Sprites and Sprites.PreloadFile) then
            Sprites.PreloadFile(full_path)
        end
    elseif (resolved == "sound") then
        local Audio = _G.Audio
        if (Audio and Audio.PreloadFile) then
            Audio.PreloadFile(full_path, "sound")
        end
    elseif (resolved == "music") then
        local Audio = _G.Audio
        if (Audio and Audio.PreloadFile) then
            Audio.PreloadFile(full_path, "music")
        end
    elseif (resolved == "font") then
        local Fonts = _G.Fonts
        if (Fonts and Fonts.PreloadFile) then
            Fonts.PreloadFile(full_path)
        end
    end
end

--- Normalise one caller path into a Game directory to walk + its resource kind.
--- Returns nil for empty paths or unknown top-level type names.
---@param p string Caller-supplied path, e.g. "Sprites/Test/" or "Music".
---@return string|nil game_dir
---@return string|nil kind
local function resolvePreloadPath(p)
    if (type(p) ~= "string") then return nil end
    p = p:gsub("\\", "/")
    p = p:gsub("^Game/Resources/", "")
    p = p:gsub("^Game/", "")
    p = p:gsub("^/+", "")
    p = p:gsub("/+$", "")
    if (p == "") then return nil end

    local first = p:match("^([^/]+)")
    local kind = PRELOAD_TYPE_KIND[first]
    if (not kind) then
        print("[SE.Preload] Unknown resource type '" .. tostring(first) ..
            "'. Expected one of: Sprites, Sounds, Music, Fonts.")
        return nil
    end

    return PRELOAD_GAME_ROOT .. p, kind
end

--- Preload every file under one or more Game resource folders.
---   SE.Preload("Sprites/Test")        -> Game/Resources/Sprites/Test/**
---   SE.Preload("Music", "Sounds/ui")  -> both trees
---   SE.Preload("Sprites/")            -> whole Game sprite tree
--- Only the Game area is walked; the main Resources/ tree is never touched.
---@param ... string One or more paths shaped "<Type>[/<Sub>][/]".
---@return integer total_files Number of files handed to a loader.
function se.preload.Preload(...)
    local total = 0
    local seen = {}
    for i = 1, select("#", ...) do
        local p = select(i, ...)
        local dir, kind = resolvePreloadPath(p)
        if (dir and not seen[dir]) then
            seen[dir] = true
            local files = collectPreloadFiles(dir)
            for _, f in ipairs(files) do
                preloadOneFile(f, kind)
                total = total + 1
            end
        end
    end
    return total
end

--- Preload the entire Game/Resources/ tree. Equivalent to passing every
--- top-level subfolder of it to SE.Preload, but discovered at call time so a
--- game does not have to name them all.
---@return integer total_files
function se.preload.PreloadAll()
    local files = collectPreloadFiles(PRELOAD_GAME_ROOT)
    for _, f in ipairs(files) do
        preloadOneFile(f, nil)
    end
    return #files
end

--- Top-level convenience aliases so callers can write SE.Preload(...) /
--- SE.PreloadAll() the same way they already write SE.tools.hexColor(...).
---@param ... any
se.Preload = function(...)
    return se.preload.Preload(...)
end
se.PreloadAll = function()
    return se.preload.PreloadAll()
end

return se
