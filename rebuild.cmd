@CD /D "%~dp0"
@call "%~dp0..\..\D-ENV.cmd"
@dub build --force
