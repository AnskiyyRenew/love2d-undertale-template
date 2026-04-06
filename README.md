# SoulEngine - A LOVE2D UNDERTALE Fangame Template

`SoulEngine` is a LOVE2D-based template and framework for creating games inspired by [UNDERTALE](https://undertale.com/).

It is not just a simple battle demo. The template already includes a relatively complete development workflow covering battle scenes, overworld exploration, dialogue presentation, map production, localization, debugging, and packaging, making it a practical starting point for real fangame projects.

This project is influenced by [Create Your Frisk](https://github.com/RhenaudTheLukark/CreateYourFrisk), and therefore shares some similarities in spirit and workflow design.

## Why This Template Stands Out

Most similar templates only provide a basic combat prototype. `SoulEngine` goes further by trying to solve the actual day-to-day needs of development:

*   **Battle system included** - Comes with menu flow, enemy setup, player stats, attack timing, damage calculation, wave scripts, and common UNDERTALE-style battle logic.
*   **Overworld system included** - Supports map loading, player movement, collisions, triggers, save points, room transitions, chests, signs, and overworld encounters.
*   **Dialogue and text presentation tools** - Includes typewriter text, instant text drawing, bubble boxes, text effects, multi-font support, and formatting tags.
*   **Map workflow ready** - Built to work with Tiled maps, object layers, and room-based scene logic instead of requiring everything to be hand-wired from scratch.
*   **Beginner-friendly documentation** - The project ships with a large documentation set covering setup, core systems, advanced features, battle development, overworld development, localization, packaging, and error handling.
*   **Built for actual projects** - Includes release configuration, custom error handling, packaging tools, localization support, and API/network-related extensions.

## Feature Overview

### Core Gameplay Systems

*   **UNDERTALE-style battle framework**
    *   FIGHT / ACT / ITEM / MERCY flow
    *   enemy definitions and player data
    *   custom attack waves and wave templates
    *   attack timing, hit calculation, miss text, flee logic
    *   built-in support for common attack elements such as bones and Gaster Blasters
*   **Overworld framework**
    *   room-based maps
    *   player movement and camera follow
    *   physical collision and trigger areas
    *   signs, chests, save points, warps, and scripted interactions
    *   random encounter support with battle scene switching

### Content Creation Tools

*   **Text system**
    *   typewriter dialogue
    *   instant text rendering
    *   bubble boxes
    *   color, font, size, spacing, and effect tags
    *   support for multilingual text display
*   **Sprite and scene workflow**
    *   scene switching system
    *   sprite management
    *   layer sorting
    *   tween and timing helpers
*   **Map production pipeline**
    *   Tiled-based workflow
    *   map examples included in the repository
    *   object-layer-driven interaction logic

### Advanced and Practical Features

*   **Shader support**
    *   screen shaders
    *   multi-pass rendering workflow
    *   mask and stencil support
*   **GUI utilities**
    *   buttons
    *   sliders
    *   text input boxes
    *   panels
    *   windows
    *   dropdowns
*   **Audio manager**
    *   sound and music playback
    *   loop points
    *   volume and pitch transitions
*   **Localization support**
    *   built-in language loading flow
    *   English and Simplified Chinese examples included
*   **GameJolt API support**
    *   user authentication
    *   trophies
    *   sessions
    *   datastore
    *   scores / leaderboards
*   **Networking foundation**
    *   ships with `sock.lua`
    *   documentation includes online/multiplayer-related development notes
*   **Windows-specific utilities**
    *   window handling helpers
    *   screenshots
    *   system dialog support

## Small but Very Useful Details

These are not flashy features, but they make development smoother:

*   **Custom error screen** - Makes runtime crashes easier to read and report.
*   **Release switch** - `_RELEASED` lets you clearly separate development mode from release mode.
*   **Fast scene reset / reload shortcuts** - Handy during iteration and testing.
*   **Built-in examples** - Example scenes, waves, and maps reduce the time needed to understand the framework.
*   **Packaging tools included** - Windows users can package projects more conveniently with the bundled tools.

## Good Fit For

This template is especially suitable for:

*   creators making UNDERTALE-inspired fangames in LOVE2D
*   developers who want both battle scenes and overworld exploration
*   beginners who need structured documentation instead of just raw source code
*   small teams or solo creators who want to start production quickly

## Prerequisites

*   Familiarity with [UNDERTALE](https://undertale.com/) is recommended.
*   The [LOVE2D](https://love2d.org/) engine, version **11.3** or compatible, must be installed on your system.

Future updates will aim to maintain compatibility with newer LOVE versions.

## How to Use the Template

### On PC (Recommended)

For development and testing, it is recommended to use an editor like [Visual Studio Code](https://code.visualstudio.com/) with relevant extensions for LOVE/Lua, or any other editor of your choice.

**To run the game:**

*   Use your editor's LOVE2D run feature, if available.
*   Or drag the project folder onto `love.exe` (or `lovec.exe` on Windows).

### On Mobile (Android)

You can browse and edit the project's script files using a capable file manager or code editing tool on Android, such as [MT Manager](https://mt2.cn).

## Documentation

The repository includes a full documentation site in the `Documentation` folder, covering topics such as:

*   getting started
*   Lua basics for beginners
*   basic engine workflow
*   advanced development
*   battle scene development
*   overworld development
*   localization
*   packaging and release
*   common error handling

## Credits

This template utilizes the following excellent libraries:

*   [MD5](https://github.com/kikito/md5.lua) by kikito - A pure-Lua 5.1 implementation of the MD5 algorithm.
*   [dkjson](http://dkolf.de/dkjson-lua/) - A JSON module for Lua that supports UTF-8.
*   [STI](https://github.com/karai17/Simple-Tiled-Implementation) by karai17 - A Tiled map loader and renderer for LÖVE.
*   [sock](https://github.com/camchenry/sock.lua) by camchenry - A networking library for LÖVE, useful for multiplayer-related experiments.

## Community

*   **Discord Server:** https://discord.gg/QeCmVMX7Mk
*   **QQ Group:** 626073642
