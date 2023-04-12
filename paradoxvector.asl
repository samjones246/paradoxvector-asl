state("Paradox_Vector")
{
    string15 levelName: "acknex.dll", 0x22D334;
    bool isGameStarted: "livesplitdata.dll", 0x15004;
    bool isGameComplete: "livesplitdata.dll", 0x15005;
    bool isLoading: "livesplitdata.dll", 0x15006;
    int paradoxTrianglesCollected: "livesplitdata.dll", 0x15008;
    int keysCollected: "livesplitdata.dll", 0x1500C;
    int bossesDefeated: "livesplitdata.dll", 0x15010;
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
        {"Outline_010.wmb", "Dungeon 10"},
        {"Outline_011.wmb", "Dungeon 11"},
        {"Outline_012.wmb", "Dungeon 12"},
        {"Outline_013.wmb", "Dungeon 13"},
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
    if (current.levelName != old.levelName) {
        vars.Log("Level Changed: " + old.levelName + " -> " + current.levelName);
        return settings["split_exit_"+old.levelName] || settings["split_enter_"+current.levelName];
    }

    if(current.paradoxTrianglesCollected > old.paradoxTrianglesCollected) {
        vars.Log("Paradox Triangles: " + old.paradoxTrianglesCollected + " -> " + current.paradoxTrianglesCollected);
        return settings["split_triangle"];
    }

    if(current.keysCollected > old.keysCollected) {
        vars.Log("Keys: " + old.keysCollected + " -> " + current.keysCollected);
        return settings["split_key"];
    }

    if(current.bossesDefeated > old.bossesDefeated) {
        vars.Log("Bosses: " + old.bossesDefeated + " -> " + current.bossesDefeated);
        return settings["split_boss"];
    }

    if(current.isGameComplete && !old.isGameComplete) {
        vars.Log("Game Complete");
        return true;
    }
}