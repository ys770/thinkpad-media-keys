// Sends one media key press and exits. No window.
//
// Usage: MediaKey.exe [playpause|next|prev]
//        MediaKey.exe probe <tag>   (appends <tag> to probe.log next to the exe, sends nothing)
//
// With no arguments the action is picked from the exe's own file name, so copies
// named Next.exe / Prev.exe / PlayPause.exe work in places that can't pass arguments
// (e.g. Lenovo Vantage's "user-defined key" app picker).
using System;
using System.IO;
using System.Runtime.InteropServices;

static class MediaKey
{
    [DllImport("user32.dll")]
    static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    const uint KEYEVENTF_EXTENDEDKEY = 0x1, KEYEVENTF_KEYUP = 0x2;

    static void Main(string[] args)
    {
        string self = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]).ToLowerInvariant();
        string a = args.Length > 0 ? args[0].ToLowerInvariant()
                 : self.Contains("next") ? "next" : self.Contains("prev") ? "prev" : "playpause";
        if (a == "probe")
        {
            string log = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "probe.log");
            File.AppendAllText(log, DateTime.Now.ToString("HH:mm:ss.fff") + " " + string.Join(" ", args) + Environment.NewLine);
            return;
        }
        byte vk = 0xB3;                  // VK_MEDIA_PLAY_PAUSE
        if (a == "next") vk = 0xB0;      // VK_MEDIA_NEXT_TRACK
        else if (a == "prev") vk = 0xB1; // VK_MEDIA_PREV_TRACK
        keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero);
        keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
