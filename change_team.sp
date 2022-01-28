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
	"sm_survival",
	"sm_js",
	"sm_join"
};

static const char g_sCmdAliasInfected[][] = { 
	"sm_infected",
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
	version = "1.0",
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
		RegConsoleCmd(g_sCmdAliasSpectate[i], TurnClientToSpectate);
	}

	// TurnClientToSurvivors
	for (int i = 0; i < sizeof(g_sCmdAliasSurvivors); i++) {
		RegConsoleCmd(g_sCmdAliasSurvivors[i], TurnClientToSurvivors);
	}

	// TurnClientToInfected
	for (int i = 0; i < sizeof(g_sCmdAliasInfected); i++) {
		RegConsoleCmd(g_sCmdAliasInfected[i], TurnClientToInfected);
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
	CheckGameMode();
}

public void OnConfigsExecuted()
{
	CheckGameMode();
}

public void OnClientConnected(int iClient) {
	if (g_bRoundStarted) {
		CreateTimer(TIMER_DELAY, Timer_RespectateClient, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

/*
* ACTION
*/
public Action TurnClientToSpectate(int iClient, int iArgs)
{
	if (iClient == 0) {
		return Plugin_Handled;
	}

	
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);

	return Plugin_Handled;
}

/*
* ACTION
*/
public Action TurnClientToSurvivors(int iClient, int iArgs)
{
	if (iClient == 0) {
		return Plugin_Handled;
	}

	ChangeClientTeamEx(iClient, L4D2Team_Survivor);

	return Plugin_Handled;
}

/*
* ACTION
*/
public Action TurnClientToInfected(int iClient, int iArgs)
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

public void CheckGameMode()
{
	if (g_bMapStarted == false) {
		g_iGameMode = L4D2Gamemode_None;
		return;
	}
		
	int entity = CreateEntityByName("info_gamemode");
	if (IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if (IsValidEntity(entity)) {// Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if(strcmp(output, "OnCoop") == 0)
		g_iGameMode = L4D2Gamemode_Coop;
	else if(strcmp(output, "OnSurvival") == 0)
		g_iGameMode = L4D2Gamemode_Survival;
	else if(strcmp(output, "OnVersus") == 0)
		g_iGameMode = L4D2Gamemode_Versus;
	else if(strcmp(output, "OnScavenge") == 0)
		g_iGameMode = L4D2Gamemode_Scavenge;
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

/*
* TIMER FOR EVENT
*/
public Action Timer_TurnClientToSpectate(Handle timer, int iClient)
{
	ChangeClientTeamEx(iClient, L4D2Team_Spectator);
}