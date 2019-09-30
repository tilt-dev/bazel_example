BAZEL_RUN_CMD = "bazel run --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 %s"

BAZEL_SOURCES_CMD = """
  bazel query 'filter("^//", kind("source file", deps(set(%s))))' --order_output=no
  """.strip()

BAZEL_BUILDFILES_CMD = """
  bazel query 'filter("^//", buildfiles(deps(set(%s))))' --order_output=no
  """.strip()

def bazel_labels_to_files(labels):
  files = {}
  for l in labels:
    if l.startswith("//external/") or l.startswith("//external:"):
      continue
    elif l.startswith("//"):
      l = l[2:]

    path = l.replace(":", "/")
    if path.startswith("/"):
      path = path[1:]

    files[path] = None

  return files.keys()

def watch_labels(labels):
  watched_files = []
  for l in labels:
    if l.startswith("@"):
      continue
    elif l.startswith("//external/") or l.startswith("//external:"):
      continue
    elif l.startswith("//"):
      l = l[2:]

    path = l.replace(":", "/")
    if path.startswith("/"):
      path = path[1:]

    watch_file(path)
    watched_files.append(path)

  return watched_files

def bazel_k8s(target):
  build_deps = str(local(BAZEL_BUILDFILES_CMD % target)).splitlines()
  source_deps = str(local(BAZEL_SOURCES_CMD % target)).splitlines()
  watch_labels(build_deps)
  watch_labels(source_deps)

  return local("bazel run %s" % target)

def bazel_build(image, target):
  build_deps = str(local(BAZEL_BUILDFILES_CMD % target)).splitlines()
  watch_labels(build_deps)

  source_deps = str(local(BAZEL_SOURCES_CMD % target)).splitlines()
  source_deps_files =bazel_labels_to_files(source_deps)

  custom_build(
    image,
    BAZEL_RUN_CMD % target,
    source_deps,
    tag="image",
  )

k8s_yaml(bazel_k8s(":snack-server"))
k8s_yaml(bazel_k8s(":vigoda-server"))

bazel_build('bazel/snack', "//snack:image")
bazel_build('bazel/vigoda', "//vigoda:image")

k8s_resource('varowner-snack', port_forwards=9000)
k8s_resource('varowner-vigoda', port_forwards=9001)
