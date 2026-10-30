load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test", "ios_application")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "InvisibleInkDustNode",
    module_name = "InvisibleInkDustNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramUI/Components/SpaceWarpView:SpaceWarpView",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/FastBlur:FastBlur",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Real UIKit component rendering; the runner creates its own disposable simulator.
swift_library(
    name = "ScratchCardRenderingTestsLib",
    testonly = True,
    srcs = ["Tests/ScratchCardRenderingTests.swift"],
    deps = [":InvisibleInkDustNode", "//submodules/Display:Display"],
)

ios_test_runner(
    name = "ScratchCardTestRunner",
    device_type = "iPhone Duo",
    os_version = "27.1",
)

ios_unit_test(
    name = "ScratchCardRenderingTests",
    test_host = ":ScratchCardTestHost",
    minimum_os_version = "15.0",
    runner = ":ScratchCardTestRunner",
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    linkopts = ["-framework", "MediaPlayer", "-framework", "AVKit", "-lz"],
    deps = [":ScratchCardRenderingTestsLib"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "ScratchCardTestHostLib",
    testonly = True,
    module_name = "ScratchCardTestHostLib",
    srcs = ["Tests/Host/AppDelegate.swift"],
    deps = [":InvisibleInkDustNode"],
)

plist_fragment(
    name = "ScratchCardTestHostInfo",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key><string>org.telegram.ScratchCardTestHost</string>
    <key>CFBundleName</key><string>ScratchCardTestHost</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>UILaunchScreen</key><dict/>
    <key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
    <key>UIApplicationSceneManifest</key><dict>
      <key>UIApplicationSupportsMultipleScenes</key><false/>
      <key>UISceneConfigurations</key><dict>
        <key>UIWindowSceneSessionRoleApplication</key><array><dict>
          <key>UISceneConfigurationName</key><string>Default</string>
          <key>UISceneDelegateClassName</key><string>SceneDelegate</string>
        </dict></array>
      </dict>
    </dict>
    """,
)

ios_application(
    name = "ScratchCardTestHost",
    testonly = True,
    linkopts = ["-framework", "MediaPlayer", "-framework", "AVKit", "-lz"],
    bundle_id = "org.telegram.ScratchCardTestHost",
    families = ["iphone"],
    minimum_os_version = "15.0",
    infoplists = [":ScratchCardTestHostInfo"],
    deps = ["//Tests/Common:Main", ":ScratchCardTestHostLib"],
)
