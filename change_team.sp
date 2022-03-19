#include <sourcemod>
#include <sdktools>

forward void OnMixStarted();
forward void OnMixStopped();

#pragma semicolon 1
#pragma newdecls required

#define TIMER_DELAY 3.0

static const char g_sCmdAliasSpectate[][] = { 
	"sm_spec",
	"sm_s",
	"sm_afk"
};

static const char g_sCmdAliasSurvivors[][] = { 
	"sm_surv",
	"sm_js",
	"sm_join"
};

static const char g_sCmdAliasInfected[][] = { 
	"sm_infect",
	"sm_ji" 
};

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

enum
{
	L4D2Gamemode_None = 0,
	L4D2Gamemode_Coop,
	L4D2Gamemode_Versus,
	L4D2Gamemode_Scavenge,
	L4D2Gamemode_Survival
}

bool g_bRoundStarted = false;
bool g_bMixStarted = false;
int g_iGameMode = L4D2Gamemode_None;

public Plugin myinfo = { 
	name = "ChangeTeam",
	author = "TouchMe",
	description = "Change team with commands: spec, js, ji and etc",
	version = "1.1.0"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Cmd_TurnClientToSpectate
	for (int i = 0; i < sizeof(g_sCmdAliasSpectate); i++) {
		RegConsoleCmd(g_sCmdAliasSpectate[i], Cmd_TurnClientToSpectate);
	}

	// Cmd_TurnClientToSurvivors
	for (int i = 0; i < sizeof(g_sCmdAliasSurvivors); i++) {
		RegConsoleCmd(g_sCmdAliasSurvivors[i], Cmd_TurnClientToSurvivors);
	}

	// Cmd_TurnClientToInfected
	for (int i = 0; i < sizeof(g_sCmdAliasInfected); i++) {
		RegConsoleCmd(g_sCmdAliasInfected[i], Cmd_TurnClientToInfected);
	}

	HookEvent("scavenge_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for( int iClient = 1; iClient <= MaxClients; iClient++ )
	{
		if (IsClientInGame(iClient) && GetClientTeamEx(iClient) == L4D2Team_Spectator) {
			RespectateClient(iClient);
		}
	}

	g_bRoundStarted = true;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	g_bRoundStarted = false;
}

public void ConVarChange_CvarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateGameMode();
}

public void OnConfigsExecuted()
{
	UpdateGameMode();
}

public void OnClientConnected(int iClient) 
{
	if (g_bRoundStarted) {
		CreateTimer(TIMER_DELAY, Timer_RespectateClient, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Cmd_TurnClientToSpectate(int iClient, int iArgs)
{
	if (!iClient) {
		return Plugin_Handled;
	}
	
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);

	return Plugin_Handled;
}

public Action Cmd_TurnClientToSurvivors(int iClient, int iArgs)
{
	if (!iClient) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(L4D2Team_Survivor)) {
		ChangeClientTeamEx(iClient, L4D2Team_Survivor);
	}

	return Plugin_Handled;
}

public Action Cmd_TurnClientToInfected(int iClient, int iArgs)
{
	if (!iClient || g_iGameMode == L4D2Gamemode_Survival || g_iGameMode == L4D2Gamemode_Coop) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(L4D2Team_Infected)) {
		ChangeClientTeamEx(iClient, L4D2Team_Infected);
	}

	return Plugin_Handled;
}

public void ChangeClientTeamEx(int iClient, L4D2Team team)
{
	if (GetClientTeamEx(iClient) == team) {
		return;
	}

	if (team != L4D2Team_Survivor) {
		ChangeClientTeam(iClient, view_as<int> (team));
	}
	else if (FindSurvivorBot() > 0)
	{
		int flags = GetCommandFlags("sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags &~FCVAR_CHEAT);
		FakeClientCommand(iClient, "sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags);
	}
}

public L4D2Team GetClientTeamEx(int iClient)
{
	return view_as<L4D2Team> (GetClientTeam(iClient));
}

public int FindSurvivorBot()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsFakeClient(iClient) && GetClientTeamEx(iClient) == L4D2Team_Survivor)
		{
			return iClient;
		}
	}

	return -1;
}

public void UpdateGameMode()
{
	char sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));

	if (StrContains(sGameMode, "versus", false) != -1) {
		g_iGameMode = L4D2Gamemode_Versus;
	} else if (StrContains(sGameMode, "coop", false) != -1) {
		g_iGameMode = L4D2Gamemode_Coop;
	} else if (StrContains(sGameMode, "survival", false) != -1) {
		g_iGameMode = L4D2Gamemode_Survival;
	} else if (StrContains(sGameMode, "scavenge", false) != -1) {
		g_iGameMode = L4D2Gamemode_Scavenge;
	}
}

public Action Timer_RespectateClient(Handle timer, int iClient)
{
	if (IsClientInGame(iClient) && GetClientTeamEx(iClient) == L4D2Team_Spectator) {
		RespectateClient(iClient);
	}
}

public void RespectateClient(int iClient)
{
	ChangeClientTeamEx(iClient, L4D2Team_Infected);
	CreateTimer(0.1, Timer_TurnClientToSpectate, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TurnClientToSpectate(Handle timer, int iClient) {
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);
}

int GetFreeSlots(L4D2Team team) 
{
	if (g_bMixStarted) {
		return 0;
	}

	int iSlots = 0;
	if (team == L4D2Team_Infected) {
		iSlots = GetConVarInt(FindConVar("z_max_player_zombies")); // TODO: move to global param
	}
	else if (team == L4D2Team_Survivor) 
	{
		for(int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient) && GetClientTeamEx(iClient) == team) {
				iSlots++;
			}
		}
	}

	int iPlayers = 0;
	for(int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if(IsClientInGame(iPlayer) && !IsFakeClient(iPlayer) && GetClientTeamEx(iPlayer) == team)
		{
			iPlayers++;
		}
	}

	return (iSlots - iPlayers);
}

public void OnMixStarted() {
	g_bMixStarted = true;
}

public void OnMixStopped() {
	g_bMixStarted = false;
}
