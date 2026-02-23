# Why "Run" Doesn't Work / 为什么 Run 不到

## Cause / 原因

The terminal cannot find the **Flutter** command.  
终端找不到 **Flutter** 命令，所以无法执行 `flutter run`。

(Your project and code are fine; the issue is the environment.)  
（项目和代码没问题，是环境没配置好。）

---

## Fix: Add Flutter to PATH / 解决：把 Flutter 加到 PATH

### 1. Find your Flutter path / 找到 Flutter 路径

Common locations / 常见位置：
- `D:\flutter\bin`
- `C:\flutter\bin`
- `C:\src\flutter\bin`

If you installed Flutter elsewhere, use that folder and add **\bin** at the end.  
如果你装在其他位置，用那个文件夹并在后面加 **\bin**。

### 2. Add to Windows PATH / 加到 Windows PATH

1. Press **Win**, type **环境变量** (or "environment variables"), open **编辑系统环境变量**.
2. Click **环境变量**.
3. Under **用户变量**, select **Path** → **编辑** → **新建**.
4. Add your Flutter path, for example: **`D:\flutter\bin`**
5. Click **确定** to save.
6. **Close Cursor completely and open it again** (so the new PATH is loaded).

### 3. Check in a new terminal / 在新终端里检查

Open a **new** terminal in Cursor and run:

```bash
flutter --version
```

If you see the Flutter version, PATH is correct. Then you can:

- Use **Run > Start Debugging** (F5), or  
- In terminal: `flutter run`

---

## Run from Cursor / 在 Cursor 里运行

If Flutter is already in PATH for your system (e.g. you set it before):

1. Choose a device: bottom-right device selector (e.g. Chrome, Windows, or an Android emulator).
2. Press **F5** or use **Run > Start Debugging**.
3. Or click the **Run** button (play icon) in the top bar.

If it still says "flutter" is not recognized, complete step 2 above (add Flutter to PATH and restart Cursor).

---

## Summary / 总结

| Problem        | Solution                    |
|----------------|-----------------------------|
| `flutter` not found | Add `D:\flutter\bin` (or your path) to user **Path** and restart Cursor. |
| No device      | Start an emulator or select Chrome/Windows. |
| Build errors   | Run `flutter pub get`, then `flutter run` in project folder. |

After Flutter is in PATH and Cursor is restarted, **Run** should work.
