using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;

namespace DshPet
{
    // Keep the visible pet on screen; its transparent host may extend past an edge.
    // Native interception also covers DragMove and display configuration changes.
    public sealed class ScreenBoundWindow : Window
    {
        private const int WindowPosChanging = 0x0046;
        private const int Moving = 0x0216;
        private const int DisplayChange = 0x007e;
        private const int SettingChange = 0x001a;
        private const int WmDpiChanged = 0x02e0;
        private const uint NoSize = 0x0001;
        private const uint NoMove = 0x0002;
        private const uint NoZOrder = 0x0004;
        private const uint NoActivate = 0x0010;
        private const uint NearestMonitor = 2;
        private const int EdgeMargin = 8;
        private IntPtr handle;
        private HwndSource source;
        private bool repairQueued;

        // Bounds of the pet and its animation envelope inside the WPF host.
        // Empty retains whole-window containment for hosts without a pet layout.
        public Rect PetBounds { get; set; }

        [StructLayout(LayoutKind.Sequential)]
        private struct NativeRect
        {
            public int Left, Top, Right, Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WindowPos
        {
            public IntPtr Window, InsertAfter;
            public int X, Y, Width, Height;
            public uint Flags;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MonitorInfo
        {
            public int Size;
            public NativeRect Monitor, Work;
            public uint Flags;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool GetWindowRect(IntPtr hwnd, out NativeRect rect);
        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromRect(ref NativeRect rect, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);

        public Rect ScreenWorkArea
        {
            get
            {
                new WindowInteropHelper(this).EnsureHandle();
                NativeRect rect = CurrentRect();
                NativeRect work = WorkArea(VisibleRect(rect));
                // Native messages use device coordinates; the animation uses WPF DIPs.
                var transform = source.CompositionTarget.TransformFromDevice;
                return new Rect(transform.Transform(new Point(work.Left, work.Top)),
                    transform.Transform(new Point(work.Right, work.Bottom)));
            }
        }

        public Rect MovementBounds
        {
            get
            {
                new WindowInteropHelper(this).EnsureHandle();
                NativeRect limits = MovementLimits(CurrentRect());
                var transform = source.CompositionTarget.TransformFromDevice;
                return new Rect(transform.Transform(new Point(limits.Left, limits.Top)),
                    transform.Transform(new Point(limits.Right, limits.Bottom)));
            }
        }

        public ScreenBoundWindow()
        {
            PetBounds = Rect.Empty;
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            handle = new WindowInteropHelper(this).Handle;
            source = HwndSource.FromHwnd(handle);
            source.AddHook(ConstrainMove);
        }

        private NativeRect CurrentRect()
        {
            NativeRect rect;
            if (!GetWindowRect(handle, out rect)) throw new Win32Exception(Marshal.GetLastWin32Error());
            return rect;
        }

        private static NativeRect WorkArea(NativeRect rect)
        {
            MonitorInfo info = new MonitorInfo();
            info.Size = Marshal.SizeOf(typeof(MonitorInfo));
            if (!GetMonitorInfo(MonitorFromRect(ref rect, NearestMonitor), ref info))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return info.Work;
        }

        private NativeRect VisibleRect(NativeRect rect)
        {
            if (PetBounds.IsEmpty || !(Width > 0) || !(Height > 0)) return rect;
            // Use the proposed native size so a DPI transition uses matching units.
            double scaleX = (rect.Right - rect.Left) / Width;
            double scaleY = (rect.Bottom - rect.Top) / Height;
            return new NativeRect {
                Left = rect.Left + (int)Math.Floor(PetBounds.Left * scaleX),
                Top = rect.Top + (int)Math.Floor(PetBounds.Top * scaleY),
                Right = rect.Left + (int)Math.Ceiling(PetBounds.Right * scaleX),
                Bottom = rect.Top + (int)Math.Ceiling(PetBounds.Bottom * scaleY)
            };
        }

        private NativeRect MovementLimits(NativeRect rect)
        {
            NativeRect visible = VisibleRect(rect);
            NativeRect work = WorkArea(visible);
            int width = visible.Right - visible.Left;
            int height = visible.Bottom - visible.Top;
            int marginX = Math.Min(EdgeMargin, Math.Max(0, (work.Right - work.Left - width) / 2));
            int marginY = Math.Min(EdgeMargin, Math.Max(0, (work.Bottom - work.Top - height) / 2));
            int left = work.Left + marginX - (visible.Left - rect.Left);
            int top = work.Top + marginY - (visible.Top - rect.Top);
            return new NativeRect {
                Left = left, Top = top,
                Right = Math.Max(left, work.Right - marginX - (visible.Right - rect.Left)),
                Bottom = Math.Max(top, work.Bottom - marginY - (visible.Bottom - rect.Top))
            };
        }

        private NativeRect Clamp(NativeRect rect)
        {
            NativeRect limits = MovementLimits(rect);
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;
            int x = Math.Max(limits.Left, Math.Min(rect.Left, limits.Right));
            int y = Math.Max(limits.Top, Math.Min(rect.Top, limits.Bottom));
            rect.Left = x; rect.Top = y; rect.Right = x + width; rect.Bottom = y + height;
            return rect;
        }

        private IntPtr ConstrainMove(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (message == Moving)
            {
                NativeRect rect = (NativeRect)Marshal.PtrToStructure(lParam, typeof(NativeRect));
                Marshal.StructureToPtr(Clamp(rect), lParam, false);
                handled = true;
                return new IntPtr(1);
            }
            if (message == WindowPosChanging)
            {
                WindowPos pos = (WindowPos)Marshal.PtrToStructure(lParam, typeof(WindowPos));
                NativeRect current = CurrentRect();
                int x = (pos.Flags & NoMove) != 0 ? current.Left : pos.X;
                int y = (pos.Flags & NoMove) != 0 ? current.Top : pos.Y;
                int width = (pos.Flags & NoSize) != 0 ? current.Right - current.Left : pos.Width;
                int height = (pos.Flags & NoSize) != 0 ? current.Bottom - current.Top : pos.Height;
                NativeRect proposed = new NativeRect { Left = x, Top = y, Right = x + width, Bottom = y + height };
                NativeRect bounded = Clamp(proposed);
                if (bounded.Left != x || bounded.Top != y)
                {
                    pos.X = bounded.Left; pos.Y = bounded.Top; pos.Flags &= ~NoMove;
                    Marshal.StructureToPtr(pos, lParam, false);
                }
                // WPF must still receive this message to update its position state.
            }
            if ((message == DisplayChange || message == SettingChange || message == WmDpiChanged) && !repairQueued)
            {
                repairQueued = true;
                Dispatcher.BeginInvoke(DispatcherPriority.Send, new Action(delegate
                {
                    repairQueued = false;
                    if (source == null || source.IsDisposed) return;
                    NativeRect rect = CurrentRect();
                    NativeRect bounded = Clamp(rect);
                    if ((rect.Left != bounded.Left || rect.Top != bounded.Top) &&
                        !SetWindowPos(handle, IntPtr.Zero, bounded.Left, bounded.Top, 0, 0, NoSize | NoZOrder | NoActivate))
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                }));
            }
            return IntPtr.Zero;
        }

        protected override void OnClosed(EventArgs e)
        {
            if (source != null && !source.IsDisposed) source.RemoveHook(ConstrainMove);
            source = null;
            base.OnClosed(e);
        }
    }
}
