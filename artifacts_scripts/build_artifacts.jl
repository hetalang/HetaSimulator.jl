using ArtifactUtils
using Pkg.Artifacts

const HETA_COMPILER_RELEASE = "v0.8.6"

const artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

for os in ("linux", "windows", "macos")

  url = "https://github.com/hetalang/heta-compiler/releases/download/$HETA_COMPILER_RELEASE/heta-compiler-$os.tar.gz"
  platform = Artifacts.Platform("x86_64", os)

  add_artifact!(
      artifacts_toml,
      "heta_app",
      url;
      platform,
      force = true,
      lazy = false,
  )
end
