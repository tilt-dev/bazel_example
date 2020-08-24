load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")
load("@io_bazel_rules_docker//go:image.bzl", "go_image")
load("@io_bazel_rules_docker//container:container.bzl", "container_bundle")

package(default_visibility = ["//visibility:public"])

go_image(
    name = "image",
    srcs = ["main.go"],
    importpath = "github.com/tilt-dev/bazel_example/vigoda",
    deps = ["//common:go_default_library"],
)

go_library(
    name = "go_default_library",
    srcs = ["main.go"],
    importpath = "github.com/tilt-dev/bazel_example/vigoda",
    deps = ["//common:go_default_library"],
)

go_binary(
    name = "vigoda",
    embed = [":go_default_library"],
)
