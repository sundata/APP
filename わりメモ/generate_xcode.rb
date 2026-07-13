#!/usr/bin/env ruby

require 'fileutils'
require 'json'

# プロジェクト設定
PROJECT_NAME = "わりメモ"
PROJECT_PATH = "/Users/sundata/Documents/GitHub/APP/わりメモ/わりメモ.xcodeproj"
BUNDLE_ID = "com.yourcompany.warimeao"
PRODUCT_NAME = "わりメモ"
MIN_IOS_VERSION = "16.0"

# ディレクトリ作成
FileUtils.mkdir_p(PROJECT_PATH)

# Contents.json を作成
contents_json = {
  "fileVersion" => 1,
  "formatVersion" => 2,
  "generatedWithToolsVersion" => "14.0",
  "shouldAtomizeOnRead" => false
}

File.write(File.join(PROJECT_PATH, "project.pbxproj"), generate_pbxproj)

def generate_pbxproj
  pbxproj = <<~PBXPROJ
    // !$*UTF8*$!
    {
      archiveVersion = 1;
      classes = {
      };
      objectVersion = 56;
      objects = {
        1C2D0001000000001 /* PBXBuildFile */ = {
          isa = PBXBuildFile;
          fileRef = 1C2D0002000000001;
        };
        1C2D0002000000001 /* WarimemoApp.swift */ = {
          isa = PBXFileReference;
          lastKnownFileType = sourcecode.swift;
          path = WarimemoApp.swift;
          sourceTree = "<group>";
        };
        1C2D0003000000001 /* ContentView.swift */ = {
          isa = PBXFileReference;
          lastKnownFileType = sourcecode.swift;
          path = ContentView.swift;
          sourceTree = "<group>";
        };
        1C2D0004000000001 /* GroupManager.swift */ = {
          isa = PBXFileReference;
          lastKnownFileType = sourcecode.swift;
          path = GroupManager.swift;
          sourceTree = "<group>";
        };
        1C2D0005000000001 /* Group.swift */ = {
          isa = PBXFileReference;
          lastKnownFileType = sourcecode.swift;
          path = Group.swift;
          sourceTree = "<group>";
        };
        1C2D0006000000001 /* Assets.xcassets */ = {
          isa = PBXFileReference;
          lastKnownFileType = folder.assetcatalog;
          path = Assets.xcassets;
          sourceTree = "<group>";
        };
        1C2D0007000000001 /* Preview Assets.xcassets */ = {
          isa = PBXFileReference;
          lastKnownFileType = folder.assetcatalog;
          path = "Preview Assets.xcassets";
          sourceTree = "<group>";
        };
        1C2D0008000000001 /* わりメモ */ = {
          isa = PBXGroup;
          children = (
            1C2D0002000000001,
            1C2D0003000000001,
            1C2D0004000000001,
            1C2D0005000000001,
            1C2D0006000000001,
            1C2D0007000000001,
          );
          path = わりメモ;
          sourceTree = SOURCE_ROOT;
        };
        1C2D0009000000001 /* Products */ = {
          isa = PBXGroup;
          children = (
            1C2D000A000000001,
          );
          name = Products;
          sourceTree = "<group>";
        };
        1C2D000A000000001 /* わりメモ.app */ = {
          isa = PBXFileReference;
          explicitFileType = wrapper.application;
          includeInIndex = 0;
          path = わりメモ.app;
          sourceTree = BUILT_PRODUCTS_DIR;
        };
        1C2D000B000000001 /* PBXProject */ = {
          isa = PBXProject;
          attributes = {
            BuildIndependentTargetsInParallel = 1;
            LastSwiftUpdateCheck = 1600;
            LastUpgradeCheck = 1600;
            ORGANIZATIONNAME = "";
            TargetAttributes = {
              1C2D000C000000001 = {
                CreatedOnToolsVersion = 16.0;
              };
            };
          };
          buildConfigurationList = 1C2D000D000000001;
          classPrefix = "";
          developmentRegion = ja;
          hasScannedForEncodings = 0;
          knownRegions = (
            en,
            ja,
            Base,
          );
          mainGroup = 1C2D000E000000001;
          productRefGroup = 1C2D0009000000001;
          projectDirPath = "";
          projectRoot = "";
          targets = (
            1C2D000C000000001,
          );
        };
        1C2D000C000000001 /* わりメモ */ = {
          isa = PBXNativeTarget;
          buildConfigurationList = 1C2D000F000000001;
          buildPhases = (
            1C2D0010000000001,
            1C2D0011000000001,
          );
          buildRules = (
          );
          dependencies = (
          );
          name = わりメモ;
          productName = わりメモ;
          productReference = 1C2D000A000000001;
          productType = "com.apple.product-type.application";
        };
        1C2D0010000000001 /* Sources */ = {
          isa = PBXSourcesBuildPhase;
          buildActionMask = 2147483647;
          files = (
            1C2D0001000000001,
          );
          runOnlyForDeploymentPostprocessing = 0;
        };
        1C2D0011000000001 /* Resources */ = {
          isa = PBXResourcesBuildPhase;
          buildActionMask = 2147483647;
          files = (
          );
          runOnlyForDeploymentPostprocessing = 0;
        };
        1C2D000D000000001 /* Build configuration list for PBXProject "わりメモ" */ = {
          isa = XCConfigurationList;
          buildConfigurations = (
            1C2D0012000000001,
            1C2D0013000000001,
          );
          defaultConfigurationIsVisible = 0;
          defaultConfigurationName = Release;
        };
        1C2D000E000000001 /* わりメモ */ = {
          isa = PBXGroup;
          children = (
            1C2D0008000000001,
            1C2D0009000000001,
          );
          sourceTree = SOURCE_ROOT;
        };
        1C2D000F000000001 /* Build configuration list for PBXNativeTarget "わりメモ" */ = {
          isa = XCConfigurationList;
          buildConfigurations = (
            1C2D0014000000001,
            1C2D0015000000001,
          );
          defaultConfigurationIsVisible = 0;
          defaultConfigurationName = Release;
        };
        1C2D0012000000001 /* Debug */ = {
          isa = XCBuildConfiguration;
          buildSettings = {
            ALWAYS_SEARCH_USER_PATHS = NO;
            CLANG_ANALYZER_NONNULL = YES;
            CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
            CLANG_CXX_LANGUAGE_DIALECT = "c++20";
            CLANG_CXX_LIBRARY = "libc++";
            CLANG_ENABLE_MODULES = YES;
            CLANG_ENABLE_OBJC_ARC = YES;
            CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
            CLANG_WARN_BOOL_CONVERSION = YES;
            CLANG_WARN_COMMA = YES;
            CLANG_WARN_CONSTANT_CONVERSION = YES;
            CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
            CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
            CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
            CLANG_WARN_EMPTY_BODY = YES;
            CLANG_WARN_ENUM_CONVERSION = YES;
            CLANG_WARN_INFINITE_RECURSION = YES;
            CLANG_WARN_INT_CONVERSION = YES;
            CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
            CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
            CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
            CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
            CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
            CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
            CLANG_WARN_STRICT_PROTOTYPES = YES;
            CLANG_WARN_SUSPICIOUS_MOVE = YES;
            CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION = YES;
            CLANG_WARN_UNREACHABLE_CODE = YES;
            CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
            COPY_PHASE_STRIP = NO;
            DEBUG_INFORMATION_FORMAT = dwarf;
            ENABLE_STRICT_OBJC_MSGSEND = YES;
            ENABLE_TESTABILITY = YES;
            GCC_C_LANGUAGE_DIALECT = c99;
            GCC_DYNAMIC_NO_PIC = NO;
            GCC_NO_COMMON_BLOCKS = YES;
            GCC_OPTIMIZATION_LEVEL = 0;
            GCC_PREPROCESSOR_DEFINITIONS = (
              "DEBUG=1",
              "$(inherited)",
            );
            GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
            GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
            GCC_WARN_UNDECLARED_SELECTOR = YES;
            GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
            GCC_WARN_UNUSED_FUNCTION = YES;
            GCC_WARN_UNUSED_VARIABLE = YES;
            IPHONEOS_DEPLOYMENT_TARGET = 16.0;
            LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
            MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
            MTL_FAST_MATH = YES;
            ONLY_ACTIVE_ARCH = YES;
            SDKROOT = iphoneos;
            SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
            SWIFT_OPTIMIZATION_LEVEL = "-Onone";
          };
          name = Debug;
        };
        1C2D0013000000001 /* Release */ = {
          isa = XCBuildConfiguration;
          buildSettings = {
            ALWAYS_SEARCH_USER_PATHS = NO;
            CLANG_ANALYZER_NONNULL = YES;
            CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
            CLANG_CXX_LANGUAGE_DIALECT = "c++20";
            CLANG_CXX_LIBRARY = "libc++";
            CLANG_ENABLE_MODULES = YES;
            CLANG_ENABLE_OBJC_ARC = YES;
            CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
            CLANG_WARN_BOOL_CONVERSION = YES;
            CLANG_WARN_COMMA = YES;
            CLANG_WARN_CONSTANT_CONVERSION = YES;
            CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
            CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
            CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
            CLANG_WARN_EMPTY_BODY = YES;
            CLANG_WARN_ENUM_CONVERSION = YES;
            CLANG_WARN_INFINITE_RECURSION = YES;
            CLANG_WARN_INT_CONVERSION = YES;
            CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
            CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
            CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
            CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
            CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
            CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
            CLANG_WARN_STRICT_PROTOTYPES = YES;
            CLANG_WARN_SUSPICIOUS_MOVE = YES;
            CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION = YES;
            CLANG_WARN_UNREACHABLE_CODE = YES;
            CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
            COPY_PHASE_STRIP = NO;
            DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
            ENABLE_NS_ASSERTIONS = NO;
            ENABLE_STRICT_OBJC_MSGSEND = YES;
            GCC_C_LANGUAGE_DIALECT = c99;
            GCC_NO_COMMON_BLOCKS = YES;
            GCC_OPTIMIZATION_LEVEL = s;
            GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
            GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
            GCC_WARN_UNDECLARED_SELECTOR = YES;
            GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
            GCC_WARN_UNUSED_FUNCTION = YES;
            GCC_WARN_UNUSED_VARIABLE = YES;
            IPHONEOS_DEPLOYMENT_TARGET = 16.0;
            LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
            MTL_ENABLE_DEBUG_INFO = NO;
            MTL_FAST_MATH = YES;
            SDKROOT = iphoneos;
            SWIFT_COMPILATION_MODE = wholemodule;
            SWIFT_OPTIMIZATION_LEVEL = "-O";
            VALIDATE_PRODUCT = YES;
          };
          name = Release;
        };
        1C2D0014000000001 /* Debug */ = {
          isa = XCBuildConfiguration;
          buildSettings = {
            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
            CODE_SIGN_STYLE = Automatic;
            CURRENT_PROJECT_VERSION = 1;
            DEVELOPMENT_ASSET_PATHS = "わりメモ/Preview\\ Assets.xcassets";
            ENABLE_PREVIEWS = YES;
            GENERATE_INFOPLIST_FILE = YES;
            INFOPLIST_KEY_UIApplicationSceneManifestKey_UISceneConfigurations = "";
            INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
            INFOPLIST_KEY_UILaunchScreen_Generation = YES;
            INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
            INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
            LD_RUNPATH_SEARCH_PATHS = (
              "$(inherited)",
              "@executable_path/Frameworks",
            );
            MARKETING_VERSION = 1.0;
            PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.warimeao;
            PRODUCT_NAME = "$(TARGET_NAME)";
            SWIFT_EMIT_LOC_STRINGS = YES;
            SWIFT_VERSION = 5.0;
            TARGETED_DEVICE_FAMILY = "1,2";
          };
          name = Debug;
        };
        1C2D0015000000001 /* Release */ = {
          isa = XCBuildConfiguration;
          buildSettings = {
            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
            CODE_SIGN_STYLE = Automatic;
            CURRENT_PROJECT_VERSION = 1;
            DEVELOPMENT_ASSET_PATHS = "わりメモ/Preview\\ Assets.xcassets";
            ENABLE_PREVIEWS = YES;
            GENERATE_INFOPLIST_FILE = YES;
            INFOPLIST_KEY_UIApplicationSceneManifestKey_UISceneConfigurations = "";
            INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
            INFOPLIST_KEY_UILaunchScreen_Generation = YES;
            INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
            INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
            LD_RUNPATH_SEARCH_PATHS = (
              "$(inherited)",
              "@executable_path/Frameworks",
            );
            MARKETING_VERSION = 1.0;
            PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.warimeao;
            PRODUCT_NAME = "$(TARGET_NAME)";
            SWIFT_EMIT_LOC_STRINGS = YES;
            SWIFT_VERSION = 5.0;
            TARGETED_DEVICE_FAMILY = "1,2";
          };
          name = Release;
        };
      };
      rootObject = 1C2D000B000000001;
    }
  PBXPROJ
  pbxproj
end

puts "✓ Xcodeプロジェクトファイルを生成しました"
