
@test chomp(read(`$(HetaSimulator.heta_exe_path) -v`, String)) == HetaSimulator.HETA_COMPILER_VERSION
@test_throws AssertionError("The model was build with Heta compiler v0.0.1, which is not supported.\nThis HetaSimulator release includes Heta compiler v0.8.6. Please re-compile the model with HetaSimulator load_platform().") load_jlplatform("$HetaSimulatorDir/test/dummy_jlmodel.jl")