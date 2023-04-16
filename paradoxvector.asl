state("Paradox_Vector")
{
    string15 levelName: "acknex.dll", 0x22D334;
}

startup
{
    vars.Log = (Action<object>)((output) => print("[Paradox Vector ASL] " + output));

    Dictionary<string, string> Levels = new Dictionary<string, string>() {
        {"Outline_001.wmb", "Dungeon 1"},
        {"Outline_002.wmb", "Dungeon 2"},
        {"Outline_003.wmb", "Dungeon 3"},
        {"Outline_004.wmb", "Dungeon 4"},
        {"Outline_005.wmb", "Dungeon 5"},
        {"Outline_006.wmb", "Dungeon 6"},
        {"Outline_007.wmb", "Dungeon 7"},
        {"Outline_008.wmb", "Dungeon 8"},
        {"Outline_009.wmb", "Dungeon 9"},
        {"Outline_010.wmb", "Ancient One Arena"},
        {"Outline_011.wmb", "Caves 1"},
        {"Outline_012.wmb", "Caves 2"},
        {"Outline_013.wmb", "Boss 2 Arena"},
        {"Outline_014.wmb", "Dungeon 14"},
        {"Outline_015.wmb", "Dungeon 15"},
        {"Outline_016.wmb", "Dungeon 16"},
        {"Outline_017.wmb", "Dungeon 17"},
        {"Outline_018.wmb", "Dungeon 18"},
        {"Outline_019.wmb", "Dungeon 19"},
        {"Outline_020.wmb", "Dungeon 20"},
    };

    settings.Add("split_triangle", false, "Split on collecting a paradox triangle");
    settings.Add("split_key", false, "Split on collecting key");
    settings.Add("split_boss", false, "Split on defeating a boss");
    settings.Add("split_enter", false, "Split on enter level");
    settings.Add("split_exit", false, "Split on exit level");

    foreach (string filename in Levels.Keys)
    {
        string description = Levels[filename];
        settings.Add("split_enter_"+filename, true, description, "split_enter");
        settings.Add("split_exit_"+filename, true, description, "split_exit");
    }
}

init
{
    ProcessModuleWow64Safe module = Array.Find(modules, (m) => m.ModuleName == "livesplitdata.dll");
    if (module == null) {
        throw new Exception("Could not locate livesplitdata.dll.");
    }
    var target = new SigScanTarget(0, "44 99 FC 01");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
    IntPtr data = scanner.Scan(target);
    if (data == IntPtr.Zero) {
        throw new Exception("Could not locate data struct.");
    }
    vars.Watchers = new MemoryWatcherList
    {
        new MemoryWatcher<bool>(data + 0x04) { Name = "isGameStarted" },
        new MemoryWatcher<bool>(data + 0x05) { Name = "isGameComplete" },
        new MemoryWatcher<bool>(data + 0x06) { Name = "isLoading" },
        new MemoryWatcher<int>(data + 0x08) { Name = "paradoxTrianglesCollected" },
        new MemoryWatcher<int>(data + 0x0C) { Name = "keysCollected" },
        new MemoryWatcher<int>(data + 0x10) { Name = "bossesDefeated" },
    };
}

update
{
    vars.Watchers.UpdateAll(game);
    current.isGameStarted = vars.Watchers["isGameStarted"].Current;
    current.isGameComplete = vars.Watchers["isGameComplete"].Current;
    current.isLoading = vars.Watchers["isLoading"].Current;
    current.paradoxTrianglesCollected = vars.Watchers["paradoxTrianglesCollected"].Current;
    current.keysCollected = vars.Watchers["keysCollected"].Current;
    current.bossesDefeated = vars.Watchers["bossesDefeated"].Current;
}

onStart
{
    vars.lastTriangles = current.paradoxTrianglesCollected;
    vars.lastKeys = current.keysCollected;
    vars.lastBosses = current.bossesDefeated;
    vars.SplitsDone = new List<string>();
}

start
{
    return current.isGameStarted && !old.isGameStarted;
}

isLoading
{
    return current.isLoading;
}

split
{
    var SplitEnabled = (Func<string, bool>)((splitName) => {
        if (settings[splitName] && !vars.SplitsDone.Contains(splitName)) {
            vars.SplitsDone.Add(splitName);
            return true;
        } else {
            return false;
        }
    });
    if (current.levelName != old.levelName) {
        vars.Log("Level Changed: " + old.levelName + " -> " + current.levelName);
        if (SplitEnabled("split_enter_"+current.levelName) || SplitEnabled("split_exit_"+old.levelName)) {
            return true;
        }
    }

    if(current.paradoxTrianglesCollected == vars.lastTriangles + 1) {
        vars.lastTriangles += 1;
        vars.Log("Paradox Triangles: " + old.paradoxTrianglesCollected + " -> " + current.paradoxTrianglesCollected);
        return settings["split_triangle"];
    }

    if(current.keysCollected == vars.lastKeys + 1) {
        vars.lastKeys += 1;
        vars.Log("Keys: " + old.keysCollected + " -> " + current.keysCollected);
        return settings["split_key"];
    }

    if(current.bossesDefeated == vars.lastBosses + 1) {
        vars.lastBosses += 1;
        vars.Log("Bosses: " + old.bossesDefeated + " -> " + current.bossesDefeated);
        return settings["split_boss"];
    }

    if(current.isGameComplete && !old.isGameComplete) {
        vars.Log("Game Complete");
        return true;
    }
}