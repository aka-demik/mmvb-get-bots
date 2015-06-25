@CD /D "%~dp0"
@call "%~dp0..\..\D-ENV.cmd"
@git pull
@dub build --force
