#include <sourcemod>
#include <sdktools>

forward void OnMixStarted();
forward void OnMixStopped();

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2 
#define TEAM_INFECTED 3

#define GAMEMODE_NONE 0
#define GAMEMODE_COOP 1
#define GAMEMODE_VERSUS 2
#define GAMEMODE_SCAVENGE 3
#define GAMEMODE_SURVIVAL 4

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


bool g_bRoundStarted = false;
bool g_bMixStarted = false;
int g_iGameMode = GAMEMODE_NONE;

public Plugin myinfo = { 
	name = "ChangeTeam",
	author = "TouchMe",
	description = "Change team with commands: spec, js, ji and etc",
	version = "1.1.1"
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
		if (IsClientInGame(iClient) && IsSpectator(iClient)) {
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

	SetClientTeam(iClient, TEAM_SPECTATOR);

	return Plugin_Handled;
}

public Action Cmd_TurnClientToSurvivors(int iClient, int iArgs)
{
	if (!iClient) {
		return Plugin_Handled;
	}

	if (g_bMixStarted) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(TEAM_SURVIVOR) > 0) {
		SetClientTeam(iClient, TEAM_SURVIVOR);
	}

	return Plugin_Handled;
}

public Action Cmd_TurnClientToInfected(int iClient, int iArgs)
{
	if (!iClient) {
		return Plugin_Handled;
	}

	if (g_iGameMode == GAMEMODE_SURVIVAL || g_iGameMode == GAMEMODE_COOP) {
		return Plugin_Handled;
	}

	if (g_bMixStarted) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(TEAM_INFECTED) > 0) {
		SetClientTeam(iClient, TEAM_INFECTED);
	}

	return Plugin_Handled;
}

bool SetClientTeam(int iClient, int iTeam)
{
	if (GetClientTeam(iClient) == iTeam) {
		return true;
	}

	if (iTeam != TEAM_SURVIVOR) {
		ChangeClientTeam(iClient, iTeam);
		return true;
	}
	else if (FindSurvivorBot() > 0)
	{
		int flags = GetCommandFlags("sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags &~FCVAR_CHEAT);
		FakeClientCommand(iClient, "sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags);
		return true;
	}

	return false;
}

int FindSurvivorBot()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsFakeClient(iClient) && IsSurvivor(iClient))
		{
			return iClient;
		}
	}

	return -1;
}

bool IsSurvivor(int iClient) {
	return GetClientTeam(iClient) == TEAM_SURVIVOR;
}

bool IsSpectator(int iClient) {
	return GetClientTeam(iClient) == TEAM_SPECTATOR;
}

void UpdateGameMode()
{
	char sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));

	if (StrContains(sGameMode, "versus", false) != -1) {
		g_iGameMode = GAMEMODE_VERSUS;
	} else if (StrContains(sGameMode, "coop", false) != -1) {
		g_iGameMode = GAMEMODE_COOP;
	} else if (StrContains(sGameMode, "survival", false) != -1) {
		g_iGameMode = GAMEMODE_SURVIVAL;
	} else if (StrContains(sGameMode, "scavenge", false) != -1) {
		g_iGameMode = GAMEMODE_SCAVENGE;
	}
}

public Action Timer_RespectateClient(Handle timer, int iClient)
{
	if (IsClientInGame(iClient) && IsSpectator(iClient)) {
		RespectateClient(iClient);
	}
}

void RespectateClient(int iClient)
{
	SetClientTeam(iClient, TEAM_INFECTED);
	CreateTimer(0.1, Timer_TurnClientToSpectate, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TurnClientToSpectate(Handle timer, int iClient) {
	SetClientTeam(iClient, TEAM_SPECTATOR);
}

int GetFreeSlots(int iTeam) 
{
	int iClient;

	int iSlots = 0;
	if (iTeam == TEAM_INFECTED) {
		iSlots = GetConVarInt(FindConVar("z_max_player_zombies")); // TODO: move to global param
	}
	else if (iTeam == TEAM_SURVIVOR) 
	{
		for(iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient) && GetClientTeam(iClient) == iTeam) {
				iSlots++;
			}
		}
	}

	int iPlayers = 0;
	for(iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) == iTeam)
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
