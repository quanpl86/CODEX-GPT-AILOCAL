param([Parameter(Mandatory=$true)][string]$Task, [ValidateRange(1,65535)][int]$ComfyPort = 8188)
$ErrorActionPreference = 'Stop'
# A read-only check: never interrupt a ComfyUI job implicitly.
try {
    $queue = Invoke-RestMethod "http://127.0.0.1:$ComfyPort/queue" -TimeoutSec 2
    if ($null -eq $queue.queue_running -or $null -eq $queue.queue_pending) { throw 'Invalid ComfyUI queue response' }
} catch {
    $probe = [Net.Sockets.TcpClient]::new()
    try {
        $attempt=$probe.ConnectAsync('127.0.0.1',$ComfyPort)
        # A timeout is unknown, not evidence that ComfyUI is stopped.
        $listening= -not $attempt.Wait(700) -or $probe.Connected
    } catch {
        $cause=$_.Exception.GetBaseException()
        if ($cause -is [Net.Sockets.SocketException] -and $cause.SocketErrorCode -eq [Net.Sockets.SocketError]::ConnectionRefused) { $listening=$false }
        else { throw 'ComfyUI status cannot be verified (socket access failed). Check local networking permissions before loading a model.' }
    } finally { $probe.Dispose() }
    if ($listening) { throw 'ComfyUI port is reachable but queue status cannot be verified. Restore the queue API before loading a model.' }
    $queue = $null
}
if ($queue -and (@($queue.queue_running).Count -gt 0 -or @($queue.queue_pending).Count -gt 0)) {
    throw 'ComfyUI has an active or queued job. Finish it before loading a local coding model.'
}
if ($env:OS -eq 'Windows_NT') {
    if (-not ('LocalAI.MemoryInfo' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace LocalAI {
    public static class MemoryInfo {
        [StructLayout(LayoutKind.Sequential)]
        private struct Status {
            public uint Length, Load;
            public ulong TotalPhysical, AvailablePhysical, TotalPage, AvailablePage;
            public ulong TotalVirtual, AvailableVirtual, AvailableExtended;
        }
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool GlobalMemoryStatusEx(ref Status status);
        public static ulong Available() {
            var s = new Status(); s.Length = (uint)Marshal.SizeOf<Status>();
            if (!GlobalMemoryStatusEx(ref s)) throw new InvalidOperationException("Cannot query available RAM");
            return s.AvailablePhysical;
        }
    }
}
'@
    }
    $freeGB = [LocalAI.MemoryInfo]::Available() / 1GB
    $minimumGB = switch ($Task) { 'brain' {22}; 'learning' {22}; 'code' {22}; 'review' {21}; default {6} }
    if ($freeGB -lt $minimumGB) {
        throw ('Not enough free RAM for {0}: {1:N1} GiB free, need at least {2} GiB. Close heavy applications or let Codex handle this task.' -f $Task,$freeGB,$minimumGB)
    }
}
