state("Paradox_Vector"){}

startup
{
    vars.Log = (Action<object>)((output) => print("[Paradox Vector ASL] " + output));
}

init
{
    List<IntPtr> allocatedAddresses = new List<IntPtr>();
    // Signature scan to find start/end of level_load
    var acknex = Array.Find(modules, m => m.ModuleName == "acknex.dll");
    SignatureScanner scanner = new SignatureScanner(game, acknex.BaseAddress, acknex.ModuleMemorySize);
    var startSig = new SigScanTarget(0, "F6 05 ?? ?? ?? ?? 40 74");
    var endSig = new SigScanTarget(0, "C7 05 ?? ?? ?? ?? 00 00 00 00 C1");
    IntPtr levelLoadStart = scanner.Scan(startSig);
    IntPtr levelLoadEnd = scanner.Scan(endSig);
    if (levelLoadStart == IntPtr.Zero || levelLoadEnd == IntPtr.Zero){
        throw new Exception("Signature scanning failed");
    }

    byte[] origBytesStart = game.ReadBytes(levelLoadStart, 7);
    byte[] origBytesEnd = game.ReadBytes(levelLoadEnd, 10);

    // Allocate memory for output bool
    IntPtr isLoadingPtr = game.AllocateMemory(1);
    allocatedAddresses.Add(isLoadingPtr);
    byte[] outputPtrBytes = BitConverter.GetBytes((UInt32)isLoadingPtr);

    // Prepare payloads
    byte[] payloadStart = new byte[] { 0xC6, 0x05 } // mov byte ptr [...
        .Concat(outputPtrBytes) // ...isLoadingPtr] ...
        .Concat(new byte[] { 0x01 }) // ... 1
        .ToArray();

    byte[] payloadEnd = new byte[] { 0xC6, 0x05 } // mov byte ptr [...
        .Concat(outputPtrBytes) // ...isLoadingPtr] ...
        .Concat(new byte[] { 0x00 }) // ... 1
        .ToArray();

    // Allocate memory for payloads
    IntPtr hookStart = game.AllocateMemory(payloadStart.Length + 5);
    IntPtr hookEnd = game.AllocateMemory(payloadEnd.Length + 5);
    allocatedAddresses.Add(hookStart);
    allocatedAddresses.Add(hookEnd);

    // Prepare cleanup
    Action cleanup = () => {
        foreach (IntPtr address in allocatedAddresses)
        {
            game.FreeMemory(address);
        }
        game.Suspend();
        try {
            game.WriteBytes(levelLoadStart, origBytesStart);
            game.WriteBytes(levelLoadEnd, origBytesEnd);
        } 
        catch { throw; }
        finally { game.Resume(); }
    };
    vars.cleanup = cleanup;

    // Write detours
    game.Suspend();
    try {
        IntPtr gateStart = game.WriteDetour(levelLoadStart, 7, hookStart);
        allocatedAddresses.Add(gateStart);
        IntPtr gateEnd = game.WriteDetour(levelLoadEnd, 10, hookEnd);
        allocatedAddresses.Add(gateEnd);
        game.WriteBytes(hookStart, payloadStart);
        game.WriteJumpInstruction(hookStart + payloadStart.Length, gateStart);
        game.WriteBytes(hookEnd, payloadEnd);
        game.WriteJumpInstruction(hookEnd + payloadEnd.Length, gateEnd);
    } catch {
        cleanup();
        throw;
    } finally {
        game.Resume();
    }

    // To access a watcher, each one must be given a name.
    vars.Watchers = new MemoryWatcherList
    {
        new MemoryWatcher<bool>(isLoadingPtr) { Name = "isLoading" }
    };
}

update
{
    vars.Watchers.UpdateAll(game);
    current.isLoading = vars.Watchers["isLoading"].Current;
}

isLoading
{
    return current.isLoading;
}

shutdown
{
    vars.cleanup();
}