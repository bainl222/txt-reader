# 读取 pubspec.yaml
$content = Get-Content pubspec.yaml
$versionLine = $content | Select-String -Pattern "^version:"
$currentVersion = $versionLine.Line.Split(" ")[1]
$versionParts = $currentVersion.Split("+")
$versionName = $versionParts[0]
$buildNumber = [int]$versionParts[1]

# 构建号 +1
$newBuildNumber = $buildNumber + 1
$newVersion = "$versionName+$newBuildNumber"

# 写入新版本号
$content = $content -replace "^version:.*", "version: $newVersion"
Set-Content pubspec.yaml -Value $content

Write-Host "版本号已更新为: $newVersion" -ForegroundColor Green
Write-Host "开始打包..." -ForegroundColor Cyan

# 执行打包命令
flutter build apk --release