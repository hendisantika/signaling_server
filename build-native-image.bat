@echo off
setlocal enableextensions enabledelayedexpansion

:: NOTE: you first need to build the project and generate the WAR artifact targeting Java 8. Update pom.xml.
 
if "%GRAALVM_HOME%"=="" (
	echo Variable GRAALVM_HOME is NOT defined
	exit /b
)

:: download spring-boot-graal-feature and build it as jar
echo :::::::: Download spring-boot-graal-feature
git clone --single-branch --branch graal_19_2_0_dev https://github.com/aclement/spring-boot-graal-feature.git target/spring-boot-graal-feature

echo :::::::: Building spring-boot-graal-feature
cd target/spring-boot-graal-feature
call mvn clean package
cd ..\..

set WAR=signaling.war
set IMAGE_NAME=signaling

:: decompress war file to get a classpath with jars and classes
echo :::::::: Decompressing %WAR% file to build a classpath with jars and classes
rmdir /Q /S target\graal-build > NUL 2>&1
mkdir target\graal-build
cd target\graal-build
jar -xf ../%WAR%

:: build classpath with all jars and classes
cd WEB-INF\classes
set LIBPATH_1=
set LIBPATH_2=
for /r "..\lib" %%i in (*.jar) do set LIBPATH_1=!LIBPATH_1!%%i;
for /r "..\lib-provided" %%i in (*.jar) do set LIBPATH_2=!LIBPATH_2!%%i;
set CP=%CD%;%LIBPATH_1%;%LIBPATH_2%

:: go back to graal-build folder
cd ..\..

:: spring-boot-graal-feature jar being on the classpath is what triggers the Spring Boot graal auto configuration.
:: we need to list only the exact jar since there is another one in test-classes
del /F /Q features_jar.txt > NUL 2>&1
dir /S /B ..\spring-boot-graal-feature\target\spring-boot-graal-feature-0.5.0.BUILD-SNAPSHOT.jar > features_jar.txt
set FEATURES_JAR=
for /f %%i in (features_jar.txt) do set FEATURES_JAR=%%i;
set CP=%CP%;%FEATURES_JAR%

:: compile with graal native-image
echo :::::::: Compiling with graal native-image
call %GRAALVM_HOME%\bin\native-image ^
  -J-Xmx4000m ^
  -H:+ReportExceptionStackTraces ^
  -H:+TraceClassInitialization ^
  -Dio.netty.noUnsafe=true ^
  -H:Name=%IMAGE_NAME% ^
  -H:IncludeResources=".*.properties|.*.jks|.*.key|.*.xml|.*.js|.*.html|.*.jsp" ^
  --no-fallback ^
  --allow-incomplete-classpath ^
  --report-unsupported-elements-at-runtime ^
  -cp %CP% -jar ..\%WAR%
  
if %ERRORLEVEL% == 0 (
	echo :::::::: Native image located at target\graal-build\
) else (
	echo :::::::: Failed!
)

:: let's go back to project base dir
cd ..\..

exit /b
