-- Solar2D config
local C = require("consts")

application = {
    content = {
        width = C.WIDTH,
        height = C.HEIGHT,
        scale = "letterbox",
        fps = 60,
        imageSuffix = {
            ["@2x"] = 1.5,
            ["@4x"] = 2.0,
        },
    },
    android = {
        largeHeap = true,
        minSdkVersion = 21,
        targetSdkVersion = 33,
    },
}