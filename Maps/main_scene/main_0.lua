return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 30,
  height = 20,
  tilewidth = 20,
  tileheight = 20,
  nextlayerid = 9,
  nextobjectid = 40,
  properties = {},
  tilesets = {
    {
      name = "unnamed_3563",
      firstgid = 1,
      class = "",
      tilewidth = 20,
      tileheight = 20,
      spacing = 0,
      margin = 0,
      columns = 7,
      image = "../images/Scene/True Lab/unnamed_3563.png",
      imagewidth = 140,
      imageheight = 200,
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 20,
        height = 20
      },
      properties = {},
      wangsets = {},
      tilecount = 70,
      tiles = {}
    },
    {
      name = "bed",
      firstgid = 71,
      class = "",
      tilewidth = 50,
      tileheight = 68,
      spacing = 0,
      margin = 0,
      columns = 0,
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 1,
        height = 1
      },
      properties = {},
      wangsets = {},
      tilecount = 2,
      tiles = {
        {
          id = 0,
          image = "../images/Scene/True Lab/spr_bed_dark_0.png",
          width = 50,
          height = 68
        },
        {
          id = 1,
          image = "../images/Scene/True Lab/unnamed_3557.png",
          width = 29,
          height = 54
        }
      }
    }
  },
  layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 30,
      height = 20,
      id = 1,
      name = "图块层 1",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      chunks = {
        {
          x = 0, y = 0, width = 16, height = 16,
          data = {
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 8, 29, 30, 31, 9, 9, 10, 11, 12, 9, 10, 11, 12, 9, 10,
            1, 15, 36, 37, 38, 16, 16, 17, 18, 19, 16, 17, 18, 19, 16, 17,
            1, 22, 43, 44, 45, 23, 23, 24, 25, 26, 23, 24, 25, 26, 23, 24,
            1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        },
        {
          x = 16, y = 0, width = 16, height = 16,
          data = {
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            11, 12, 13, 29, 30, 8, 10, 29, 30, 8, 10, 29, 30, 9, 10, 13,
            18, 19, 20, 36, 37, 15, 17, 36, 37, 15, 17, 36, 37, 16, 17, 20,
            25, 26, 27, 43, 44, 22, 24, 43, 44, 22, 24, 43, 44, 23, 24, 27,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        },
        {
          x = 32, y = 0, width = 16, height = 16,
          data = {
            1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            29, 30, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            36, 37, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            43, 44, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        }
      }
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 30,
      height = 20,
      id = 2,
      name = "图块层 2",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      chunks = {
        {
          x = 0, y = 0, width = 16, height = 16,
          data = {
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 39, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 46, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        },
        {
          x = 16, y = 0, width = 16, height = 16,
          data = {
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 33, 34, 0, 0, 0, 46, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 40, 41, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 3,
      name = "marks",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 3,
          name = "",
          type = "",
          shape = "point",
          x = 60,
          y = 100,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["direction"] = "down",
            ["id"] = 1
          }
        },
        {
          id = 32,
          name = "",
          type = "",
          shape = "point",
          x = 400,
          y = 100,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 2
          }
        },
        {
          id = 33,
          name = "",
          type = "",
          shape = "point",
          x = 480,
          y = 100,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 3
          }
        },
        {
          id = 34,
          name = "",
          type = "",
          shape = "point",
          x = 560,
          y = 100,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 4
          }
        },
        {
          id = 35,
          name = "",
          type = "",
          shape = "point",
          x = 660,
          y = 100,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 5
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 4,
      name = "warps",
      class = "",
      visible = true,
      opacity = 0.77,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 2,
          name = "",
          type = "",
          shape = "rectangle",
          x = 40,
          y = 60,
          width = 40,
          height = 19,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 1
          }
        },
        {
          id = 19,
          name = "",
          type = "",
          shape = "rectangle",
          x = 380,
          y = 60,
          width = 40,
          height = 19.125,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 2
          }
        },
        {
          id = 20,
          name = "",
          type = "",
          shape = "rectangle",
          x = 460,
          y = 60,
          width = 40,
          height = 19.375,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 3
          }
        },
        {
          id = 21,
          name = "",
          type = "",
          shape = "rectangle",
          x = 540,
          y = 60,
          width = 40,
          height = 18.75,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 4
          }
        },
        {
          id = 27,
          name = "",
          type = "",
          shape = "rectangle",
          x = 640,
          y = 60,
          width = 40,
          height = 19,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 5
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 7,
      name = "saves",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 30,
          name = "",
          type = "",
          shape = "point",
          x = 480,
          y = 140,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 1
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "triggers",
      class = "",
      visible = true,
      opacity = 0.54,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 8,
          name = "",
          type = "",
          shape = "rectangle",
          x = 20,
          y = 100,
          width = 20,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 1
          }
        },
        {
          id = 9,
          name = "",
          type = "",
          shape = "rectangle",
          x = 144.5,
          y = 60,
          width = 70.25,
          height = 39.75,
          rotation = 0,
          visible = true,
          properties = {
            ["rr"] = 1
          }
        },
        {
          id = 10,
          name = "",
          type = "",
          shape = "rectangle",
          x = 224.5,
          y = 60,
          width = 69.75,
          height = 38.75,
          rotation = 0,
          visible = true,
          properties = {
            ["rr"] = 2
          }
        },
        {
          id = 11,
          name = "",
          type = "",
          shape = "rectangle",
          x = 304.5,
          y = 60,
          width = 70.25,
          height = 39,
          rotation = 0,
          visible = true,
          properties = {
            ["rr"] = 3
          }
        },
        {
          id = 12,
          name = "",
          type = "",
          shape = "rectangle",
          x = 160,
          y = 61.2337,
          width = 40,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 2
          }
        },
        {
          id = 13,
          name = "",
          type = "",
          shape = "rectangle",
          x = 240,
          y = 61.2273,
          width = 40,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 3
          }
        },
        {
          id = 14,
          name = "",
          type = "",
          shape = "rectangle",
          x = 320,
          y = 62,
          width = 40,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 4
          }
        },
        {
          id = 31,
          name = "",
          type = "",
          shape = "rectangle",
          x = 660,
          y = 140,
          width = 20,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 7
          }
        },
        {
          id = 37,
          name = "",
          type = "",
          shape = "rectangle",
          x = 419.5,
          y = 80,
          width = 30,
          height = 20.375,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 5
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 8,
      name = "signs",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 39,
          name = "",
          type = "",
          shape = "point",
          x = 609.5,
          y = 88.5,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["id"] = 1
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 5,
      name = "walls",
      class = "",
      visible = true,
      opacity = 0.53,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 4,
          name = "",
          type = "",
          shape = "rectangle",
          x = 20,
          y = 60,
          width = 20,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "",
          type = "",
          shape = "rectangle",
          x = 80,
          y = 60,
          width = 300,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 15,
          name = "",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 160,
          width = 680,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 16,
          name = "",
          type = "",
          shape = "rectangle",
          x = 420,
          y = 60,
          width = 40,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 17,
          name = "",
          type = "",
          shape = "rectangle",
          x = 500,
          y = 60,
          width = 40,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 23,
          name = "",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 60,
          width = 20,
          height = 100,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 24,
          name = "",
          type = "",
          shape = "rectangle",
          x = 580,
          y = 60,
          width = 60,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 25,
          name = "",
          type = "",
          shape = "rectangle",
          x = 680,
          y = 60,
          width = 20,
          height = 120,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 36,
          name = "",
          type = "",
          shape = "rectangle",
          x = 420,
          y = 80,
          width = 29.0145,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
