local RUI = RetreatUI

RUI.ElvUIProfile = {
  actionbar = {
    backdropSpacingConverted = true,
    bar1 = {
      buttonsize = 30,
      counttext = true,
      hotkeytext = true,
      macrotext = false,
    },
    bar2 = {
      buttonsize = 26,
      counttext = true,
      enabled = true,
      hotkeytext = true,
      macrotext = false,
      visibility = "[vehicleui] hide; show",
    },
    bar3 = {
      buttons = 12,
      buttonsPerRow = 12,
      buttonsize = 24,
      counttext = true,
      enabled = true,
      hotkeytext = true,
      macrotext = false,
      visibility = "[vehicleui] hide; show",
    },
    bar4 = {
      backdrop = false,
      counttext = true,
      enabled = false,
      hotkeytext = true,
      macrotext = false,
      visibility = "[vehicleui] hide; show",
    },
    bar5 = {
      counttext = true,
      enabled = false,
      hotkeytext = true,
      macrotext = false,
      visibility = "[vehicleui] hide; show",
    },
    bar6 = {
      counttext = true,
      hotkeytext = true,
      macrotext = false,
      visibility = "[vehicleui] hide; show",
    },
    countFont = "Fira Sans Heavy",
    countFontOutline = "OUTLINE",
    countFontSize = 10,
    font = "Fira Sans Heavy",
    fontOutline = "OUTLINE",
  },
  auras = {
    buffs = {
      countFontSize = 10,
    },
    debuffs = {
      countFontSize = 10,
    },
  },
  bags = {
    bagSize = 42,
    bagWidth = 472,
    bankSize = 42,
    bankWidth = 472,
  },
  chat = {
    editBoxPosition = "ABOVE_CHAT",
    font = "Fira Sans Heavy",
    fontOutline = "OUTLINE",
    fontSize = 11,
    panelBackdrop = "HIDEBOTH",
    panelColorConverted = true,
    panelHeight = 318,
    panelWidth = 360,
    panelTabBackdrop = false,
    retreatHideRightChat = true,
    tabFontSize = 11,
  },
  currentTutorial = 8,
  databars = {
    experience = {
      height = 10,
      orientation = "HORIZONTAL",
      textSize = 12,
      width = 350,
    },
    reputation = {
      enable = true,
      height = 10,
      orientation = "HORIZONTAL",
      width = 222,
    },
  },
  general = {
    backdropcolor = {
      b = 0.018,
      g = 0.012,
      r = 0.012,
    },
    bordercolor = {
      b = 0.03,
      g = 0.025,
      r = 0.025,
    },
    font = "Fira Sans Heavy",
    fontSize = 11,
    glossTex = "ElvUI Norm",
    minimap = {
      size = 205,
    },
    normTex = "ElvUI Norm",
    totems = {
      growthDirection = "HORIZONTAL",
      size = 36,
      spacing = 2,
    },
    valuecolor = {
      b = 0.02,
      g = 0,
    },
    watchFrameHeight = 360,
  },
  layoutSet = "tank",
  movers = {
    AlertFrameMover = "TOP,ElvUIParent,TOP,-1,-18",
    BNETMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-274",
    ElvAB_1 = "BOTTOM,ElvUIParent,BOTTOM,0,88",
    ElvAB_2 = "BOTTOM,ElvUIParent,BOTTOM,0,54",
    ElvAB_3 = "BOTTOM,ElvUIParent,BOTTOM,0,26",
    ElvAB_5 = "BOTTOM,ElvUIParent,BOTTOM,-210,78",
    ElvBar_Totem = "BOTTOM,ElvUIParent,BOTTOM,0,151",
    ElvUF_BossMover = "RIGHT,ElvUIParent,RIGHT,-255,62",
    ElvUF_FocusMover = "BOTTOM,ElvUIParent,BOTTOM,0,275",
    ElvUF_PartyMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,430,603",
    ElvUF_PetMover = "BOTTOM,ElvUIParent,BOTTOM,-310,320",
    ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,-310,326",
    ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-310,350",
    ElvUF_Raid40Mover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,8,503",
    ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,8,210",
    ElvUF_RaidpetMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,737",
    ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,310,326",
    ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,310,350",
    ElvUF_TargetTargetMover = "BOTTOM,ElvUIParent,BOTTOM,508,350",
    ExperienceBarMover = "BOTTOM,ElvUIParent,BOTTOM,0,2",
    LootFrameMover = "TOPLEFT,ElvUIParent,TOPLEFT,418,-186",
    MinimapMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-5,-5",
    MirrorTimer1Mover = "TOP,ElvUIParent,TOP,-1,-96",
    ReputationBarMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-2,-215",
    ShiftAB = "BOTTOM,ElvUIParent,BOTTOM,-310,8",
    TempEnchantMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-215,-4",
    TotemBarMover = "BOTTOM,ElvUIParent,BOTTOM,0,151",
    VehicleSeatMover = "TOPLEFT,ElvUIParent,TOPLEFT,4,-4",
    WatchFrameMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-148,-205",
  },
  tooltip = {
    font = "Fira Sans Heavy",
    fontSize = 11,
    healthBar = {
      font = "Fira Sans Heavy",
      height = 12,
    },
  },
  unitframe = {
    colors = {
      auraBarBuff = {
        b = 0.02,
        g = 0,
        r = 0.99,
      },
      castColor = {
        b = 0.08,
        g = 0.35,
        r = 0.86,
      },
      castNoInterrupt = {
        b = 0.12,
        g = 0.12,
        r = 0.58,
      },
      health = {
        b = 0.115,
        g = 0.09,
        r = 0.085,
      },
      healthReaction = false,
      health_backdrop = {
        b = 0.018,
        g = 0.012,
        r = 0.012,
      },
    },
    font = "Fira Sans Heavy",
    fontOutline = "OUTLINE",
    fontSize = 15,
    smoothbars = true,
    thinBorders = true,
    units = {
      arena = {
        health = {
          frequentUpdates = true,
        },
      },
      boss = {
        buffs = {
          maxDuration = 300,
          sizeOverride = 27,
          yOffset = 16,
        },
        castbar = {
          insideInfoPanel = false,
          width = 190,
        },
        debuffs = {
          maxDuration = 300,
          numrows = 1,
          sizeOverride = 27,
          yOffset = -16,
        },
        health = {
          frequentUpdates = true,
        },
        height = 40,
        infoPanel = {
          height = 17,
        },
        portrait = {
          camDistanceScale = 2,
          width = 45,
        },
        power = {
          attachTextTo = "Power",
          detachFromFrame = false,
          height = 4,
        },
        width = 190,
      },
      focus = {
        castbar = {
          insideInfoPanel = false,
          width = 180,
        },
        health = {
          frequentUpdates = true,
        },
        height = 30,
        power = {
          attachTextTo = "Power",
          detachFromFrame = false,
          height = 6,
        },
        width = 180,
      },
      focustarget = {
        health = {
          frequentUpdates = true,
        },
      },
      party = {
        growthDirection = "DOWN_RIGHT",
        height = 38,
        horizontalSpacing = 3,
        power = {
          attachTextTo = "Power",
          detachFromFrame = false,
          height = 4,
        },
        rdebuffs = {
          font = "Fira Sans Heavy",
        },
        width = 190,
      },
      pet = {
        castbar = {
          iconSize = 32,
          insideInfoPanel = false,
          width = 160,
        },
        debuffs = {
          anchorPoint = "TOPRIGHT",
          enable = true,
        },
        disableTargetGlow = false,
        health = {
          frequentUpdates = true,
        },
        height = 28,
        infoPanel = {
          height = 14,
        },
        portrait = {
          camDistanceScale = 2,
        },
        power = {
          height = 5,
        },
        width = 160,
      },
      pettarget = {
        health = {
          frequentUpdates = true,
        },
      },
      player = {
        auraBar = {
          enable = false,
        },
        aurabar = {
          enable = false,
        },
        castbar = {
          displayTarget = false,
          enable = true,
          format = "REMAINING",
          height = 18,
          icon = true,
          iconAttached = true,
          iconPosition = "LEFT",
          insideInfoPanel = false,
          latency = true,
          spark = false,
          timeToHold = 0,
          width = 260,
        },
        classbar = {
          enable = false,
          height = 0,
        },
        debuffs = {
          enable = false,
        },
        disableMouseoverGlow = true,
        health = {
          frequentUpdates = true,
          position = "RIGHT",
          text_format = "[health:current]",
          xOffset = -7,
        },
        height = 46,
        name = {
          font = "Fira Sans Heavy",
          fontOutline = "OUTLINE",
          fontSize = 11,
          position = "LEFT",
          text_format = "[name:medium]",
          xOffset = 7,
        },
        orientation = "RIGHT",
        power = {
          attachTextTo = "Power",
          enable = false,
          height = 5,
          position = "CENTER",
          text_format = "",
          xOffset = 0,
        },
        width = 260,
      },
      raid = {
        growthDirection = "RIGHT_UP",
        health = {
          frequentUpdates = true,
        },
        height = 40,
        name = {
          attachTextTo = "InfoPanel",
          position = "BOTTOMLEFT",
          xOffset = 2,
        },
        numGroups = 8,
        power = {
          enable = false,
        },
        rdebuffs = {
          font = "Fira Sans Heavy",
          size = 30,
          xOffset = 30,
          yOffset = 25,
        },
        resurrectIcon = {
          attachTo = "BOTTOMRIGHT",
        },
        visibility = "[@raid6,noexists] hide;show",
      },
      raid40 = {
        enable = false,
        height = 34,
        rdebuffs = {
          font = "Fira Sans Heavy",
        },
        width = 72,
      },
      target = {
        auraBar = {
          enable = false,
        },
        aurabar = {
          enable = false,
        },
        buffs = {
          enable = false,
        },
        castbar = {
          displayTarget = false,
          enable = true,
          format = "REMAINING",
          height = 18,
          icon = true,
          iconAttached = true,
          iconPosition = "RIGHT",
          insideInfoPanel = false,
          spark = false,
          timeToHold = 0,
          width = 260,
        },
        debuffs = {
          enable = false,
        },
        disableMouseoverGlow = true,
        health = {
          frequentUpdates = true,
          position = "LEFT",
          text_format = "[health:current]",
          xOffset = 7,
        },
        height = 46,
        name = {
          font = "Fira Sans Heavy",
          fontOutline = "OUTLINE",
          fontSize = 11,
          position = "RIGHT",
          text_format = "[name:medium]",
          xOffset = -7,
        },
        orientation = "LEFT",
        power = {
          attachTextTo = "Power",
          height = 4,
        },
        width = 260,
      },
      targettarget = {
        buffs = {
          enable = false,
        },
        debuffs = {
          anchorPoint = "TOPRIGHT",
          enable = false,
        },
        disableMouseoverGlow = true,
        enable = true,
        health = {
          frequentUpdates = true,
          position = "CENTER",
          text_format = "",
          xOffset = 0,
        },
        height = 24,
        name = {
          font = "Fira Sans Heavy",
          fontOutline = "OUTLINE",
          fontSize = 10,
          position = "CENTER",
          text_format = "[name:short]",
          xOffset = 0,
        },
        power = {
          enable = false,
        },
        raidicon = {
          attachTo = "TOP",
          enable = true,
          size = 14,
          xOffset = 0,
          yOffset = 5,
        },
        threatStyle = "GLOW",
        width = 120,
      },
      targettargettarget = {
        health = {
          frequentUpdates = true,
        },
      },
    },
  },
  version = 7.27,
}
