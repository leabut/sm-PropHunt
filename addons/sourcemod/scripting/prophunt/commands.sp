#include "prophunt/include/phclient.inc"

// say /tp /third /thirdperson
public Action Cmd_ToggleThirdPerson(int client, int args) {
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    // Only allow Terrorists to use thirdperson view
    if (GetClientTeam(client) != CS_TEAM_T) {
        PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
        return Plugin_Handled;
    }

    if (!g_bInThirdPersonView[client]) {
        SetThirdPersonView(client, true);
        PrintToChat(client, "%s%t", PREFIX, "Type again for ego");
    } else {
        SetThirdPersonView(client, false);
    }

    return Plugin_Continue;
}

// say /whistle
public Action Cmd_PlayWhistle(int _client, int args) {
    PHClient client = GetPHClient(_client);

    // check if whistling is enabled
    if (!GetConVarBool(cvar_Whistle) || !client.isAlive)
        return Plugin_Handled;

    bool cvarWhistleSeeker = view_as<bool>(GetConVarInt(cvar_WhistleSeeker));

    if (cvarWhistleSeeker && client.team != CS_TEAM_CT) {
        PrintToChat(client.index, "%s%t", PREFIX, "Only counter-terrorists can use");
        return Plugin_Handled;
    }
    // only Ts are allowed to whistle
    else if (!cvarWhistleSeeker && client.team != CS_TEAM_T) {
        PrintToChat(client.index, "%s%t", PREFIX, "Only terrorists can use");
        return Plugin_Handled;
    }

    int cvarWhistleTimes = GetConVarInt(cvar_WhistleTimes);
    char buffer[128];
    char sound[MAX_WHISTLE_LENGTH];
    int soundIndex = GetRandomInt(0, g_WhistleSounds.Length - 1);
    g_WhistleSounds.GetString(soundIndex, sound, MAX_WHISTLE_LENGTH);
    PrintToServer("Whistle: %s", sound);
    Format(buffer, sizeof(buffer), "*/%s", sound);

    if (g_iWhistleCount[client.index] < cvarWhistleTimes) {
        if (!cvarWhistleSeeker) {
            EmitSoundToAll(buffer, client.index, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
            PrintToChatAll("%s%N %t", PREFIX, client, "whistled");
            g_iWhistleCount[client.index]++;
            PrintToChat(client.index, "%s%t", PREFIX, "whistles left", (cvarWhistleTimes - g_iWhistleCount[client.index]));
        } else {
            int target, iCount;
            float maxrange, range, clientOrigin[3];

            client.GetOrigin(clientOrigin);
            for (int i = 1; i <= MaxClients; i++) {
                PHClient c = GetPHClient(i);
                if (c && c.isAlive && c.team == CS_TEAM_T) {
                    iCount++;
                    float targetOrigin[3];
                    c.GetOrigin(targetOrigin);
                    range = GetVectorDistance(clientOrigin, targetOrigin);
                    if (range > maxrange) {
                        maxrange = range;
                        target = i;
                    }
                }
            }

            if (iCount > 1) {
                EmitSoundToAll(buffer, target, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
                PrintToChatAll("%s %N forced %N to whistle.", PREFIX, client, target);
                g_iWhistleCount[client.index]++;
                PrintToChat(client.index, "%s%t", PREFIX, "whistles left", (cvarWhistleTimes - g_iWhistleCount[client.index]));
            }
        }
    } else {
        PrintToChat(client.index, "%s%t", PREFIX, "whistle limit exceeded", cvarWhistleTimes);
    }

    return Plugin_Handled;
}

// say /help
public Action Cmd_DisplayHelp(int client, int args) {
    ShowMOTDPanel(client, "PropHunt", "https://tilastokeskus.github.io/sm-PropHunt/r_rules.html", MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}

// say /freeze
// Freeze hiders in position
public Action Cmd_Freeze(int _client, int args) {
    PHClient client = GetPHClient(_client);
    if (!GetConVarInt(cvar_HiderFreezeMode) || client.team != CS_TEAM_T || !client.isAlive)
        return Plugin_Handled;

    if (client.isFreezed) {
        client.SetFreezed(false);
        PrintToChat(client.index, "%s%t", PREFIX, "Hider Unfreezed");
    } else if (GetConVarBool(cvar_HiderFreezeInAir) || (GetEntityFlags(client.index) & FL_ONGROUND)) {
        client.SetFreezed(true);

        char buffer[128];
        Format(buffer, sizeof(buffer), "*/%s", g_sndFreeze);
        EmitSoundToClient(client.index, buffer);

        PrintToChat(client.index, "%s%t", PREFIX, "Hider Freezed");
    }

    return Plugin_Handled;
}

// Admin Command
// ph_force_whistle
// Forces a terrorist player to whistle
public Action ForceWhistle(int client, int args) {
    if (!GetConVarBool(cvar_Whistle)) {
        ReplyToCommand(client, "Disabled.");
        return Plugin_Handled;
    }

    if (GetCmdArgs() < 1) {
        ReplyToCommand(client, "Usage: ph_force_whistle <#userid|steamid|name>");
        return Plugin_Handled;
    }

    char player[70];
    GetCmdArg(1, player, sizeof(player));

    int target = FindTarget(client, player);
    if (target == -1)
        return Plugin_Handled;

    if (GetClientTeam(target) == CS_TEAM_T && IsPlayerAlive(target)) {
        char sound[MAX_WHISTLE_LENGTH];
        g_WhistleSounds.GetString(GetRandomInt(0, g_WhistleSounds.Length - 1), sound, MAX_WHISTLE_LENGTH);
        EmitSoundToAll(sound, target, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
        PrintToChatAll("%s%N %t", PREFIX, target, "whistled");
    } else {
        ReplyToCommand(client, "Hide and Seek: %t", "Only terrorists can use");
    }

    return Plugin_Handled;
}

// say /whoami
// displays the model name in chat again
public Action Cmd_DisplayModelName(int client, int args) {

    // only enable command, if player already chose a model
    if (!IsPlayerAlive(client) || g_iModelChangeCount[client] == 0)
        return Plugin_Handled;

    // only Ts can use a model
    if (GetClientTeam(client) != CS_TEAM_T) {
        PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
        return Plugin_Handled;
    }

    char modelName[128];
    GetClientModel(client, modelName, sizeof(modelName));
    PrintToChat(client, "%s%t\x01 %s.", PREFIX, "Model Changed", modelName);

    return Plugin_Handled;
}

// say /ct
public Action Cmd_RequestCT(int client, int args) {
    if (GetClientTeam(client) == CS_TEAM_CT) {
        PrintToChat(client, "%s You are already on the seeking side", PREFIX);
        return Plugin_Handled;
    }

    if (g_iHiderToSeekerQueue[client] != NOT_IN_QUEUE) {
        PrintToChat(client, "%s You are already in the queue", PREFIX);
        return Plugin_Stop;
    }

    g_iHidersInSeekerQueue++;
    g_iHiderToSeekerQueue[client] = g_iHidersInSeekerQueue;

    PrintToChat(client, "%s You are now in the seeker queue", PREFIX);
    PrintToChat(client, "%s Turns until team switch: %d", PREFIX, SimulateTurnsToSeeker(g_iHidersInSeekerQueue));

    return Plugin_Handled;
}

public Action Cmd_JoinTeam(int client, int args) {
    PrintToServer("CT ratio: %f", GetConVarFloat(cvar_CTRatio));
    if (!client || !IsClientInGame(client) || FloatCompare(GetConVarFloat(cvar_CTRatio), 0.0) == 0) {
        PrintToServer("JoinTeam: team balance disabled");
        return Plugin_Continue;
    }

    char arg[5];
    if (!GetCmdArgString(arg, sizeof(arg))) {
        return Plugin_Continue;
    }

    int team = StringToInt(arg);

    // Player wants to join CT
    if (team == CS_TEAM_CT) {
        int iCTCount = GetTeamClientCount(CS_TEAM_CT);
        int iTCount = GetTeamClientCount(CS_TEAM_T);

        // This client would be in CT if we continue.
        iCTCount++;

        // And would leave T
        if (GetClientTeam(client) == CS_TEAM_T)
            iTCount--;

        // Check, how many terrors are going to get switched to ct at the end of the round
        for (int i = 1; i <= MaxClients; i++) {
            if (g_bCTToSwitch[i]) {
                iCTCount--;
                iTCount++;
            }
        }

        float fRatio = FloatDiv(float(iCTCount), float(iTCount));

        float fCFGRatio = FloatDiv(1.0, GetConVarFloat(cvar_CTRatio));

        //PrintToServer("Debug: Player %N wants to join CT. CTCount: %d TCount: %d Ratio: %f", client, iCTCount, iTCount, FloatDiv(float(iCTCount), float(iTCount)));

        // There are more CTs than we want in the CT team.
        if (iCTCount > 1 && fRatio > fCFGRatio) {
            PrintCenterText(client, "CT team is full");
            //PrintToServer("Debug: Blocked.");
            return Plugin_Stop;
        }
    } else if (team == CS_TEAM_T) {
        int iCTCount = GetTeamClientCount(CS_TEAM_CT);
        int iTCount = GetTeamClientCount(CS_TEAM_T);

        iTCount++;

        if (GetClientTeam(client) == CS_TEAM_CT)
            iCTCount--;

        if (iCTCount == 0 && iTCount >= 2) {
            PrintCenterText(client, "Cannot leave CT empty");
            //PrintToServer("Debug: Blocked.");
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

public Action Cmd_SelectModelMenu(int client, int args) {
   return ShowSelectModelMenu(client, args); 
}