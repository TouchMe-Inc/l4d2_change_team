#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TIMER_DELAY 5.0

static const char g_sCmdAliasSpectate[][] = { 
    	"sm_spec",
	"sm_s" 
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

bool g_bMapStarted;
bool g_bRoundStarted;
int g_iGameMode;

enum
{
	L4D2Gamemode_None = 0,
	L4D2Gamemode_Coop,
	L4D2Gamemode_Versus,
	L4D2Gamemode_Scavenge,
	L4D2Gamemode_Survival
}

public Plugin myinfo = { 
	name = "ChangeTeam",
	author = "TouchMe",
	description = "Change team with commands: spec, js, ji and etc",
	version = "1.0"
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
	// TurnClientToSpectate
	for (int i = 0; i < sizeof(g_sCmdAliasSpectate); i++) {
		RegConsoleCmd(g_sCmdAliasSpectate[i], Cmd_TurnClientToSpectate);
	}

	// TurnClientToSurvivors
	for (int i = 0; i < sizeof(g_sCmdAliasSurvivors); i++) {
		RegConsoleCmd(g_sCmdAliasSurvivors[i], Cmd_TurnClientToSurvivors);
	}

	// TurnClientToInfected
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

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void ConVarChange_CvarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateGameMode();
}

public void OnConfigsExecuted()
{
	UpdateGameMode();
}

public void OnClientConnected(int iClient) {
	if (g_bRoundStarted) {
		CreateTimer(TIMER_DELAY, Timer_RespectateClient, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Cmd_TurnClientToSpectate(int iClient, int iArgs)
{
	if (iClient == 0) {
		return Plugin_Handled;
	}

	
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);

	return Plugin_Handled;
}


public Action Cmd_TurnClientToSurvivors(int iClient, int iArgs)
{
	if (iClient == 0) {
		return Plugin_Handled;
	}

	ChangeClientTeamEx(iClient, L4D2Team_Survivor);

	return Plugin_Handled;
}


public Action Cmd_TurnClientToInfected(int iClient, int iArgs)
{
	if (iClient == 0 || g_iGameMode == L4D2Gamemode_Survival || g_iGameMode == L4D2Gamemode_Coop) {
		return Plugin_Handled;
	}

	ChangeClientTeamEx(iClient, L4D2Team_Infected);

	return Plugin_Handled;
}

public bool ChangeClientTeamEx(int iClient, L4D2Team team)
{
	if (GetClientTeamEx(iClient) == team) {
		return true;
	}

	if (team != L4D2Team_Survivor)
	{
		ChangeClientTeam(iClient, view_as<int> (team));
		return true;
	}
	else
	{
		int bot = FindSurvivorBot();
		if (bot > 0)
		{
			int flags = GetCommandFlags("sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags &~FCVAR_CHEAT);
			FakeClientCommand(iClient, "sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags);
			return true;
		}
	}

	return false;
}

public L4D2Team GetClientTeamEx(int iClient)
{
	return view_as<L4D2Team> (GetClientTeam(iClient));
}

public int FindSurvivorBot()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeamEx(client) == L4D2Team_Survivor)
		{
			return client;
		}
	}

	return -1;
}

public void UpdateGameMode()
{
	if (g_bMapStarted == false) {
		g_iGameMode = L4D2Gamemode_None;
		return;
	}
		
	char GameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), GameMode, 32);

	if (StrContains(GameMode, "versus", false) != -1) {
		g_iGameMode = L4D2Gamemode_Versus;
	} else if (StrContains(GameMode, "coop", false) != -1) {
		g_iGameMode = L4D2Gamemode_Coop;
	} else if (StrContains(GameMode, "survival", false) != -1) {
		g_iGameMode = L4D2Gamemode_Survival;
	} else if (StrContains(GameMode, "scavenge", false) != -1) {
		g_iGameMode = L4D2Gamemode_Scavenge;
	}
}

/*
* TIMER FOR CONNECTED
*/
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

public Action Timer_TurnClientToSpectate(Handle timer, int iClient)
{
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);
}
