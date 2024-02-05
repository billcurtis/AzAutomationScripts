[Environment]::SetEnvironmentVariable("ORACLE_HOME", "C:\Windows\system32\oracle", "Machine");
[Environment]::SetEnvironmentVariable("PATH", "$ENV:PATH;C:\Windows\system32\oracle", "Machine");Configuration OracleEnvironmentConfig {
    Node "localhost" {
        Environment OracleHome {
            Name = "ORACLE_HOME"
            Value = "C:\Windows\system32\oracle"
            Ensure = "Present"
            Path = "Machine"
        }

        Environment OraclePath {
            Name = "PATH"
            Value = "$ENV:PATH;C:\Windows\system32\oracle"
            Ensure = "Present"
            Path = "Machine"
        }
    }
}

OracleEnvironmentConfig
