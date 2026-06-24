# Codex 配置保护脚本 - 防止切换配置后 MCP 和会话丢失
# 使用方法: 在 Codex 切换配置后运行此脚本恢复

$codexDir = "$env:USERPROFILE\.codex"
$configPath = Join-Path $codexDir "config.toml"
$backupDir = Join-Path $codexDir "config-backups"
$logFile = Join-Path $codexDir "protect-config.log"

# 必需的关键配置段落
$requiredSections = @(
    "[mcp_servers.matlab]",
    "[marketplaces.claude-mem-local]",
    "[marketplaces.openai-primary-runtime]",
    '[plugins."claude-mem@claude-mem-local"]',
    "[features]",
    "[hooks.state]",
    "[memories]"
)

# 创建备份目录
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

function Write-Log {
    param([string]$msg)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg" | Out-File $logFile -Append -Encoding UTF8
}

function Backup-Config {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path $backupDir "config.toml.$timestamp"
    Copy-Item $configPath $backupFile -Force
    Write-Log "备份: $backupFile"
    Write-Host "已备份配置到: $backupFile" -ForegroundColor Green
    return $backupFile
}

function Test-ConfigIntegrity {
    if (-not (Test-Path $configPath)) {
        Write-Log "错误: config.toml 不存在"
        return $false
    }
    $content = Get-Content $configPath -Raw
    $missing = @()
    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $missing += $section
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host "缺失配置段落:" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Log "检测到缺失: $($missing -join ', ')"
        return $false
    }
    Write-Host "配置完整性检查通过" -ForegroundColor Green
    Write-Log "配置完整性检查通过"
    return $true
}

function Restore-FromLatest {
    $latest = Get-ChildItem $backupDir -Filter "config.toml.*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host "没有找到备份文件" -ForegroundColor Red
        Write-Log "恢复失败: 无备份"
        return $false
    }
    Copy-Item $latest.FullName $configPath -Force
    Write-Host "已从备份恢复: $($latest.Name)" -ForegroundColor Green
    Write-Log "已从备份恢复: $($latest.Name)"
    return $true
}

function Protect-Config {
    Write-Host "=== Codex 配置保护 ===" -ForegroundColor Cyan
    
    # 1. 先备份当前配置
    Backup-Config
    
    # 2. 检查完整性
    $ok = Test-ConfigIntegrity
    
    if (-not $ok) {
        Write-Host "`n配置不完整，尝试从最近备份恢复..." -ForegroundColor Yellow
        if (Restore-FromLatest) {
            Write-Host "恢复完成，请重启 Codex" -ForegroundColor Green
        }
    }
}

# 运行
Protect-Config
