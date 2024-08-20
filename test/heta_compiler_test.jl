
@test chomp(read(`$(HetaSimulator.heta_exe_path) -v`, String)) == HetaSimulator.HETA_COMPILER_VERSION