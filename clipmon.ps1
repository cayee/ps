#requires -version 2.0
 
[CmdletBinding()]
param
(
    $clipmonfile
)
 
$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }
 
function ClipboardWatcher-Register
{
    if (-not (Test-Path Variable:Global:ClipboardWatcher))
    {
        ClipboardWatcherType-Register
        $Global:ClipboardWatcher = New-Object ClipboardWatcher
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action `
        {
            ClipboardWatcher-Unregister
        }
    }
    return $Global:ClipboardWatcher
}
 
function ClipboardWatcher-Unregister
{
    if (Test-Path Variable:Global:ClipboardWatcher)
    {
        $Global:ClipboardWatcher.Dispose();
        Remove-Variable ClipboardWatcher -Scope Global
        Remove-Variable ClipboardWatcherStore -Scope Global
        Unregister-Event -SourceIdentifier ClipboardWatcher
    }
}
 
function ClipboardWatcherType-Register
{
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -Language CSharpVersion3 -TypeDefinition `
@"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
 
public class ClipboardWatcher : IDisposable
{
    readonly Thread _formThread;
    bool _disposed;
 
    public ClipboardWatcher()
    {
        _formThread = new Thread(() => { new ClipboardWatcherForm(this); })
                      {
                          IsBackground = true
                      };
 
        _formThread.SetApartmentState(ApartmentState.STA);
        _formThread.Start();
    }
 
    public void Dispose()
    {
        if (_disposed)
            return;
        Disposed();
        if (_formThread != null && _formThread.IsAlive)
            _formThread.Abort();
        _disposed = true;
        GC.SuppressFinalize(this);
    }
 
    ~ClipboardWatcher()
    {
        Dispose();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
    public event Action Disposed = delegate { };
    public bool clipResult { get; set; }
 
    public void OnClipboardTextChanged(string text)
    {
        ClipboardTextChanged(text);
    }
}
 
public class ClipboardWatcherForm : Form
{
    public ClipboardWatcherForm(ClipboardWatcher clipboardWatcher)
    {
        HideForm();
        clipboardWatcher.clipResult = RegisterWin32();
        ClipboardTextChanged += clipboardWatcher.OnClipboardTextChanged;
        clipboardWatcher.Disposed += () => InvokeIfRequired(Dispose);
        Disposed += (sender, args) => UnregisterWin32();
        Application.Run(this);
    }
 
    void InvokeIfRequired(Action action)
    {
        if (InvokeRequired)
            Invoke(action);
        else
            action();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
 
    protected override CreateParams CreateParams {
      get {
        // Turn on WS_EX_TOOLWINDOW style bit to hide form from Alt-Tab
        CreateParams cp = base.CreateParams;
        cp.ExStyle |= 0x80;
        return cp;
      }
    }
  
    void HideForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        Load += (sender, args) => { Size = new Size(0, 0); };
    }
 
    bool RegisterWin32()
    {
        return User32.AddClipboardFormatListener(Handle);
    }
 
    void UnregisterWin32()
    {
        if (IsHandleCreated)
            User32.RemoveClipboardFormatListener(Handle);
    }
 
    protected override void WndProc(ref Message m)
    {
        switch ((WM) m.Msg)
        {
            case WM.WM_CLIPBOARDUPDATE:
                ClipboardChanged();
                break;
 
            default:
                base.WndProc(ref m);
                break;
        }
    }
 
    void ClipboardChanged()
    {
        if (Clipboard.ContainsText())
            ClipboardTextChanged(Clipboard.GetText());
    }
}
 
public enum WM
{
    WM_CLIPBOARDUPDATE = 0x031D
}
 
public class User32
{
    const string User32Dll = "User32.dll";
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool AddClipboardFormatListener(IntPtr hWndObserver);
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hWndObserver);
}
"@
}

function ClipboardWatcher-ClipboardTextChangedEvent-Register
{
    param
    (
        [ScriptBlock] $Action
    )
 
    $watcher = ClipboardWatcher-Register
    Register-ObjectEvent $watcher -EventName ClipboardTextChanged -Action $Action -SourceIdentifier ClipboardWatcher > $null
}

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class UserWindows {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@            

function ClipboardWatcher-Start
{
    ClipboardWatcher-ClipboardTextChangedEvent-Register -Action `
    {
        param
        (
            [string] $text
        )
    
        $logtime = Get-Date -Format "yyyy-MM-dd-hh:mm:ss"   
        try {            
            $ActiveHandle = [UserWindows]::GetForegroundWindow()            
            $Process = Get-Process | ? {$_.MainWindowHandle -eq $activeHandle}
            $wintitle = $Process.MainWindowTitle
        } catch {            
            # Write-Host "Failed to GetForegroundWindow: $_"
        }
        $logitem = "$pid $logtime [$wintitle] $text"
        # Write-Host $logitem
        $logitem >> $clipmonfile
    }
}

$logtime = Get-Date -Format "yyyy-MM-dd-hh:mm:ss"
$logitem = "$pid $logtime Started"
$logitem >> $clipmonfile
ClipboardWatcher-Start
