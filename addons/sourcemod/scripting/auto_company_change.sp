#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <l4d2_changelevel>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "AutoCompanyChange",
	author = "TouchMe",
	description = "Automatic company change",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_auto_company_change"
}


#define LIB_CHANGELEVEL    "l4d2_changelevel"

#define CONFIG_PATH        "configs/auto_company_change.txt"


char g_sCurrentMap[32];

Handle
	g_hCompanies = null,
	g_hCompanyFlow = null
;

bool g_bChangeLevelAvailable = false;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
	g_bChangeLevelAvailable = LibraryExists(LIB_CHANGELEVEL);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, LIB_CHANGELEVEL)) {
		g_bChangeLevelAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_CHANGELEVEL)) {
		g_bChangeLevelAvailable = true;
	}
}

/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadCompanies(g_hCompanies = CreateKeyValues("Companies"));
	FillCompanyFlow(g_hCompanies, g_hCompanyFlow = CreateTrie());

	char sMessageName[64];

	for (int i = 1; ; i++)
	{
		if (!GetUserMessageName(view_as<UserMsg>(i), sMessageName, sizeof(sMessageName))) {
			break;
		}

		if (StrEqual(sMessageName, "PZEndGamePanelMsg"))
		{
			HookUserMessage(view_as<UserMsg>(i), OnMessage, true);
			break;
		}
	}
}

public Action OnMessage(UserMsg msg_id, BfRead hMsg, const int[] players, int playersNum, bool reliable, bool init)
{
	char sNextMap[32];

	if (GetNextCompaing(g_sCurrentMap, sNextMap, sizeof(sNextMap))) {
		ChangeMap(sNextMap);
	}

	return Plugin_Handled;
}

public void OnMapInit(const char[] sMapName) {
	strcopy(g_sCurrentMap, sizeof(g_sCurrentMap), sMapName);
}

void LoadCompanies(Handle hCompanies)
{
	char sPath[PLATFORM_MAX_PATH ];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_PATH);

	if (!FileExists(sPath)) {
		SetFailState("Couldn't load %s", sPath);
	}

 	if (!FileToKeyValues(hCompanies, sPath)) {
		SetFailState("Failed to parse keyvalues for %s", sPath);
	}
}

void FillCompanyFlow(Handle hCompanies, Handle hCompanyFlow)
{
	if (KvGotoFirstSubKey(hCompanies, false))
	{
		char sKey[32], sValue[32];

		do
		{
			KvGetSectionName(hCompanies, sKey, sizeof(sKey));
			KvGetString(hCompanies, "next", sValue, sizeof(sValue));

			SetTrieString(hCompanyFlow, sKey, sValue);
		} while (KvGotoNextKey(hCompanies, false));
	}
}

bool GetNextCompaing(const char[] sMap, char[] sNextMap, int iLength)
{
	if (GetTrieString(g_hCompanyFlow, sMap, sNextMap, iLength)) {
		return true;
	}

	if (GetTrieString(g_hCompanyFlow, "default", sNextMap, iLength)) {
		return true;
	}

	return false;
}

void ChangeMap(const char[] sMap)
{
	if (g_bChangeLevelAvailable) {
		L4D2_ChangeLevel(sMap);
	} else {
		ServerCommand("changelevel %s", sMap);
	}
}
