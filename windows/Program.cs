using System;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using System.Threading;
using System.Windows.Forms;

namespace OtterBlink
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            bool first;
            using (var mutex = new Mutex(true, "OtterBlink.SingleInstance", out first))
            {
                if (!first) return;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new TrayApp());
                GC.KeepAlive(mutex);
            }
        }
    }

    class TrayApp : ApplicationContext
    {
        // LED slots: 0 disk read, 1 disk write, 2 LAN rx, 3 LAN tx,
        //            4 Wi-Fi rx, 5 Wi-Fi tx, 6 combined rx, 7 combined tx
        const int Slots = 8;

        Settings cfg = Settings.Load();
        readonly NotifyIcon diskIcon = new NotifyIcon();
        readonly NotifyIcon netIcon = new NotifyIcon();
        readonly System.Windows.Forms.Timer poll = new System.Windows.Forms.Timer();
        readonly System.Windows.Forms.Timer fade = new System.Windows.Forms.Timer();
        readonly DiskCounters disk = new DiskCounters();
        readonly Dictionary<string, long[]> lastNet = new Dictionary<string, long[]>();
        NetworkInterface[] nics = new NetworkInterface[0];
        int nicsAt;

        readonly int[] litUntil = new int[Slots];
        readonly bool[] lit = new bool[Slots];
        readonly double[] acc = new double[Slots];
        public readonly double[] Rates = new double[Slots];
        int lastTick, accStart;
        string diskKey = "", netKey = "";
        RatesForm ratesForm;
        bool settingsOpen;

        bool Combined { get { return cfg.ShowNetwork && cfg.CombineNetwork; } }

        public TrayApp()
        {
            int now = Environment.TickCount;
            lastTick = accStart = now;
            nicsAt = now - 10000;
            for (int i = 0; i < Slots; i++) litUntil[i] = now;

            var menu = new ContextMenuStrip();
            menu.Items.Add("Rates", null, (s, e) => ShowRates());
            menu.Items.Add("Settings...", null, (s, e) => ShowSettings());
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, (s, e) => ExitThread());

            foreach (var ni in new[] { diskIcon, netIcon })
            {
                ni.ContextMenuStrip = menu;
                ni.Text = "Otter Blink";
                ni.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) ShowRates(); };
            }

            fade.Interval = 15;
            fade.Tick += (s, e) => Fade();
            poll.Tick += (s, e) => Poll();

            ApplySettings();
            diskIcon.Visible = true;
            poll.Start();
        }

        void ApplySettings()
        {
            poll.Interval = Math.Max(cfg.Interval, 20);
            netIcon.Visible = cfg.ShowNetwork && !cfg.CombineNetwork;
            Redraw(true);
            UpdateTooltips();
        }

        void Poll()
        {
            int now = Environment.TickCount;
            double dt = Math.Max(now - lastTick, 1) / 1000.0;
            lastTick = now;

            var r = new double[Slots];
            disk.Read(out r[0], out r[1]);
            if (cfg.ShowNetwork) ReadNet(now, dt, r);
            r[6] = r[2] + r[4];
            r[7] = r[3] + r[5];

            for (int i = 0; i < Slots; i++)
            {
                acc[i] += r[i] * dt;
                if (r[i] > 0) litUntil[i] = now + Math.Max(cfg.Hold, 1);
            }

            if (now - accStart >= 1000)
            {
                double span = (now - accStart) / 1000.0;
                for (int i = 0; i < Slots; i++) { Rates[i] = acc[i] / span; acc[i] = 0; }
                accStart = now;
                UpdateTooltips();
                if (ratesForm != null && ratesForm.Visible)
                    ratesForm.UpdateRates(Rates, cfg.ShowNetwork, cfg.CombineNetwork);
            }

            Fade();
        }

        void ReadNet(int now, double dt, double[] r)
        {
            if (now - nicsAt >= 5000)
            {
                try { nics = NetworkInterface.GetAllNetworkInterfaces(); } catch { nics = new NetworkInterface[0]; }
                nicsAt = now;
            }

            var seen = new HashSet<string>();
            foreach (var n in nics)
            {
                int slot;
                switch (n.NetworkInterfaceType)
                {
                    case NetworkInterfaceType.Wireless80211:
                        slot = 4; break;
                    case NetworkInterfaceType.Ethernet:
                    case NetworkInterfaceType.GigabitEthernet:
                    case NetworkInterfaceType.FastEthernetT:
                    case NetworkInterfaceType.FastEthernetFx:
                        slot = 2; break;
                    default:
                        continue;
                }
                if (n.OperationalStatus != OperationalStatus.Up) continue;
                string d = n.Description ?? "";
                if (d.IndexOf("Virtual", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    d.IndexOf("Hyper-V", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    d.IndexOf("Loopback", StringComparison.OrdinalIgnoreCase) >= 0) continue;

                long rx, tx;
                try
                {
                    var st = n.GetIPv4Statistics();
                    rx = st.BytesReceived;
                    tx = st.BytesSent;
                }
                catch { continue; }

                seen.Add(n.Id);
                long[] prev;
                if (lastNet.TryGetValue(n.Id, out prev))
                {
                    r[slot] += Math.Max(rx - prev[0], 0) / dt;
                    r[slot + 1] += Math.Max(tx - prev[1], 0) / dt;
                }
                lastNet[n.Id] = new[] { rx, tx };
            }

            var gone = new List<string>();
            foreach (var k in lastNet.Keys) if (!seen.Contains(k)) gone.Add(k);
            foreach (var k in gone) lastNet.Remove(k);
        }

        void Fade()
        {
            int now = Environment.TickCount;
            bool any = false;
            for (int i = 0; i < Slots; i++)
            {
                lit[i] = litUntil[i] - now > 0;
                any |= lit[i];
            }
            Redraw(false);
            fade.Enabled = any;
        }

        void Redraw(bool force)
        {
            if (Combined)
            {
                // One icon: disk on top, network below
                string ck = Key(0, 1, 6, 7);
                if (force || ck != diskKey)
                {
                    diskKey = ck;
                    SetIcon(diskIcon, LedIcon.Make(
                        new[] { cfg.ReadColor, cfg.WriteColor, cfg.RxColor, cfg.TxColor },
                        new[] { lit[0], lit[1], lit[6], lit[7] }, 2, cfg.OffBrightness));
                }
                return;
            }

            string dk = Key(0, 1);
            if (force || dk != diskKey)
            {
                diskKey = dk;
                SetIcon(diskIcon, LedIcon.Make(
                    new[] { cfg.ReadColor, cfg.WriteColor },
                    new[] { lit[0], lit[1] }, 2, cfg.OffBrightness));
            }
            if (!cfg.ShowNetwork) return;
            string nk = Key(2, 3, 4, 5);
            if (force || nk != netKey)
            {
                netKey = nk;
                SetIcon(netIcon, LedIcon.Make(
                    new[] { cfg.RxColor, cfg.TxColor, cfg.RxColor, cfg.TxColor },
                    new[] { lit[2], lit[3], lit[4], lit[5] }, 2, cfg.OffBrightness));
            }
        }

        string Key(params int[] slots)
        {
            var c = new char[slots.Length];
            for (int i = 0; i < slots.Length; i++) c[i] = lit[slots[i]] ? '1' : '0';
            return new string(c);
        }

        static void SetIcon(NotifyIcon ni, System.Drawing.Icon ico)
        {
            var old = ni.Icon;
            ni.Icon = ico;
            if (old != null) old.Dispose();
        }

        void UpdateTooltips()
        {
            string diskText = "Disk R " + Fmt(Rates[0]) + " W " + Fmt(Rates[1]);
            if (Combined)
            {
                diskIcon.Text = Clip(diskText + "  Net \u2193" + Fmt(Rates[6]) + " \u2191" + Fmt(Rates[7]));
                return;
            }
            diskIcon.Text = Clip(diskText);
            netIcon.Text = Clip("LAN \u2193" + Fmt(Rates[2]) + " \u2191" + Fmt(Rates[3]) +
                                "  Wi-Fi \u2193" + Fmt(Rates[4]) + " \u2191" + Fmt(Rates[5]));
        }

        static string Clip(string s) { return s.Length > 63 ? s.Substring(0, 63) : s; }

        public static string Fmt(double b)
        {
            string[] u = { "B", "KiB", "MiB", "GiB" };
            int i = 0;
            while (b >= 1024 && i < u.Length - 1) { b /= 1024; i++; }
            return b.ToString(i == 0 ? "0" : "0.0") + " " + u[i] + "/s";
        }

        void ShowRates()
        {
            if (ratesForm == null) ratesForm = new RatesForm();
            ratesForm.UpdateRates(Rates, cfg.ShowNetwork, cfg.CombineNetwork);
            ratesForm.ShowNear();
        }

        void ShowSettings()
        {
            if (settingsOpen) return;
            settingsOpen = true;
            try
            {
                using (var f = new SettingsForm(cfg))
                {
                    if (f.ShowDialog() == DialogResult.OK)
                    {
                        cfg = f.Result;
                        cfg.Save();
                        ApplySettings();
                    }
                }
            }
            finally { settingsOpen = false; }
        }

        protected override void ExitThreadCore()
        {
            poll.Stop();
            fade.Stop();
            diskIcon.Visible = false;
            netIcon.Visible = false;
            diskIcon.Dispose();
            netIcon.Dispose();
            base.ExitThreadCore();
        }
    }
}
