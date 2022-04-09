#include <sourcemod>
#include <sdktools>
#include <mix_team>

#undef REQUIRE_PLUGIN
#include <mix_team>
#define LIB_MIX_TEAM            "mix_team" 

#pragma semicolon               1
#pragma newdecls                required


public Plugin myinfo = { 
	name = "ChangeTeam",
	author = "TouchMe",
	description = "Change team with commands: spec, js, ji and etc",
	version = "1.0rc"
};


#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2 
#define TEAM_INFECTED           3

#define GAMEMODE_NONE           0
#define GAMEMODE_COOP           1
#define GAMEMODE_VERSUS         2
#define GAMEMODE_SCAVENGE       3
#define GAMEMODE_SURVIVAL       4

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_REAL_CLIENT(%1)      (IsClientInGame(%1) && !IsFakeClient(%1))
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)

#define TIMER_DELAY 5.0


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

bool 
	g_bRoundStarted = false,
	g_bMixTeamUpAvailable = false;

int g_iGameMode = GAMEMODE_NONE;

/**
 * Called before OnPluginStart.
 * 
 * @param myself      Handle to the plugin
 * @param late        Whether or not the plugin was loaded "late" (after map load)
 * @param error       Error message buffer in case load failed
 * @param err_max     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure 
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

/**
 * Called when the plugin is fully initialized and all known external references are resolved.
 * 
 * @noreturn
 */
public void OnPluginStart()
{
	InitCmds();
	InitEvents();
}

/**
  * Global event. Called when all plugins loaded.
  *
  * @noreturn
  */
public void OnAllPluginsLoaded() {
	g_bMixTeamUpAvailable = LibraryExists(LIB_MIX_TEAM);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  *
  * @noreturn
  */
public void OnLibraryRemoved(const char[] sName) 
{
	if (StrEqual(sName, LIB_MIX_TEAM)) {
		g_bMixTeamUpAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  *
  * @noreturn
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_MIX_TEAM)) {
		g_bMixTeamUpAvailable = true;
	}
}

/**
 * Fragment
 * 
 * @noreturn
 */
void InitCmds() 
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
}

/**
 * Fragment
 * 
 * @noreturn
 */
void InitEvents() 
{
	HookEvent("scavenge_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

/**
 * Round start event.
 */
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for( int iClient = 1; iClient <= MaxClients; iClient++ )
	{
		if (!IS_REAL_CLIENT(iClient) || !IS_SPECTATOR(iClient)) {
			continue;
		}

		RespectateClient(iClient);
	}

	g_bRoundStarted = true;
}

/**
 * Round end event.
 */
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	g_bRoundStarted = false;
}

/**
 * Called when a console variable's value is changed.
 * 
 * @param convar       Handle to the convar that was changed
 * @param oldValue     String containing the value of the convar before it was changed
 * @param newValue     String containing the new value of the convar
 * @noreturn
 */
public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	UpdateGameMode();
}

/**
 * Called when the map has loaded, servercfgfile (server.cfg) has been executed, and all plugin configs are done executing.
 * This will always be called once and only once per map. It will be called after OnMapStart().
 * 
 * @noreturn
*/
public void OnConfigsExecuted() {
	UpdateGameMode();
}

/**
 * Called once a client successfully connects.  This callback is paired with OnClientDisconnect.
 * 
 * @param iClient     Client indedx
 * @noreturn
 */
public void OnClientConnected(int iClient) 
{
	if (g_bRoundStarted) {
		CreateTimer(TIMER_DELAY, Timer_RespectateClient, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Cmd_TurnClientToSpectate(int iClient, int iArgs)
{
	if (!IS_VALID_CLIENT(iClient)) {
		return Plugin_Handled;
	}

	SetClientTeam(iClient, TEAM_SPECTATOR);

	return Plugin_Handled;
}

public Action Cmd_TurnClientToSurvivors(int iClient, int iArgs)
{
	if (!IS_VALID_CLIENT(iClient)) {
		return Plugin_Handled;
	}

	if (g_bMixTeamUpAvailable && IsMixTeam()) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(TEAM_SURVIVOR) > 0) {
		SetClientTeam(iClient, TEAM_SURVIVOR);
	}

	return Plugin_Handled;
}

public Action Cmd_TurnClientToInfected(int iClient, int iArgs)
{
	if (!IS_VALID_CLIENT(iClient)) {
		return Plugin_Handled;
	}

	if (g_iGameMode == GAMEMODE_SURVIVAL || g_iGameMode == GAMEMODE_COOP) {
		return Plugin_Handled;
	}

	if (g_bMixTeamUpAvailable && IsMixTeam()) {
		return Plugin_Handled;
	}

	if (GetFreeSlots(TEAM_INFECTED) > 0) {
		SetClientTeam(iClient, TEAM_INFECTED);
	}

	return Plugin_Handled;
}

/**
 * Sets the client team.
 * 
 * @param iClient     Client index
 * @param iTeam       Param description
 * @return            true if success
 */
bool SetClientTeam(int iClient, int iTeam)
{	
	if (!IS_VALID_CLIENT(iClient)) {
		return false;
	}

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

/**
 * Finds a free bot.
 * 
 * @return     Bot index or -1
 */
int FindSurvivorBot()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsFakeClient(iClient) && IS_SURVIVOR(iClient))
		{
			return iClient;
		}
	}

	return -1;
}

void UpdateGameMode()
{
	char sGameMode[16];
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
	if (IS_REAL_CLIENT(iClient) && IS_SPECTATOR(iClient)) {
		RespectateClient(iClient);
	}
}

void RespectateClient(int iClient)
{
	SetClientTeam(iClient, TEAM_INFECTED);
	CreateTimer(0.1, Timer_TurnClientToSpectate, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TurnClientToSpectate(Handle timer, int iClient) {
	if (IS_REAL_CLIENT(iClient)) {
		SetClientTeam(iClient, TEAM_SPECTATOR);
	}
}

int GetFreeSlots(int iTeam) 
{
	int iSlots = GetConVarInt(FindConVar("survivor_limit"));

	int iPlayers = 0;
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(!IS_REAL_CLIENT(iClient) || GetClientTeam(iClient) != iTeam) {
			continue;
		}

		iPlayers++;
	}

	return (iSlots - iPlayers);
}
