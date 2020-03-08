#include <sourcemod>
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

bool gB_Challenge[MAXPLAYERS + 1];
bool gB_Challenge_Abort[MAXPLAYERS + 1];
bool gB_Challenge_Request[MAXPLAYERS + 1];
bool gB_Late = false;
bool gB_Bonus = false;
char gS_Challenge_OpponentID[MAXPLAYERS + 1][32];
char gS_SteamID[MAXPLAYERS + 1][32];
int gI_CountdownTime[MAXPLAYERS + 1];
int gI_Styles = 0;
int gI_ChallengeStyle[MAXPLAYERS + 1];
int gI_Track[MAXPLAYERS + 1];
int gI_ClientTrack[MAXPLAYERS + 1];
chatstrings_t gS_ChatStrings;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

public Plugin myinfo = 
{
	name = "Shavit Race Mode",
	author = "Evan",
	description = "Allows players to race each other",
	version = "1.1.0"
}

public void OnPluginStart()
{
	LoadTranslations("shavit-challenge.phrases");
	LoadTranslations("shavit-common.phrases");

	RegConsoleCmd("sm_challenge", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_race", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_accept", Client_Accept, "[Challenge] allows you to accept a challenge request");
	RegConsoleCmd("sm_surrender", Client_Surrender, "[Challenge] surrender your current challenge");
	RegConsoleCmd("sm_abort", Client_Abort, "[Challenge] abort your current challenge");
	
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
		
		Shavit_OnChatConfigLoaded();
		Shavit_OnStyleConfigLoaded(-1);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, gS_SteamID[client], MAX_NAME_LENGTH, true);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			gB_Challenge[i] = false;
			gB_Challenge_Request[i] = false;	
		}
	}
}

public void OnMapStart()
{
	//not optimal. need a shavit_onzonesloaded or something
	CreateTimer(15.0, Timer_CheckBonus);
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
	}

	gI_Styles = styles;
}

public Action Client_Challenge(int client, int args)
{
	if (!gB_Challenge[client] && !gB_Challenge_Request[client])
	{
		if (IsPlayerAlive(client))
		{
			char sPlayerName[MAX_NAME_LENGTH];
			Menu menu = new Menu(ChallengeMenuHandler);
			menu.SetTitle("%T", "ChallengeMenuTitle", client);
			int playerCount = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && IsPlayerAlive(i) && i != client && !IsFakeClient(i))
				{
					GetClientName(i, sPlayerName, MAX_NAME_LENGTH);
					menu.AddItem(sPlayerName, sPlayerName);
					playerCount++;
				}
			}
			
			if (playerCount > 0)
			{
				menu.ExitButton = true;
				menu.Display(client, 30);
			}
			
			else
			{
				Shavit_PrintToChat(client, "%T", "ChallengeNoPlayers", client);
			}
		}
		
		else
		{
			Shavit_PrintToChat(client, "%T", "ChallengeInRace", client);
		}
	}
	
	return Plugin_Handled;
}

public int ChallengeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		char sPlayerName[MAX_NAME_LENGTH];
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
		menu.GetItem(param2, sInfo, 32);
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				GetClientName(i, sTargetName, MAX_NAME_LENGTH);

				if (StrEqual(sInfo, sTargetName))
				{
					if (!gB_Challenge[i])
					{
						char sSteamId[32];
						GetClientAuthId(i, AuthId_Steam2, sSteamId, MAX_NAME_LENGTH, true);
						Format(gS_Challenge_OpponentID[param1], 32, sSteamId);
						SelectStyle(param1);		
					}
					
					else
					{
						Shavit_PrintToChat(param1, "%T", "ChallengeOpponentInRace", param1, gS_ChatStrings.sVariable2, sTargetName, gS_ChatStrings.sText);
					}
				}
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void SelectStyle(int param1)
{
	Menu menu = new Menu(ChallengeMenuHandler2);
	menu.SetTitle("%T", "ChallengeMenuTitle2", param1);
	
	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int j = 0; j < gI_Styles; j++)
	{
		int iStyle = styles[j];

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);
		menu.AddItem(sInfo, gS_StyleStrings[iStyle].sStyleName);
	}
	
	menu.ExitButton = true;
	menu.Display(param1, 30);
}

public int ChallengeMenuHandler2(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		int style = StringToInt(sInfo);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[param1]))
				{
					gI_ChallengeStyle[i] = style;
					gI_ChallengeStyle[param1] = style;
					
					if(gB_Bonus)
					{
						SelectTrack(param1);
					}
					
					else if(!gB_Bonus)
					{						
						char sTargetName[32];
						char sPlayerName[32];	
						char sTrack[8];
						sTrack = "Main";
						gI_Track[param1] = Track_Main;
						GetClientName(i, sTargetName, MAX_NAME_LENGTH);
						GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
						Shavit_PrintToChat(param1, "%T", "ChallengeRequestSent", param1, gS_ChatStrings.sVariable2, sTargetName);
						Shavit_PrintToChat(i, "%T", "ChallengeRequestReceive", i, gS_ChatStrings.sVariable2, sPlayerName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, gS_StyleStrings[gI_ChallengeStyle[param1]].sStyleName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, sTrack, gS_ChatStrings.sText, gS_ChatStrings.sVariable);		
						CreateTimer(20.0, Timer_Request, GetClientUserId(param1));
						gB_Challenge_Request[param1] = true;
					}
				}	
			}	
		}	
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void SelectTrack(int param1)
{
	char sInfo[8];
	Menu menu = new Menu(ChallengeMenuHandler3);
	menu.SetTitle("%T", "ChallengeMenuTitle3", param1);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		IntToString(i, sInfo, 8);

		char sTrack[32];
		GetTrackName(param1, i, sTrack, 32);

		menu.AddItem(sInfo, sTrack);
	}
	
	menu.ExitButton = true;
	menu.Display(param1, 30);
}

public int ChallengeMenuHandler3(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{	
		char sInfo[8];
		char sTrack[8];
		menu.GetItem(param2, sInfo, 8);
		int gI_TrackSelect = StringToInt(sInfo);
		gI_Track[param1] = gI_TrackSelect;
		if(gI_Track[param1] == 0)
		{
			sTrack = "Main";
		}
		else if(gI_Track[param1] == 1)
		{
			sTrack = "Bonus";
		}
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != param1)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[param1]))
				{
					char sTargetName[32];
					char sPlayerName[32];		
					GetClientName(i, sTargetName, MAX_NAME_LENGTH);
					GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
					Shavit_PrintToChat(param1, "%T", "ChallengeRequestSent", param1, gS_ChatStrings.sVariable2, sTargetName);
					Shavit_PrintToChat(i, "%T", "ChallengeRequestReceive", i, gS_ChatStrings.sVariable2, sPlayerName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, gS_StyleStrings[gI_ChallengeStyle[param1]].sStyleName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, sTrack, gS_ChatStrings.sText, gS_ChatStrings.sVariable);		
					CreateTimer(20.0, Timer_Request, GetClientUserId(param1));
					gB_Challenge_Request[param1] = true;
				}
			}
		}
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Client_Accept(int client, int args)
{
	char sSteamId[32];
	char sTrack[8];
	GetClientAuthId(client, AuthId_Steam2, sSteamId, MAX_NAME_LENGTH, true);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != client && gB_Challenge_Request[i])
		{
			if (StrEqual(sSteamId, gS_Challenge_OpponentID[i]))
			{
				GetClientAuthId(i, AuthId_Steam2, gS_Challenge_OpponentID[client], MAX_NAME_LENGTH, true);
				gB_Challenge_Request[i] = false;
				
				gB_Challenge_Abort[client] = false;
				gB_Challenge_Abort[i] = false;

				Shavit_ChangeClientStyle(client, gI_ChallengeStyle[client]);
				Shavit_ChangeClientStyle(i, gI_ChallengeStyle[i]);
				
				gB_Challenge[client] = true;
				gB_Challenge[i] = true;
				
				Shavit_RestartTimer(client, gI_Track[i]);
				Shavit_RestartTimer(i, gI_Track[i]);
				
				gI_ClientTrack[client] = gI_Track[i];
				gI_ClientTrack[i] = gI_Track[i];
				
				SetEntityMoveType(client, MOVETYPE_NONE);
				SetEntityMoveType(i, MOVETYPE_NONE);
				
				Shavit_StopTimer(client);
				Shavit_StopTimer(i);
				
				gI_CountdownTime[client] = 5;
				gI_CountdownTime[i] = 5;
				
				CreateTimer(1.0, Timer_Countdown, client, TIMER_REPEAT);
				CreateTimer(1.0, Timer_Countdown, i, TIMER_REPEAT);
				
				Shavit_PrintToChat(client, "%T", "ChallengeAccept", client);
				Shavit_PrintToChat(i, "%T", "ChallengeAccept", i);
				
				char sPlayer1[MAX_NAME_LENGTH];
				char sPlayer2[MAX_NAME_LENGTH];
				
				GetClientName(i, sPlayer1, MAX_NAME_LENGTH);
				GetClientName(client, sPlayer2, MAX_NAME_LENGTH);
				
				if(gI_Track[i] == 0)
				{
					sTrack = "Main";
				}
				else if(gI_Track[i] == 1)
				{
					sTrack = "Bonus";
				}

				Shavit_PrintToChatAll("%t", "ChallengeAnnounce", sPlayer1, sPlayer2, gS_ChatStrings.sStyle, gS_StyleStrings[gI_ChallengeStyle[client]].sStyleName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, sTrack);
				
				CreateTimer(1.0, CheckChallenge, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(1.0, CheckChallenge, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Client_Surrender(int client, int args)
{
	char sSteamIdOpponent[32];
	char sNameOpponent[MAX_NAME_LENGTH];
	char sName[MAX_NAME_LENGTH];
	if (gB_Challenge[client])
	{
		GetClientName(client, sName, MAX_NAME_LENGTH);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				GetClientAuthId(i, AuthId_Steam2, sSteamIdOpponent, MAX_NAME_LENGTH, true);
				if (StrEqual(sSteamIdOpponent, gS_Challenge_OpponentID[client]))
				{
					GetClientName(i, sNameOpponent, MAX_NAME_LENGTH);
					gB_Challenge[i] = false;
					gB_Challenge[client] = false;

					for (int j = 1; j <= MaxClients; j++)
					{
						if (IsValidClient(j) && IsValidEntity(j))
						{
							Shavit_PrintToChat(j, "%T", "ChallengeSurrenderAnnounce", j, gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sWarning);
						}
					}

					SetEntityMoveType(client, MOVETYPE_WALK);
					SetEntityMoveType(i, MOVETYPE_WALK);
					
					i = MaxClients + 1;
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Client_Abort(int client, int args)
{
	if (gB_Challenge[client])
	{
		if (gB_Challenge_Abort[client])
		{
			gB_Challenge_Abort[client] = false;
			Shavit_PrintToChat(client, "%T", "ChallengeDisagreeAbort", client);
		}
		
		else
		{
			gB_Challenge_Abort[client] = true;
			Shavit_PrintToChat(client, "%T", "ChallengeAgreeAbort", client);		
		}
	}
	
	return Plugin_Handled;
}

public Action Timer_Countdown(Handle timer, any client)
{		
	if (IsValidClient(client) && gB_Challenge[client] && !IsFakeClient(client))
	{
		Shavit_PrintToChat(client, "%T", "ChallengeCountdown", client, gI_CountdownTime[client]);
		gI_CountdownTime[client]--;
		
		if (gI_CountdownTime[client] < 1)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted1", client);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted2", client, gS_ChatStrings.sVariable);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted3", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText);
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Request(Handle timer, any data)
{	
	int client = GetClientOfUserId(data);
	
	if(!gB_Challenge[client] && gB_Challenge_Request[client])
	{
		Shavit_PrintToChat(client, "%T", "ChallengeExpire", client);
		gB_Challenge_Request[client] = false;
	}
}

public Action Timer_CheckBonus(Handle timer, any data)
{
	if(Shavit_ZoneExists(Zone_Start, Track_Bonus))
	{
		gB_Bonus = true;
	}
}

public Action CheckChallenge(Handle timer, any client)
{
	bool oppenent = false;
	char sName[32];
	char sNameTarget[32];
	if (gB_Challenge[client] && IsValidClient(client) && !IsFakeClient(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					oppenent = true;
					if (gB_Challenge_Abort[i] && gB_Challenge_Abort[client])
					{
						GetClientName(i, sNameTarget, 32);
						GetClientName(client, sName, 32);
						
						gB_Challenge[client] = false;
						gB_Challenge[i] = false;
						
						Shavit_PrintToChat(client, "%T", "ChallengeAborted", client, gS_ChatStrings.sVariable2, sNameTarget, gS_ChatStrings.sText);
						Shavit_PrintToChat(i, "%T", "ChallengeAborted",  i, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sText);
						
						SetEntityMoveType(client, MOVETYPE_WALK);
						SetEntityMoveType(i, MOVETYPE_WALK);
					}
				}
			}
		}
		
		if (!oppenent)
		{
			gB_Challenge[client] = false;

			if (IsValidClient(client))
			{
				Shavit_PrintToChat(client, "%T", "ChallengeWon", client);
			}
			
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	if(gB_Challenge[client] && track == gI_ClientTrack[client])
	{
		char sNameOpponent[MAX_NAME_LENGTH];
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, MAX_NAME_LENGTH);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					gB_Challenge[client] = false;
					gB_Challenge[i] = false;
					GetClientName(i, sNameOpponent, MAX_NAME_LENGTH);
					Shavit_PrintToChatAll("%t", "ChallengeFinishAnnounce", gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sNameOpponent);
				}
			}
		}
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if(gB_Challenge[client])
	{	
		char sNameOpponent[MAX_NAME_LENGTH];
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, MAX_NAME_LENGTH);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					gB_Challenge[client] = false;
					gB_Challenge[i] = false;
					GetClientName(i, sNameOpponent, MAX_NAME_LENGTH);
					Shavit_PrintToChatAll("%t", "ChallengeStyleChange", gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sWarning);
				}
			}
		}	
	}
}

void GetTrackName(int client, int track, char[] output, int size)
{
	if(track < 0 || track >= TRACKS_SIZE)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);

		return;
	}

	static char sTrack[16];
	FormatEx(sTrack, 16, "Track_%d", track);
	FormatEx(output, size, "%T", sTrack, client);
}