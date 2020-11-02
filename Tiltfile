BAZEL_RUN_CMD = "bazel run --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64"
BAZEL_BUILD_CMD = "bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64"

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

RESTART_FILE = '/.restart-proc'

TYPE_RESTART_CONTAINER_STEP = 'live_update_restart_container_step'

KWARGS_BLACKLIST = [
    # since we'll be passing `dockerfile_contents` when building the
    # child image, remove any kwargs that might conflict
    'dockerfile', 'dockerfile_contents',

    # 'target' isn't relevant to our child build--if we pass this arg,
    # Docker will just fail to find the specified stage and error out
    'target',

  'tag',
]

def custom_build_with_restart(ref, command, deps, entrypoint, live_update,
                              base_suffix='-tilt_docker_build_with_restart_base', restart_file=RESTART_FILE, **kwargs):
    """Wrap a docker_build call and its associated live_update steps so that the last step
    of any live update is to rerun the given entrypoint.
     Args:
      ref: name for this image (e.g. 'myproj/backend' or 'myregistry/myproj/backend'); as the parameter of the same name in docker_build
      context: path to use as the Docker build context; as the parameter of the same name in docker_build
      entrypoint: the command to be (re-)executed when the container starts or when a live_update is run
      live_update: set of steps for updating a running container; as the parameter of the same name in docker_build
      base_suffix: suffix for naming the base image, applied as {ref}{base_suffix}
      restart_file: file that Tilt will update during a live_update to signal the entrypoint to rerun
      **kwargs: will be passed to the underlying `docker_build` call
    """

    # first, validate the given live_update steps
    if len(live_update) == 0:
        fail("`docker_build_with_restart` requires at least one live_update step")
    for step in live_update:
        if type(step) == TYPE_RESTART_CONTAINER_STEP:
            fail("`docker_build_with_restart` is not compatible with live_update step: "+
                 "`restart_container()` (this extension is meant to REPLACE restart_container() )")

    # rename the original image to make it a base image and declare a docker_build for it
    base_ref = '{}{}'.format(ref, base_suffix)
    custom_build(base_ref, command, deps, **kwargs)

    # declare a new docker build that adds a static binary of tilt-restart-wrapper
    # (which makes use of `entr` to watch files and restart processes) to the user's image
    df = '''
    FROM alpine as alpine
    RUN touch /.restart-proc

    FROM tiltdev/restart-helper:2020-10-16 as restart-helper
    FROM {}
    USER root
    COPY --from=alpine /.restart-proc {}
    COPY --from=restart-helper /tilt-restart-wrapper /
    COPY --from=restart-helper /entr /
  '''.format(base_ref, restart_file)

    # Clean kwargs for building the child image (which builds on user's specified
    # image and copies in Tilt's restart wrapper). In practice, this means removing
    # kwargs that were relevant to building the user's specified image but are NOT
    # relevant to building the child image / may conflict with args we specifically
    # pass for the child image.
    cleaned_kwargs = {k: v for k, v in kwargs.items() if k not in KWARGS_BLACKLIST}

    # Change the entrypoint to use `tilt-restart-wrapper`.
    # `tilt-restart-wrapper` makes use of `entr` (https://github.com/eradman/entr/) to
    # re-execute $entrypoint whenever $restart_file changes
    if type(entrypoint) == type(""):
        entrypoint_with_entr = ["/tilt-restart-wrapper", "--watch_file={}".format(restart_file), "sh", "-c", entrypoint]
    elif type(entrypoint) == type([]):
        entrypoint_with_entr = ["/tilt-restart-wrapper", "--watch_file={}".format(restart_file)] + entrypoint
    else:
        fail("`entrypoint` must be a string or list of strings: got {}".format(type(entrypoint)))

    # last live_update step should always be to modify $restart_file, which
    # triggers the process wrapper to rerun $entrypoint
    # NB: write `date` instead of just `touch`ing because `entr` doesn't respond
    # to timestamp changes, only writes (see https://github.com/eradman/entr/issues/32)
    live_update = live_update + [run('date > {}'.format(restart_file))]

    docker_build(ref, deps[0], entrypoint=entrypoint_with_entr, dockerfile_contents=df,
                 live_update=live_update, **cleaned_kwargs)

def bazel_build(image, target, options='', live_update_go_binary=None, live_update_go_dest=None, live_update_go_binary_rule=None):
  build_deps = str(local(BAZEL_BUILDFILES_CMD % target)).splitlines()
  watch_labels(build_deps)

  source_deps = str(local(BAZEL_SOURCES_CMD % target)).splitlines()
  source_deps_files = bazel_labels_to_files(source_deps)

  # Bazel puts the image at bazel/{dirname}, so transform
  # //snack:image -> bazel/snack:image
  dest = target.replace('//', 'bazel/')

  command = "{run_cmd} {target} -- --norun && docker tag {dest} $EXPECTED_REF".format(
    run_cmd=BAZEL_RUN_CMD, target=target, dest=dest)
  if live_update_go_binary_rule:
    local_resource(
      name='bazel-build-%s' % live_update_go_binary_rule.replace('/', '-'),
      cmd=BAZEL_BUILD_CMD + ' ' + live_update_go_binary_rule,
      deps=source_deps_files)

  if live_update_go_binary:
    custom_build(
      image,
      command=command,
      deps=[live_update_go_binary],
      live_update=[
        sync(live_update_go_binary, live_update_go_dest),
      ],
    )
  else:
    custom_build(
      image,
      command=command,
      deps=source_deps_files,
    )

k8s_yaml(bazel_k8s(":snack-server"))
#k8s_yaml(bazel_k8s(":vigoda-server"))

bazel_build('snack-image', "//snack:image", "-- --norun",
            live_update_go_binary='./bazel-bin/snack/snack_/snack',
            live_update_go_dest='/app/snack/image.binary2', # This is where bazel puts the binary in the container.
            live_update_go_binary_rule='//snack:snack')
#bazel_build('vigoda-image', "//vigoda:image", "-- --norun")

k8s_resource('snack', port_forwards=9000, resource_deps=['bazel-build---snack:snack'])
#k8s_resource('vigoda', port_forwards=9001)
