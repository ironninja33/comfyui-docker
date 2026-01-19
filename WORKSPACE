workspace(name = "comfyui_docker")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Platforms
http_archive(
    name = "platforms",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.10/platforms-0.0.10.tar.gz",
        "https://github.com/bazelbuild/platforms/releases/download/0.0.10/platforms-0.0.10.tar.gz",
    ],
)

# Rules Python
http_archive(
    name = "rules_python",
    strip_prefix = "rules_python-0.40.0",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.40.0/rules_python-0.40.0.tar.gz",
)

# Rules OCI
http_archive(
    name = "rules_oci",
    strip_prefix = "rules_oci-1.4.0",
    url = "https://github.com/bazel-contrib/rules_oci/releases/download/v1.4.0/rules_oci-v1.4.0.tar.gz",
)

load("@rules_oci//oci:dependencies.bzl", "rules_oci_dependencies")
rules_oci_dependencies()

load("@rules_oci//oci:repositories.bzl", "LATEST_CRANE_VERSION", "oci_register_toolchains")
oci_register_toolchains(
    name = "oci",
    crane_version = LATEST_CRANE_VERSION,
)

# Rules Pkg
http_archive(
    name = "rules_pkg",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/1.0.1/rules_pkg-1.0.1.tar.gz",
        "https://github.com/bazelbuild/rules_pkg/releases/download/1.0.1/rules_pkg-1.0.1.tar.gz",
    ],
)
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")
rules_pkg_dependencies()

# Pull Base Image
load("@rules_oci//oci:pull.bzl", "oci_pull")
oci_pull(
    name = "runpod_base",
    image = "runpod/comfyui",
    tag = "latest",
    platforms = ["linux/amd64"],
)

# Static FFmpeg Binary (Linux AMD64)
http_archive(
    name = "ffmpeg_static",
    url = "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz",
    build_file_content = """
package(default_visibility = ["//visibility:public"])
filegroup(
    name = "ffmpeg_bin",
    srcs = glob(["**/ffmpeg"]),
)
filegroup(
    name = "ffprobe_bin",
    srcs = glob(["**/ffprobe"]),
)
""",
)
