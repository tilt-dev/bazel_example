load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

k8s_object(
  name = "vigoda-server",
  kind = "deployment",

  # A template of a Kubernetes Deployment object yaml.
  template = ":deploy/vigoda.yaml",

  cluster = "docker-for-desktop-cluster",
)

k8s_object(
  name = "snack-server",
  kind = "deployment",

  # A template of a Kubernetes Deployment object yaml.
  template = ":deploy/snack.yaml",

  cluster = "docker-for-desktop-cluster",

  images = {
    "gcr.io/windmill-public-containers/snack": "//snack:image",
  }
)

k8s_object(
  name = "snack-server-dev",
  kind = "deployment",

  # A template of a Kubernetes Deployment object yaml.
  template = ":deploy/snack.yaml",

  cluster = "docker-for-desktop-cluster",
)
