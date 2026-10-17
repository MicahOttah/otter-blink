using System;
using System.Runtime.InteropServices;

namespace OtterBlink
{
    // Disk throughput from the built-in PhysicalDisk counters.
    // PdhAddEnglishCounter uses English names, so it works on any Windows language.
    class DiskCounters
    {
        IntPtr query, readCounter, writeCounter;
        readonly bool ok;

        public DiskCounters()
        {
            try
            {
                ok = Pdh.PdhOpenQuery(null, IntPtr.Zero, out query) == 0
                  && Pdh.PdhAddEnglishCounter(query, @"\PhysicalDisk(_Total)\Disk Read Bytes/sec", IntPtr.Zero, out readCounter) == 0
                  && Pdh.PdhAddEnglishCounter(query, @"\PhysicalDisk(_Total)\Disk Write Bytes/sec", IntPtr.Zero, out writeCounter) == 0;
                if (ok) Pdh.PdhCollectQueryData(query);
            }
            catch { ok = false; }
        }

        public void Read(out double read, out double write)
        {
            read = write = 0;
            if (!ok || Pdh.PdhCollectQueryData(query) != 0) return;
            read = Value(readCounter);
            write = Value(writeCounter);
        }

        static double Value(IntPtr counter)
        {
            uint type;
            Pdh.PDH_FMT_COUNTERVALUE v;
            if (Pdh.PdhGetFormattedCounterValue(counter, Pdh.PDH_FMT_DOUBLE | Pdh.PDH_FMT_NOCAP100, out type, out v) != 0)
                return 0;
            if (v.CStatus > 1) return 0;   // 0 = valid, 1 = new data
            return v.doubleValue > 0 ? v.doubleValue : 0;
        }
    }

    static class Pdh
    {
        public const uint PDH_FMT_DOUBLE = 0x00000200;
        public const uint PDH_FMT_NOCAP100 = 0x00008000;

        [StructLayout(LayoutKind.Explicit)]
        public struct PDH_FMT_COUNTERVALUE
        {
            [FieldOffset(0)] public uint CStatus;
            [FieldOffset(8)] public double doubleValue;
        }

        [DllImport("pdh.dll", CharSet = CharSet.Unicode)]
        public static extern uint PdhOpenQuery(string dataSource, IntPtr userData, out IntPtr query);

        [DllImport("pdh.dll", CharSet = CharSet.Unicode)]
        public static extern uint PdhAddEnglishCounter(IntPtr query, string fullCounterPath, IntPtr userData, out IntPtr counter);

        [DllImport("pdh.dll")]
        public static extern uint PdhCollectQueryData(IntPtr query);

        [DllImport("pdh.dll")]
        public static extern uint PdhGetFormattedCounterValue(IntPtr counter, uint format, out uint type, out PDH_FMT_COUNTERVALUE value);
    }
}
