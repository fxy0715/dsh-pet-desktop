# Desktop whale for the dsh-pet-desktop Harness plugin.
# Draws the official DeepSeek whale as a WPF vector path inside a transparent,
# borderless, always-on-top window. It drifts gently, follows the mouse when
# dragged, remembers the last user-placed position, and exits by itself when
# the parent Harness process disappears.
#
# The shared official artwork is injected by scripts/build.cjs.
param(
  [int]$ParentPid = 0,
  [string]$StateFile = ''
)

$ErrorActionPreference = 'Stop'

# Single instance guard: a second launch (manual test + installed plugin) must
# quietly no-op instead of stacking two whales. Use WaitOne (not constructor
# ownership) so a mutex abandoned by a force-killed instance is recovered
# instead of blocking every future launch until reboot.
$mutex = New-Object System.Threading.Mutex($false, 'Local\dsh-pet-desktop-whale')
$owned = $false
try {
  $owned = $mutex.WaitOne([TimeSpan]::FromSeconds(3))
} catch [System.Threading.AbandonedMutexException] {
  # The previous instance was force-killed mid-hold; the mutex is ours now.
  $owned = $true
}
if (-not $owned) { exit 0 }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -Path (Join-Path $PSScriptRoot 'ScreenBoundWindow.cs') -ReferencedAssemblies @(
  [System.Windows.Window].Assembly.Location,
  [System.Windows.Media.Visual].Assembly.Location,
  [System.Windows.DependencyObject].Assembly.Location,
  [System.Xaml.XamlReader].Assembly.Location)

if (-not $StateFile) {
  $StateFile = Join-Path $env:APPDATA 'dsh-pet\position.json'
}

# --- artwork -----------------------------------------------------------------
$whalePathData = 'M22.9168 1.43018C22.6713 1.31018 22.5658 1.53918 22.4223 1.65519C22.3733 1.69269 22.3318 1.74169 22.2903 1.78669C21.9317 2.1697 21.5127 2.42121 20.9657 2.39121C20.1657 2.34621 19.4827 2.59771 18.8787 3.20973C18.7502 2.45521 18.3236 2.0047 17.6746 1.71569C17.3351 1.56568 16.9916 1.41518 16.7536 1.08867C16.5876 0.856163 16.5421 0.597155 16.4591 0.341647C16.4061 0.187643 16.3536 0.0301382 16.1761 0.00363739C15.9836 -0.0263635 15.9081 0.135141 15.8326 0.270145C15.5306 0.822162 15.4136 1.43018 15.4251 2.0462C15.4516 3.43174 16.0366 4.53527 17.1991 5.3203C17.3311 5.4103 17.3651 5.5003 17.3236 5.63181C17.2441 5.90231 17.1501 6.16482 17.0671 6.43533C17.0141 6.60784 16.9351 6.64584 16.7501 6.57033C16.1121 6.30383 15.5611 5.90931 15.074 5.4328C14.2475 4.63328 13.5 3.75075 12.568 3.05973C12.349 2.89822 12.13 2.74822 11.9034 2.60522C10.9524 1.68169 12.028 0.923165 12.277 0.833162C12.5375 0.739159 12.3675 0.41615 11.5259 0.42015C10.6844 0.42365 9.91439 0.705658 8.93286 1.08117C8.78935 1.13767 8.63835 1.17867 8.48384 1.21267C7.59332 1.04367 6.66829 1.00617 5.70226 1.11517C3.88321 1.31768 2.43016 2.1777 1.36213 3.64575C0.0790928 5.4103 -0.222916 7.41536 0.146595 9.50642C0.535106 11.7105 1.66014 13.535 3.38869 14.9616C5.18125 16.4406 7.24581 17.1657 9.60138 17.0266C11.0319 16.9441 12.6245 16.7526 14.421 15.2321C14.874 15.4576 15.3496 15.5476 16.1381 15.6151C16.7456 15.6716 17.3306 15.5851 17.7836 15.4911C18.4931 15.3411 18.4441 14.6841 18.1876 14.5636C16.1081 13.595 16.5646 13.9891 16.1496 13.67C17.2061 12.42 18.8202 10.1979 19.3182 7.17235C19.3672 6.83834 19.4297 6.36783 19.4222 6.09732C19.4182 5.93231 19.4562 5.86831 19.6447 5.84931C20.1657 5.78931 20.6712 5.64681 21.1357 5.3913C22.4833 4.65528 23.0268 3.44624 23.1548 1.9972C23.1738 1.77569 23.1508 1.54668 22.9168 1.43018ZM11.1749 14.4736C9.15936 12.889 8.18184 12.3675 7.77832 12.39C7.40081 12.4125 7.46881 12.8445 7.55182 13.126C7.63882 13.404 7.75182 13.5955 7.91033 13.8396C8.01983 14.0011 8.09533 14.2411 7.80083 14.4216C7.15181 14.8231 6.02327 14.2866 5.97027 14.2601C4.65673 13.4865 3.5587 12.4655 2.78467 11.069C2.03715 9.72493 1.60314 8.28289 1.53164 6.74384C1.51264 6.37233 1.62214 6.24082 1.99215 6.17332C2.47916 6.08332 2.98118 6.06432 3.46769 6.13582C5.52476 6.43633 7.27581 7.35586 8.74385 8.8129C9.58188 9.64243 10.2159 10.634 10.8689 11.6025C11.5634 12.631 12.3105 13.611 13.262 14.4146C13.598 14.6961 13.866 14.9101 14.1225 15.0681C13.349 15.1546 12.058 15.1731 11.1749 14.4746L11.1749 14.4736ZM12.141 8.25988C12.141 8.09488 12.273 7.96338 12.439 7.96338C12.4765 7.96338 12.5105 7.97088 12.541 7.98188C12.5825 7.99688 12.6205 8.01938 12.6505 8.05338C12.7035 8.10588 12.7335 8.18088 12.7335 8.25988C12.7335 8.42489 12.6015 8.55639 12.4355 8.55639C12.2695 8.55639 12.141 8.42489 12.141 8.25988ZM15.1415 9.79893C14.949 9.87793 14.7565 9.94544 14.5715 9.95294C14.2845 9.96794 13.9715 9.85143 13.8015 9.70893C13.5375 9.48742 13.3485 9.36342 13.2695 8.97691C13.2355 8.8119 13.2545 8.55639 13.2845 8.40989C13.3525 8.09438 13.277 7.89187 13.0545 7.70787C12.8735 7.55786 12.643 7.51636 12.39 7.51636C12.2955 7.51636 12.209 7.47486 12.1445 7.44136C12.039 7.38886 11.9519 7.25735 12.035 7.09585C12.0615 7.04335 12.19 6.91584 12.22 6.89334C12.5635 6.69784 12.9595 6.76184 13.326 6.90834C13.6655 7.04735 13.9225 7.30236 14.292 7.66287C14.6695 8.09838 14.7375 8.21838 14.9525 8.54539C15.1225 8.8009 15.277 9.06341 15.3831 9.36392C15.4471 9.55142 15.3641 9.70493 15.1415 9.79893Z'
# WPF's geometry parser wants 0.x instead of .x; normalize leading dots without
# touching decimal digits that are already anchored (1.5 stays 1.5).
$whalePathData = [regex]::Replace($whalePathData, '(?<![\d])\.(?=\d)', '0.')
$geometry = [System.Windows.Media.Geometry]::Parse($whalePathData)

$whaleWidth = 96.0
$whaleHeight = [math]::Round($whaleWidth * 17.04 / 23.16, 1)
$bobDistance = 7.0
$motionPadding = 12.0
$whaleBottomMargin = 18.0

$win = New-Object DshPet.ScreenBoundWindow
$win.AllowsTransparency = $true
$win.WindowStyle = [System.Windows.WindowStyle]::None
$win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true
$win.ShowInTaskbar = $false
$win.ShowActivated = $false
$win.ResizeMode = [System.Windows.ResizeMode]::NoResize
$win.Width = 240
$win.Height = 190
$win.Title = 'DeepSeek desktop whale'

# Official brand gradient: #5B7CFF (top) -> #3D5AFE (bottom).
$brush = New-Object System.Windows.Media.LinearGradientBrush
$brush.StartPoint = New-Object System.Windows.Point(0, 0)
$brush.EndPoint = New-Object System.Windows.Point(0, 1)
[void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromRgb(0x5B, 0x7C, 0xFF), 0)))
[void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromRgb(0x3D, 0x5A, 0xFE), 1)))

$whale = New-Object System.Windows.Shapes.Path
$whale.Data = $geometry
$whale.Fill = $brush
$whale.Stretch = [System.Windows.Media.Stretch]::Fill
$whale.Width = $whaleWidth
$whale.Height = $whaleHeight

$shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
$shadow.BlurRadius = 12
$shadow.ShadowDepth = 6
$shadow.Opacity = 0.35
$shadow.Color = [System.Windows.Media.Color]::FromRgb(0x14, 0x28, 0x78)
$whale.Effect = $shadow

# Flip (drift direction), wiggle (click) and bob (idle) compose here.
$scale = New-Object System.Windows.Media.ScaleTransform
$scale.ScaleX = 1
$scale.ScaleY = 1
$rotate = New-Object System.Windows.Media.RotateTransform
$bob = New-Object System.Windows.Media.TranslateTransform
$transformGroup = New-Object System.Windows.Media.TransformGroup
[void]$transformGroup.Children.Add($scale)
[void]$transformGroup.Children.Add($rotate)
[void]$transformGroup.Children.Add($bob)
$whale.RenderTransform = $transformGroup
$whale.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)

# --- layout ------------------------------------------------------------------
$root = New-Object System.Windows.Controls.Grid
$root.Width = 240
$root.Height = 190

# Transparent hit-test filler exactly over the whale rectangle: outside it the
# per-pixel-alpha window is click-through at the OS level.
$whaleHost = New-Object System.Windows.Controls.Grid
$whaleHost.Background = [System.Windows.Media.Brushes]::Transparent
$whaleHost.Width = $whaleWidth
$whaleHost.Height = $whaleHeight
$whaleHost.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
$whaleHost.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$whaleHost.Margin = New-Object System.Windows.Thickness(0, 0, 0, $whaleBottomMargin)
$whaleHost.Cursor = [System.Windows.Input.Cursors]::Hand
[void]$whaleHost.Children.Add($whale)
[void]$root.Children.Add($whaleHost)

$bubbleText = New-Object System.Windows.Controls.TextBlock
$bubbleText.FontSize = 12
$bubbleText.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x1F, 0x29, 0x37))
$bubble = New-Object System.Windows.Controls.Border
$bubble.CornerRadius = New-Object System.Windows.CornerRadius(10)
$bubble.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3)
$bubble.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF))
$bubble.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xD1, 0xD9, 0xE6))
$bubble.BorderThickness = New-Object System.Windows.Thickness(1)
$bubble.Child = $bubbleText
$bubble.Visibility = [System.Windows.Visibility]::Collapsed
$bubble.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$bubble.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
# Popup placement flips at screen edges independently of the transparent host.
$bubblePopup = New-Object System.Windows.Controls.Primitives.Popup
$bubblePopup.AllowsTransparency = $true
$bubblePopup.StaysOpen = $true
$bubblePopup.IsHitTestVisible = $false
$bubblePopup.PlacementTarget = $whaleHost
$bubblePopup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Top
$bubblePopup.VerticalOffset = -8
$bubblePopup.Child = $bubble
$win.Add_LocationChanged({
  if ($bubblePopup.IsOpen) {
    # Popup does not track owner moves automatically; invalidate its placement.
    $offset = $bubblePopup.HorizontalOffset
    $bubblePopup.HorizontalOffset = $offset + 1
    $bubblePopup.HorizontalOffset = $offset
  }
})
$win.Add_Closed({ $bubblePopup.IsOpen = $false })

$win.Content = $root
$win.PetBounds = [System.Windows.Rect]::new(
  ($win.Width - $whaleWidth) / 2 - $motionPadding,
  $win.Height - $whaleHeight - $whaleBottomMargin - $bobDistance - $motionPadding,
  $whaleWidth + 2 * $motionPadding,
  $whaleHeight + $bobDistance + 2 * $motionPadding)

# --- script state ------------------------------------------------------------
$script:win = $win
$script:scale = $scale
$script:rotate = $rotate
$script:sleeping = $false
$script:moving = $false
$script:dragging = $false
$script:targetX = 0.0
$script:targetY = 0.0
$script:remainingTicks = 0
$script:quietUntil = [datetime]::MinValue
$script:bubbleLines = @('咕噜咕噜~', '加油鸭~', '我是 DeepSeek 的小蓝鲸~')

function Save-Position {
  try {
    $dir = Split-Path -Parent $StateFile
    if ($dir -and -not (Test-Path $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    @{ x = $script:win.Left; y = $script:win.Top } | ConvertTo-Json -Compress |
      Set-Content -Path $StateFile -Encoding UTF8
  } catch {
    # Forgetting the position is acceptable; never crash over storage.
  }
}

function Get-PositionBounds {
  # Allowed host origins already account for the pet's visible bounds and DPI.
  $area = $script:win.MovementBounds
  return @($area.Left, $area.Top, $area.Right, $area.Bottom)
}

function Set-WhalePosition {
  param([double]$X, [double]$Y)
  $b = Get-PositionBounds
  $script:win.Left = [math]::Min([math]::Max($X, $b[0]), $b[2])
  $script:win.Top = [math]::Min([math]::Max($Y, $b[1]), $b[3])
}

function Corner-Position {
  # Leave a small inset from the visible pet's bottom-right limit.
  $b = Get-PositionBounds
  $cornerInset = 16
  Set-WhalePosition -X ($b[2] - $cornerInset) -Y ($b[3] - $cornerInset)
}

function Show-Bubble {
  $bubbleText.Text = $script:bubbleLines[(Get-Random -Maximum $script:bubbleLines.Count)]
  $bubble.Visibility = [System.Windows.Visibility]::Visible
  $bubblePopup.IsOpen = $true
  $wig = New-Object System.Windows.Media.Animation.DoubleAnimation
  $wig.From = 0
  $wig.To = -7
  $wig.AutoReverse = $true
  $wig.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(220))
  $wig.RepeatBehavior = New-Object System.Windows.Media.Animation.RepeatBehavior(2)
  $wig.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
  $rotate.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $wig)
  $script:bubbleTimer.Stop()
  $script:bubbleTimer.Start()
}

# --- timers ------------------------------------------------------------------
$bubbleTimer = New-Object System.Windows.Threading.DispatcherTimer
$bubbleTimer.Interval = [TimeSpan]::FromMilliseconds(1900)
$bubbleTimer.Add_Tick({
  $bubble.Visibility = [System.Windows.Visibility]::Collapsed
  $bubblePopup.IsOpen = $false
  $bubbleTimer.Stop()
})
$script:bubbleTimer = $bubbleTimer

# Smooth manual interpolation: full control, no animation hold-end surprises
# fighting DragMove's direct Left/Top writes.
$motionTimer = New-Object System.Windows.Threading.DispatcherTimer
$motionTimer.Interval = [TimeSpan]::FromMilliseconds(33)
function Stop-Motion {
  $script:moving = $false
  $motionTimer.Stop()
}
$motionTimer.Add_Tick({
  if (-not $script:moving) { $motionTimer.Stop(); return }
  # Recheck every frame: monitor resolution, scaling or work area may have changed.
  $b = Get-PositionBounds
  $script:targetX = [math]::Min([math]::Max($script:targetX, $b[0]), $b[2])
  $script:targetY = [math]::Min([math]::Max($script:targetY, $b[1]), $b[3])
  $ticks = [math]::Max(1, $script:remainingTicks)
  Set-WhalePosition -X ($script:win.Left + ($script:targetX - $script:win.Left) / $ticks) -Y ($script:win.Top + ($script:targetY - $script:win.Top) / $ticks)
  $script:remainingTicks--
  if ($script:remainingTicks -le 0) {
    Set-WhalePosition -X $script:targetX -Y $script:targetY
    Stop-Motion
  }
})

$driftTimer = New-Object System.Windows.Threading.DispatcherTimer
$driftTimer.Interval = [TimeSpan]::FromMilliseconds(2400)
$driftTimer.Add_Tick({
  if ($script:sleeping -or $script:moving -or $script:dragging) { return }
  if ((Get-Date) -lt $script:quietUntil) { return }
  $b = Get-PositionBounds
  $nx = $script:win.Left + (Get-Random -Minimum -90 -Maximum 91)
  $ny = $script:win.Top + (Get-Random -Minimum -40 -Maximum 41)
  $nx = [math]::Min([math]::Max($nx, $b[0]), $b[2])
  $ny = [math]::Min([math]::Max($ny, $b[1]), $b[3])
  if ([math]::Abs($nx - $script:win.Left) -gt 4) {
    if ($nx -lt $script:win.Left) { $script:scale.ScaleX = -1 } else { $script:scale.ScaleX = 1 }
  }
  $script:targetX = $nx
  $script:targetY = $ny
  $script:remainingTicks = 70
  $script:moving = $true
  $motionTimer.Start()
})

# Watchdog: exit when the parent Harness process disappears, so the whale never
# outlives the plugin that owns it (covers hard exits that skip disposers).
$watchdog = New-Object System.Windows.Threading.DispatcherTimer
$watchdog.Interval = [TimeSpan]::FromSeconds(5)
$watchdog.Add_Tick({
  if ($ParentPid -gt 0) {
    $p = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
    if (-not $p) { $script:win.Close() }
  }
})

# --- interaction -------------------------------------------------------------
$whaleHost.Add_MouseLeftButtonDown({
  param($sender, $e)
  Stop-Motion
  $script:dragging = $true
  $driftTimer.Stop()
  $beforeLeft = $script:win.Left
  $beforeTop = $script:win.Top
  try { $script:win.DragMove() } catch { return } finally {
    $script:dragging = $false
    if (-not $script:sleeping) { $driftTimer.Start() }
  }
  $dx = [math]::Abs($script:win.Left - $beforeLeft)
  $dy = [math]::Abs($script:win.Top - $beforeTop)
  if (($dx + $dy) -lt 3) {
    Show-Bubble
  } else {
    # ScreenBoundWindow also constrains DragMove before each native move.
    # Persist only user-placed positions; drift stays transient.
    Set-WhalePosition -X $script:win.Left -Y $script:win.Top
    Save-Position
    $script:quietUntil = (Get-Date).AddSeconds(6)
  }
})

$menu = New-Object System.Windows.Controls.ContextMenu
$menu.Add_Opened({
  Stop-Motion
  $driftTimer.Stop()
})
$menu.Add_Closed({
  if (-not $script:sleeping) { $driftTimer.Start() }
})
$miSleep = New-Object System.Windows.Controls.MenuItem
$miSleep.Header = '暂停游走'
$miSleep.Add_Click({
  $script:sleeping = -not $script:sleeping
  if ($script:sleeping) {
    $miSleep.Header = '恢复游走'
    Stop-Motion
    $driftTimer.Stop()
  } else {
    $miSleep.Header = '暂停游走'
    $driftTimer.Start()
  }
})
[void]$menu.Items.Add($miSleep)

$miReset = New-Object System.Windows.Controls.MenuItem
$miReset.Header = '回到右下角'
$miReset.Add_Click({
  Stop-Motion
  $script:sleeping = $false
  $miSleep.Header = '暂停游走'
  Corner-Position
  $driftTimer.Start()
  try { Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue } catch {}
})
[void]$menu.Items.Add($miReset)

$miQuit = New-Object System.Windows.Controls.MenuItem
$miQuit.Header = '退出'
$miQuit.Add_Click({ $script:win.Close() })
[void]$menu.Items.Add($miQuit)

$win.ContextMenu = $menu

# --- start -------------------------------------------------------------------
$placed = $false
try {
  if (Test-Path $StateFile) {
    $saved = Get-Content -Path $StateFile -Raw | ConvertFrom-Json
    if ($null -ne $saved.x -and $null -ne $saved.y) {
      Set-WhalePosition -X ([double]$saved.x) -Y ([double]$saved.y)
      $placed = $true
    }
  }
} catch {
  $placed = $false
}
if (-not $placed) { Corner-Position }

# Idle bob: gentle vertical float, paused only while dragging (DragMove runs on
# the same thread; the animation keeps running and is visually fine).
$bobAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
$bobAnim.To = -$bobDistance
$bobAnim.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(800))
$bobAnim.AutoReverse = $true
$bobAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
$bob.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $bobAnim)

$driftTimer.Start()
$watchdog.Start()

$win.Show()

$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnLastWindowClose
[void]$app.Run()

$bubbleTimer.Stop()
$motionTimer.Stop()
$driftTimer.Stop()
$watchdog.Stop()
try { $mutex.ReleaseMutex() } catch {}
$mutex.Dispose()
