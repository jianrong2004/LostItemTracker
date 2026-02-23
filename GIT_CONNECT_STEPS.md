# Git 连接步骤 (Git Connect Steps)

## 1. 让终端识别 Git（安装后必做）

安装 Git for Windows 后，**关闭并重新打开** Cursor/终端，这样 PATH 才会更新。

如果仍然不识别，手动添加 Git 到 PATH：

- 你的安装路径：`C:\Program Files\Git\bin`（已加入用户 PATH）
- 按 `Win + R` → 输入 `sysdm.cpl` → 高级 → 环境变量
- 在「用户变量」或「系统变量」里找到 **Path** → 编辑 → 新建
- 添加：`C:\Program Files\Git\bin`
- 确定保存，**重新打开** Cursor/终端

## 2. 本仓库已连接的远程

- 远程名称：`origin`
- 地址：`https://github.com/jianrong2004/LostItemTracker.git`
- 分支：`master` 已跟踪 `origin/master`

无需再添加远程，连接已存在。

## 3. 验证连接

在项目目录 `D:\LostItemTracker-1` 打开终端，执行：

```bash
git --version
git remote -v
git status
```

若需测试与 GitHub 的网络连接：

```bash
git fetch origin
```

## 4. 登录 GitHub（推送/拉取时）

- 使用 **HTTPS** 时，第一次 `git push` 或 `git pull` 会提示登录
- 推荐：用 **Personal Access Token** 代替密码  
  - GitHub → Settings → Developer settings → Personal access tokens → 生成 token
  - 在提示输入密码时粘贴 token
- 或使用 **SSH**：  
  - 生成密钥：`ssh-keygen -t ed25519 -C "your_email@example.com"`  
  - 把公钥加到 GitHub → Settings → SSH and GPG keys  
  - 然后：`git remote set-url origin git@github.com:jianrong2004/LostItemTracker.git`

## 5. 常用命令

```bash
git status          # 查看状态
git pull origin     # 拉取最新
git push origin     # 推送
```

完成以上步骤后，Git 即可在终端使用并与 GitHub 连接。
