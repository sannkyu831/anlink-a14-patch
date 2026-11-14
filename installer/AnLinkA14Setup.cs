// SPDX-License-Identifier: MIT
using System;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using Microsoft.Win32;

static class AnLinkA14Setup
{
    const string PayloadName = "anlink_payload";
    const string SetupName = "anlink_setup";
    const string TargetName = "an-link";
    const string BackupName = "an-link.orig-310";

    static Form form;
    static TextBox logBox;
    static Button btnFull, btnPatch, btnRestore;
    static Label status;
    static string logFile;
    static bool busy;
    static bool hasSetup;
    static string currentDir;

    [STAThread]
    static void Main(string[] args)
    {
        logFile = Path.Combine(Path.GetTempPath(), "anlink-a14-setup.log");
        hasSetup = ReadResource(SetupName) != null;

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        form = new Form();
        form.Text = "AnLink Android 14+ 兼容补丁";
        form.ClientSize = new Size(560, 450);
        form.FormBorderStyle = FormBorderStyle.FixedDialog;
        form.MaximizeBox = false;
        form.StartPosition = FormStartPosition.CenterScreen;
        try { form.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

        Label title = new Label();
        title.Text = "AnLink Android 14+ 兼容补丁";
        title.Font = new Font("Microsoft YaHei UI", 14F, FontStyle.Bold);
        title.SetBounds(20, 16, 520, 30);
        form.Controls.Add(title);

        Label sub = new Label();
        sub.Text = "修复 AnLink 在 Android 14 / 15 / 16 上的投屏、控制和息屏控制（替换手机端 an-link 服务端）";
        sub.ForeColor = Color.DimGray;
        sub.SetBounds(20, 50, 520, 34);
        form.Controls.Add(sub);

        logBox = new TextBox();
        logBox.Multiline = true;
        logBox.ReadOnly = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.BackColor = Color.White;
        logBox.Font = new Font("Consolas", 9F);
        logBox.SetBounds(20, 92, 520, 248);
        form.Controls.Add(logBox);

        status = new Label();
        status.Text = "就绪";
        status.ForeColor = Color.DimGray;
        status.SetBounds(20, 346, 520, 20);
        form.Controls.Add(status);

        int by = 368;
        if (hasSetup)
        {
            btnFull = MakeButton("重新安装 AnLink 并打补丁", 20, by, 220);
            btnFull.Click += delegate { Run(true); };
            form.Controls.Add(btnFull);
            btnPatch = MakeButton("仅打补丁", 252, by, 110);
            btnPatch.Click += delegate { Run(false); };
            form.Controls.Add(btnPatch);
        }
        else
        {
            btnPatch = MakeButton("安装补丁", 20, by, 200);
            btnPatch.Click += delegate { Run(false); };
            form.Controls.Add(btnPatch);
        }

        btnRestore = MakeButton("还原官方版本", 20, 406, 130);
        btnRestore.Click += delegate { Restore(); };
        form.Controls.Add(btnRestore);

        Button btnPick = MakeButton("手动选择安装目录", 162, 406, 150);
        btnPick.Click += delegate { PickDir(); };
        form.Controls.Add(btnPick);

        Button close = MakeButton("退出", 456, by, 84);
        close.Click += delegate { if (!busy) form.Close(); };
        form.Controls.Add(close);

        AppendLog("AnLink 版本 3.10（官方 an-link 服务端基于 scrcpy 1.25）");
        AppendLog("补丁 v1.2：Android 15 真机验证版，修复息屏控制路径。");
        AppendLog("Android 14 移除了 SurfaceControl 虚拟显示事务 API，导致投屏失败。");
        AppendLog("本补丁改为使用 DisplayManager.createVirtualDisplay() 通道。");
        AppendLog("Android 14 同时移动了物理显示电源 API，息屏控制改走 DisplayControl。");
        AppendLog("");
        currentDir = FindAnLinkDir();
        if (currentDir == null)
        {
            AppendLog("未自动检测到 AnLink。");
            AppendLog("如果你把 AnLink 装在其它盘（例如 D 盘），请点下面的“手动选择安装目录”。");
        }
        else
        {
            AppendLog("检测到 AnLink: " + currentDir);
            SaveLastDir(currentDir);
        }
        AppendLog("");

        Application.Run(form);
    }

    static Button MakeButton(string text, int x, int y, int w)
    {
        Button b = new Button();
        b.Text = text;
        b.SetBounds(x, y, w, 32);
        b.FlatStyle = FlatStyle.System;
        return b;
    }

    static void SetBusy(bool v)
    {
        busy = v;
        if (btnFull != null) btnFull.Enabled = !v;
        if (btnPatch != null) btnPatch.Enabled = !v;
        if (btnRestore != null) btnRestore.Enabled = !v;
    }

    static void AppendLog(string line)
    {
        if (logBox.InvokeRequired)
        {
            logBox.Invoke((MethodInvoker)delegate { AppendLog(line); });
            return;
        }
        logBox.AppendText(line + Environment.NewLine);
        try { File.AppendAllText(logFile, line + Environment.NewLine, Encoding.UTF8); } catch { }
    }

    static void SetStatus(string s)
    {
        if (status.InvokeRequired) { status.Invoke((MethodInvoker)delegate { SetStatus(s); }); return; }
        status.Text = s;
    }

    static void Run(bool withSetup)
    {
        if (busy) return;
        SetBusy(true);
        Thread t = new Thread(delegate ()
        {
            try
            {
                string dir = withSetup ? InstallWithSetup() : (currentDir != null ? currentDir : FindAnLinkDir());
                if (dir == null)
                {
                    AppendLog("[X] 没有找到已安装的 AnLink，请先安装。");
                    return;
                }
                ApplyPatch(dir);
            }
            catch (Exception ex)
            {
                AppendLog("[X] 出错: " + ex.Message);
            }
            finally
            {
                SetBusy(false);
                SetStatus("完成");
                AppendLog("");
                AppendLog("日志已保存: " + logFile);
            }
        });
        t.IsBackground = true;
        t.Start();
    }

    static string InstallWithSetup()
    {
        byte[] setup = ReadResource(SetupName);
        if (setup == null)
        {
            AppendLog("[!] 本程序未内置安装器，改为直接打补丁。");
            return FindAnLinkDir();
        }
        string tmp = Path.Combine(Path.GetTempPath(), "anlink-a14-setup");
        Directory.CreateDirectory(tmp);
        string setupExe = Path.Combine(tmp, "AnLinkSetup.exe");
        if (!File.Exists(setupExe) || new FileInfo(setupExe).Length != setup.Length)
        {
            SetStatus("释放安装器 ...");
            File.WriteAllBytes(setupExe, setup);
        }

        SetStatus("等待安装器完成 ...");
        AppendLog("[1/4] 启动 AnLink 官方安装器，请在窗口里点 “Install Now”");
        DateTime start = DateTime.UtcNow;
        ProcessStartInfo psi = new ProcessStartInfo(setupExe);
        psi.WorkingDirectory = tmp;
        psi.UseShellExecute = true;
        Process.Start(psi);

        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AnLink");
        string link = Path.Combine(dir, TargetName);
        DateTime deadline = DateTime.Now.AddMinutes(20);
        bool seen = false;
        int stable = 0;
        long lastSize = -1;
        while (DateTime.Now < deadline)
        {
            Thread.Sleep(700);
            using (Process cur = FindProc("AnLinkSetup"))
            {
                if (cur != null) seen = true;
                if (seen && cur == null) break;
            }
            if (File.Exists(link))
            {
                DateTime w = File.GetLastWriteTimeUtc(link);
                if (w >= start.AddSeconds(-1))
                {
                    long size = new FileInfo(link).Length;
                    if (size == lastSize) stable++; else { stable = 0; lastSize = size; }
                    if (stable >= 2) break;
                }
            }
        }
        Thread.Sleep(1500);
        if (!File.Exists(Path.Combine(dir, "AnLink.exe")))
        {
            AppendLog("[X] 安装似乎没有完成（没找到 AnLink.exe）。");
            return null;
        }
        AppendLog("      安装器已完成");
        return dir;
    }

    static Process FindProc(string name)
    {
        Process[] ps = Process.GetProcessesByName(name);
        if (ps.Length == 0) return null;
        return ps[0];
    }

    static bool IsAnLinkPatched(string path)
    {
        try
        {
            using (FileStream fs = File.OpenRead(path))
            using (ZipArchive zip = new ZipArchive(fs, ZipArchiveMode.Read))
            {
                ZipArchiveEntry entry = zip.GetEntry("classes.dex");
                if (entry == null) return false;
                byte[] marker = Encoding.ASCII.GetBytes("anlink-display:");
                using (Stream dex = entry.Open())
                {
                    int matched = 0;
                    int value;
                    while ((value = dex.ReadByte()) >= 0)
                    {
                        if (value == marker[matched])
                        {
                            matched++;
                            if (matched == marker.Length) return true;
                        }
                        else
                        {
                            matched = value == marker[0] ? 1 : 0;
                        }
                    }
                }
            }
        }
        catch { }
        return false;
    }

    static void ApplyPatch(string dir)
    {
        string target = Path.Combine(dir, TargetName);
        string backup = Path.Combine(dir, BackupName);
        string exe = Path.Combine(dir, "AnLink.exe");

        if (!File.Exists(target))
        {
            AppendLog("[X] 目录里没有 an-link，AnLink 版本可能不符。");
            return;
        }
        byte[] payload = ReadResource(PayloadName);
        if (payload == null)
        {
            AppendLog("[X] 补丁数据损坏。");
            return;
        }
        string want = Sha256(payload);

        SetStatus("备份原始服务端 ...");
        if (!File.Exists(backup))
        {
            KillAnLink();
            if (IsAnLinkPatched(target))
            {
                string safety = target + ".before-update-" + DateTime.Now.ToString("yyyyMMdd-HHmmss");
                File.Copy(target, safety, true);
                AppendLog("[1/4] 当前已是补丁版，未覆盖官方备份");
                AppendLog("      安全副本 -> " + Path.GetFileName(safety));
            }
            else
            {
                File.Copy(target, backup, true);
                AppendLog("[1/4] 已备份官方服务端 -> " + BackupName);
            }
        }
        else
        {
            AppendLog("[1/4] 备份已存在，保留");
            if (IsAnLinkPatched(backup))
            {
                AppendLog("      [!] 该备份本身是补丁版，不可当作官方版本还原");
            }
        }

        SetStatus("写入补丁 ...");
        AppendLog("[2/4] 关闭 AnLink 并写入修复后的服务端 ...");
        KillAnLink();
        for (int i = 0; i < 6; i++)
        {
            try { File.WriteAllBytes(target, payload); break; }
            catch { if (i == 5) throw; Thread.Sleep(600); }
        }

        SetStatus("校验 ...");
        string now = Sha256(File.ReadAllBytes(target));
        if (now != want)
        {
            AppendLog("[X] 校验失败，请点“还原官方版本”后重试。");
            return;
        }
        AppendLog("      校验通过 SHA256 " + now.Substring(0, 16) + "...");

        AppendLog("[3/4] 启动 AnLink ...");
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo(exe);
            psi.WorkingDirectory = dir;
            psi.UseShellExecute = true;
            Process.Start(psi);
        }
        catch (Exception ex) { AppendLog("      启动失败: " + ex.Message); }

        AppendLog("[4/4] 完成");
        AppendLog("");
        AppendLog("[√] 补丁已安装。现在连接手机（开启 USB 调试）即可。");
        AppendLog("    Android 14+ 的投屏走 DisplayManager，息屏控制走 DisplayControl。");
    }

    static void Restore()
    {
        if (busy) return;
        SetBusy(true);
        Thread t = new Thread(delegate ()
        {
            try
            {
                string dir = currentDir != null ? currentDir : FindAnLinkDir();
                if (dir == null) { AppendLog("[X] 没找到 AnLink。"); return; }
                string target = Path.Combine(dir, TargetName);
                string backup = Path.Combine(dir, BackupName);
                if (!File.Exists(backup)) { AppendLog("[X] 没有备份文件，无法还原。"); return; }
                if (IsAnLinkPatched(backup))
                {
                    AppendLog("[X] 备份是补丁版，不是官方 3.10；请用官方安装器重装后再打补丁。");
                    return;
                }
                SetStatus("还原中 ...");
                AppendLog("[1/3] 关闭 AnLink ...");
                KillAnLink();
                AppendLog("[2/3] 还原官方服务端 ...");
                File.Copy(backup, target, true);
                AppendLog("      完成 (" + new FileInfo(target).Length + " 字节)");
                AppendLog("[3/3] 启动 AnLink ...");
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(dir, "AnLink.exe"));
                    psi.WorkingDirectory = dir;
                    psi.UseShellExecute = true;
                    Process.Start(psi);
                }
                catch { }
                AppendLog("");
                AppendLog("[√] 已还原为官方 3.10 服务端。");
            }
            catch (Exception ex) { AppendLog("[X] 出错: " + ex.Message); }
            finally { SetBusy(false); SetStatus("完成"); }
        });
        t.IsBackground = true;
        t.Start();
    }

    static string FindAnLinkDir()
    {
        string remembered = LoadLastDir();
        if (IsAnLinkDir(remembered)) return remembered;

        string[] candidates = new string[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AnLink"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AnLink"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AnLink"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "AnLink")
        };
        foreach (string c in candidates)
        {
            if (IsAnLinkDir(c)) return c;
        }

        string reg = FindFromRegistry();
        if (IsAnLinkDir(reg)) return reg;

        return ScanDrives();
    }

    static bool IsAnLinkDir(string dir)
    {
        if (dir == null || dir.Length == 0) return false;
        try
        {
            return File.Exists(Path.Combine(dir, "AnLink.exe")) && File.Exists(Path.Combine(dir, TargetName));
        }
        catch { return false; }
    }

    static string FindFromRegistry()
    {
        string[] roots = new string[]
        {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        };
        RegistryKey[] hives = new RegistryKey[] { Registry.CurrentUser, Registry.LocalMachine };
        foreach (RegistryKey hive in hives)
        {
            foreach (string r in roots)
            {
                try
                {
                    using (RegistryKey k = hive.OpenSubKey(r))
                    {
                        if (k == null) continue;
                        foreach (string sub in k.GetSubKeyNames())
                        {
                            using (RegistryKey app = k.OpenSubKey(sub))
                            {
                                if (app == null) continue;
                                object name = app.GetValue("DisplayName");
                                if (name == null || name.ToString().IndexOf("AnLink", StringComparison.OrdinalIgnoreCase) < 0) continue;
                                string[] keys = new string[] { "InstallLocation", "DisplayIcon", "UninstallString", "DisplayName" };
                                foreach (string kn in keys)
                                {
                                    object v = app.GetValue(kn);
                                    if (v == null) continue;
                                    string dir = DirFromValue(v.ToString());
                                    if (IsAnLinkDir(dir)) return dir;
                                }
                            }
                        }
                    }
                }
                catch { }
            }
        }
        return null;
    }

    // 把 InstallLocation / DisplayIcon / UninstallString 统一转成目录
    static string DirFromValue(string v)
    {
        if (v == null) return null;
        v = v.Trim();
        if (v.Length == 0) return null;

        if (v.StartsWith("\""))
        {
            int q = v.IndexOf('"', 1);
            if (q > 1) v = v.Substring(1, q - 1);
        }
        else
        {
            int comma = v.IndexOf(',');
            if (comma > 0 && v.IndexOf(".exe", StringComparison.OrdinalIgnoreCase) < comma)
                v = v.Substring(0, comma);
            int exe = v.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
            if (exe > 0) v = v.Substring(0, exe + 4);
        }
        v = v.Trim();

        try
        {
            if (Directory.Exists(v)) return v;
            string parent = Path.GetDirectoryName(v);
            if (parent != null && Directory.Exists(parent)) return parent;
        }
        catch { }
        return null;
    }

    static string ScanDrives()
    {
        string[] skip = new string[] { "windows", "$recycle.bin", "system volume information", "programdata",
                                       "recovery", "perflogs", "node_modules", "appdata", "winsxs", "msocache" };
        try
        {
            DriveInfo[] drives = DriveInfo.GetDrives();
            foreach (DriveInfo d in drives)
            {
                try
                {
                    if (d.DriveType != DriveType.Fixed || !d.IsReady) continue;
                }
                catch { continue; }
                SetStatus("扫描 " + d.Name + " ...");
                string hit = ScanDir(d.RootDirectory.FullName, 0, skip);
                if (hit != null) return hit;
            }
        }
        catch { }
        return null;
    }

    static string ScanDir(string dir, int depth, string[] skip)
    {
        if (depth > 3) return null;
        if (IsAnLinkDir(dir)) return dir;
        string[] subs;
        try { subs = Directory.GetDirectories(dir); }
        catch { return null; }

        foreach (string sub in subs)
        {
            string name = Path.GetFileName(sub);
            if (name == null) continue;
            string low = name.ToLowerInvariant();
            bool bad = false;
            foreach (string s in skip) { if (low == s) { bad = true; break; } }
            if (bad) continue;
            string hit = ScanDir(sub, depth + 1, skip);
            if (hit != null) return hit;
        }
        return null;
    }

    static string LastDirFile()
    {
        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AnLinkA14Patch");
        try { Directory.CreateDirectory(dir); } catch { }
        return Path.Combine(dir, "lastdir.txt");
    }

    static string LoadLastDir()
    {
        try
        {
            string f = LastDirFile();
            if (File.Exists(f)) return File.ReadAllText(f).Trim();
        }
        catch { }
        return null;
    }

    static void SaveLastDir(string dir)
    {
        try { File.WriteAllText(LastDirFile(), dir); } catch { }
    }

    static void PickDir()
    {
        if (busy) return;
        using (FolderBrowserDialog dlg = new FolderBrowserDialog())
        {
            dlg.Description = "请选择 AnLink 的安装目录（里面有 AnLink.exe 的那个文件夹）";
            dlg.ShowNewFolderButton = false;
            if (dlg.ShowDialog(form) != DialogResult.OK) return;
            string dir = dlg.SelectedPath;
            if (!File.Exists(Path.Combine(dir, "AnLink.exe")))
            {
                MessageBox.Show("这个目录里没有 AnLink.exe，请重新选择。", "目录不对", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (!File.Exists(Path.Combine(dir, TargetName)))
            {
                MessageBox.Show("这个目录里没有 an-link 文件，AnLink 版本可能不匹配（需要 3.10）。", "目录不对", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            currentDir = dir;
            SaveLastDir(dir);
            AppendLog("已手动指定 AnLink 目录: " + dir);
            SetStatus("就绪");
        }
    }

    static void KillAnLink()
    {
        try
        {
            Process[] ps = Process.GetProcessesByName("AnLink");
            foreach (Process p in ps) { try { p.Kill(); p.WaitForExit(4000); } catch { } }
            if (ps.Length > 0) Thread.Sleep(900);
        }
        catch { }
    }

    static byte[] ReadResource(string name)
    {
        Assembly asm = Assembly.GetExecutingAssembly();
        using (Stream s = asm.GetManifestResourceStream(name))
        {
            if (s == null) return null;
            byte[] buf = new byte[s.Length];
            int off = 0;
            while (off < buf.Length)
            {
                int n = s.Read(buf, off, buf.Length - off);
                if (n <= 0) break;
                off += n;
            }
            return buf;
        }
    }

    static string Sha256(byte[] data)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] h = sha.ComputeHash(data);
            StringBuilder sb = new StringBuilder();
            foreach (byte b in h) sb.Append(b.ToString("X2"));
            return sb.ToString();
        }
    }
}
