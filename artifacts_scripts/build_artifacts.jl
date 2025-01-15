using ArtifactUtils
using Pkg.Artifacts

const HETA_COMPILER_RELEASE = "v0.9.3"

const artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

platforms = [
  Artifacts.Platform("x86_64", "linux"),
  Artifacts.Platform("x86_64", "windows"),
  Artifacts.Platform("x86_64", "macos"),
  Artifacts.Platform("aarch64", "macos")
]

for platform in platforms

  os  = platform.tags["os"]
  url = "https://github.com/hetalang/heta-compiler/releases/download/$HETA_COMPILER_RELEASE/heta-compiler-$os.tar.gz"

  add_artifact!(
      artifacts_toml,
      "heta_app",
      url;
      platform,
      force = true,
      lazy = false,
  )
end
