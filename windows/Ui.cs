using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace OtterBlink
{
    class Settings
    {
        public Color ReadColor = Color.FromArgb(0xff, 0x2a, 0x2a);
        public Color WriteColor = Color.FromArgb(0x2a, 0xe0, 0x2a);
        public Color RxColor = Color.FromArgb(0x2a, 0x9d, 0xff);
        public Color TxColor = Color.FromArgb(0xff, 0xb0, 0x20);
        public int OffBrightness = 20;
        public int Interval = 100;
        public int Hold = 80;
        public bool ShowNetwork = true;

        static string Dir
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OtterBlink"); }
        }
        static string FilePath { get { return Path.Combine(Dir, "settings.txt"); } }

        public Settings Clone() { return (Settings)MemberwiseClone(); }

        static string Hex(Color c) { return string.Format("#{0:X2}{1:X2}{2:X2}", c.R, c.G, c.B); }

        public static Settings Load()
        {
            var s = new Settings();
            try
            {
                if (!File.Exists(FilePath)) return s;
                foreach (var line in File.ReadAllLines(FilePath))
                {
                    int i = line.IndexOf('=');
                    if (i < 0) continue;
                    string k = line.Substring(0, i).Trim();
                    string v = line.Substring(i + 1).Trim();
                    switch (k)
                    {
                        case "ReadColor": s.ReadColor = ColorTranslator.FromHtml(v); break;
                        case "WriteColor": s.WriteColor = ColorTranslator.FromHtml(v); break;
                        case "RxColor": s.RxColor = ColorTranslator.FromHtml(v); break;
                        case "TxColor": s.TxColor = ColorTranslator.FromHtml(v); break;
                        case "OffBrightness": s.OffBrightness = int.Parse(v); break;
                        case "Interval": s.Interval = int.Parse(v); break;
                        case "Hold": s.Hold = int.Parse(v); break;
                        case "ShowNetwork": s.ShowNetwork = v == "true"; break;
                    }
                }
            }
            catch { }
            return s;
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Dir);
                File.WriteAllLines(FilePath, new[]
                {
                    "ReadColor=" + Hex(ReadColor),
                    "WriteColor=" + Hex(WriteColor),
                    "RxColor=" + Hex(RxColor),
                    "TxColor=" + Hex(TxColor),
                    "OffBrightness=" + OffBrightness,
                    "Interval=" + Interval,
                    "Hold=" + Hold,
                    "ShowNetwork=" + (ShowNetwork ? "true" : "false")
                });
            }
            catch { }
        }
    }

    static class Startup
    {
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string Name = "OtterBlink";

        public static bool Enabled
        {
            get
            {
                using (var k = Registry.CurrentUser.OpenSubKey(RunKey))
                    return k != null && k.GetValue(Name) != null;
            }
        }

        public static void Set(bool on)
        {
            using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
            {
                if (on) k.SetValue(Name, "\"" + Application.ExecutablePath + "\"");
                else k.DeleteValue(Name, false);
            }
        }
    }

    static class LedIcon
    {
        [DllImport("user32.dll")]
        static extern bool DestroyIcon(IntPtr handle);

        public static Icon Make(Color[] colors, bool[] lit, int cols, int offPercent)
        {
            int s = SystemInformation.SmallIconSize.Width;
            int rows = (colors.Length + cols - 1) / cols;
            float cell = s / (float)Math.Max(cols, rows);
            float d = cell * 0.86f;
            float ox = (s - cell * cols) / 2f;
            float oy = (s - cell * rows) / 2f;
            float f = offPercent / 100f;

            using (var bmp = new Bitmap(s, s))
            {
                using (var g = Graphics.FromImage(bmp))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.Clear(Color.Transparent);
                    for (int i = 0; i < colors.Length; i++)
                    {
                        Color c = colors[i];
                        Color fill = lit[i] ? c : Color.FromArgb((int)(c.R * f), (int)(c.G * f), (int)(c.B * f));
                        float x = ox + (i % cols) * cell + (cell - d) / 2f;
                        float y = oy + (i / cols) * cell + (cell - d) / 2f;
                        using (var b = new SolidBrush(fill)) g.FillEllipse(b, x, y, d, d);
                        using (var p = new Pen(ControlPaint.Dark(c, 0.5f))) g.DrawEllipse(p, x, y, d, d);
                    }
                }
                IntPtr h = bmp.GetHicon();
                Icon ico = (Icon)Icon.FromHandle(h).Clone();
                DestroyIcon(h);
                return ico;
            }
        }
    }

    class RatesForm : Form
    {
        readonly Label text = new Label();

        public RatesForm()
        {
            Text = "Otter Blink";
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            text.AutoSize = true;
            text.Font = new Font("Consolas", 10f);
            text.Padding = new Padding(10);
            Controls.Add(text);
            Deactivate += (s, e) => Hide();
            FormClosing += (s, e) =>
            {
                if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); }
            };
        }

        static string Row(string name, double rate)
        {
            return "  " + name.PadRight(10) + TrayApp.Fmt(rate).PadLeft(13);
        }

        public void UpdateRates(double[] r, bool net)
        {
            var sb = new StringBuilder();
            sb.AppendLine("Disk");
            sb.AppendLine(Row("Read", r[0]));
            sb.AppendLine(Row("Write", r[1]));
            if (net)
            {
                sb.AppendLine("Ethernet");
                sb.AppendLine(Row("Download", r[2]));
                sb.AppendLine(Row("Upload", r[3]));
                sb.AppendLine("Wi-Fi");
                sb.AppendLine(Row("Download", r[4]));
                sb.AppendLine(Row("Upload", r[5]));
            }
            text.Text = sb.ToString().TrimEnd();
            ClientSize = text.PreferredSize;
        }

        public void ShowNear()
        {
            Point c = Cursor.Position;
            Rectangle wa = Screen.FromPoint(c).WorkingArea;
            int x = Math.Max(wa.Left, Math.Min(c.X - Width / 2, wa.Right - Width));
            int y = c.Y >= wa.Bottom ? wa.Bottom - Height : (c.Y < wa.Top ? wa.Top : c.Y - Height);
            y = Math.Max(wa.Top, Math.Min(y, wa.Bottom - Height));
            Location = new Point(x, y);
            Show();
            Activate();
        }
    }

    class SettingsForm : Form
    {
        public readonly Settings Result;
        readonly TableLayoutPanel table = new TableLayoutPanel();

        public SettingsForm(Settings current)
        {
            Result = current.Clone();
            Text = "Otter Blink Settings";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Padding = new Padding(10);

            table.ColumnCount = 2;
            table.AutoSize = true;
            table.Dock = DockStyle.Fill;

            AddColor("Disk read color", () => Result.ReadColor, c => Result.ReadColor = c);
            AddColor("Disk write color", () => Result.WriteColor, c => Result.WriteColor = c);
            AddColor("Network receive color", () => Result.RxColor, c => Result.RxColor = c);
            AddColor("Network transmit color", () => Result.TxColor, c => Result.TxColor = c);
            var off = AddNumber("Off brightness (%)", 0, 100, Result.OffBrightness);
            var interval = AddNumber("Poll interval (ms)", 20, 2000, Result.Interval);
            var hold = AddNumber("Blink duration (ms)", 0, 1000, Result.Hold);

            var net = new CheckBox { Text = "Show network icon", Checked = Result.ShowNetwork, AutoSize = true };
            var startup = new CheckBox { Text = "Start with Windows", Checked = Startup.Enabled, AutoSize = true };
            AddWide(net);
            AddWide(startup);

            var ok = new Button { Text = "OK", DialogResult = DialogResult.OK };
            var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel };
            var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill };
            buttons.Controls.Add(cancel);
            buttons.Controls.Add(ok);
            AddWide(buttons);

            Controls.Add(table);
            AcceptButton = ok;
            CancelButton = cancel;

            FormClosing += (s, e) =>
            {
                if (DialogResult != DialogResult.OK) return;
                Result.OffBrightness = (int)off.Value;
                Result.Interval = (int)interval.Value;
                Result.Hold = (int)hold.Value;
                Result.ShowNetwork = net.Checked;
                try { Startup.Set(startup.Checked); } catch { }
            };
        }

        void AddWide(Control c)
        {
            table.Controls.Add(c);
            table.SetColumnSpan(c, 2);
        }

        void AddColor(string label, Func<Color> get, Action<Color> set)
        {
            table.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left });
            var b = new Button { Width = 60, BackColor = get(), FlatStyle = FlatStyle.Flat };
            b.Click += (s, e) =>
            {
                using (var d = new ColorDialog { Color = get(), FullOpen = true })
                {
                    if (d.ShowDialog(this) == DialogResult.OK)
                    {
                        set(d.Color);
                        b.BackColor = d.Color;
                    }
                }
            };
            table.Controls.Add(b);
        }

        NumericUpDown AddNumber(string label, int min, int max, int value)
        {
            table.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left });
            var n = new NumericUpDown { Minimum = min, Maximum = max, Width = 80 };
            n.Value = Math.Max(min, Math.Min(max, value));
            table.Controls.Add(n);
            return n;
        }
    }
}
