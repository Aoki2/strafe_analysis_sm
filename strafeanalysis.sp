#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
    name = "Strafe Analysis",
    author = "Aoki",
    description = "Get stat dump for player movement",
    version = PLUGIN_VERSION,
    url = ""
}

//-------------------------------------------------------------------------
// Includes
//-------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

//-------------------------------------------------------------------------
// Defines 
//-------------------------------------------------------------------------
#define LOG_DEBUG_ENABLE 1
#define LOG_TO_CHAT 1
#define LOG_TO_SERVER 1
#define LOG_TO_FILE 0
#define ONLY_CAPTURE_ON_POSITION_CHANGE 0

//-------------------------------------------------------------------------
// Types 
//-------------------------------------------------------------------------
enum teLogType
{
	eeLogHeader,
	eeLogLine
};

//-------------------------------------------------------------------------
// Globals 
//-------------------------------------------------------------------------
new String:gpanLogFile[127];
new gnTick = 0;

//Player data
new Float:gaarPlayerOrigin[MAXPLAYERS+1][3];
new Float:gaarPlayerVelocity[MAXPLAYERS+1][3];
new Float:gaarPlayerNormalizedVelocity[MAXPLAYERS+1][3];
new Float:garPlayerXyzVelScalar[MAXPLAYERS+1];
new Float:garPlayerXyVelScalar[MAXPLAYERS+1];

//Pitch, yaw, roll
new Float:gaarPlayerEyeAngles[MAXPLAYERS+1][3];
new Float:gaarPlayerEyePos[MAXPLAYERS+1][3];
new Float:garPlayerRotation[MAXPLAYERS+1][3];

new ganPlayerButtons[MAXPLAYERS+1];
new bool:gaaeButtonHolds[MAXPLAYERS+1][32];
new bool:gaaeButtonPress[MAXPLAYERS+1][32];

new bool:ganPlayerOnGround[MAXPLAYERS+1];
new bool:ganPlayerDucking[MAXPLAYERS+1];
new bool:gaePlayerInJump[MAXPLAYERS+1] = { false, ... };

new bool:gaeEnable = false;

//-------------------------------------------------------------------------
// Functions 
//-------------------------------------------------------------------------
public OnPluginStart()
{   
	BuildPath(Path_SM, gpanLogFile, sizeof(gpanLogFile), "logs/strafeanalysis.txt");
	
	HookEvent("player_jump", evPlayerJump, EventHookMode_Post);
	RegAdminCmd("sa_start",cbStrafeAnalysisStart,ADMFLAG_KICK,"Strafe analysis start");
	RegAdminCmd("sa_stop",cbStrafeAnalysisStop,ADMFLAG_KICK,"Strafe analysis stop");
		
	CreateConVar("strafe_analysis_version", PLUGIN_VERSION, "strafe analysis version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
}

public Action:cbStrafeAnalysisStart(anClient, ahArgs)
{
	if(FileExists(gpanLogFile))
	{
		DeleteFile(gpanLogFile);
	}
	
	WriteLogLine(0,eeLogHeader);

	gnTick = 0;
	gaeEnable = true;
 	return Plugin_Handled;
}

public Action:cbStrafeAnalysisStop(anClient, ahArgs)
{
	gaeEnable = false;
 	return Plugin_Handled;
}

public LogDebug(const String:aapanFormat[], any:...)
{
#if LOG_DEBUG_ENABLE == 1
	decl String:ppanBuffer[512];
	
	VFormat(ppanBuffer, sizeof(ppanBuffer), aapanFormat, 2);
#if LOG_TO_CHAT == 1
	PrintToChatAll("%s", ppanBuffer);
#endif
#if LOG_TO_SERVER == 1
	PrintToServer("%s", ppanBuffer);
#endif
#if LOG_TO_FILE == 1
	LogToFile(gpanLogFile,"%s", ppanBuffer);
#endif
#endif
}

public OnGameFrame()
{
	decl Float:paarPrevPlayerOrigin[MAXPLAYERS+1][3];
	decl pnIndex;
	
	if(gaeEnable)
	{
		gnTick++;
		
		if(gnTick < 0)
		{
			gnTick = 0;
		}
		
		for(pnIndex=1;pnIndex<MaxClients;pnIndex++)
		{
			if(IsClientConnected(pnIndex) && IsClientAuthorized(pnIndex)  &&
			   IsClientInGame(pnIndex) && IsPlayerAlive(pnIndex) && GetClientTeam(pnIndex) > 1)
			{
				UpdateClientOrigin(pnIndex);
		
#if ONLY_CAPTURE_ON_POSITION_CHANGE == 1
				if(IsVectorEqual(paarPrevPlayerOrigin[pnIndex],gaarPlayerOrigin[pnIndex]) == false)
				{
					UpdateAndWriteStats(pnIndex);
				}
#else
				UpdateAndWriteStats(pnIndex);
#endif
			
				paarPrevPlayerOrigin[pnIndex][0] = gaarPlayerOrigin[pnIndex][0];
				paarPrevPlayerOrigin[pnIndex][1] = gaarPlayerOrigin[pnIndex][1];
				paarPrevPlayerOrigin[pnIndex][2] = gaarPlayerOrigin[pnIndex][2];
			}
		}
	}
}

bool:IsVectorEqual(Float:arVector1[],Float:arVector2[])
{
	new bool:leReturn = true;
	new lnVectorLen = sizeof(arVector1[]);
	
	if(lnVectorLen == sizeof(arVector2[]))
	{
		for(new i=0;i<lnVectorLen;i++)
		{
			if(FloatAbs(arVector1[i] - arVector2[i]) > 0.0001)
			{
				leReturn = false;
				break;
			}
		}
	}
	else
	{
		leReturn = false;
	}
	
	return leReturn;
}

UpdateClientFlags(anClient)
{
	new lnFlags = GetEntityFlags(anClient);
	
	if(lnFlags & FL_ONGROUND)
	{
		ganPlayerOnGround[anClient] = true;
	}
	else
	{
		ganPlayerOnGround[anClient] = false;
	}
	
	if(lnFlags & FL_DUCKING)
	{
		ganPlayerDucking[anClient] = true;
	}
	else
	{
		ganPlayerDucking[anClient] = false;
	}
}

UpdateAndWriteStats(anClient)
{
	UpdateClientVelocityInfo(anClient);
	UpdateClientOrientation(anClient);
	UpdateClientFlags(anClient);
	
	WriteLogLine(anClient);
}

WriteLogLine(anClient, teLogType:aeType = eeLogLine)
{
	decl String:ppanLogLine[1024];
	static pnMaxLen = sizeof(ppanLogLine);
	
	ppanLogLine = "";
	
	if(aeType == eeLogHeader)
	{
	/* 1  */ AppendToLogLine(ppanLogLine,pnMaxLen,"Client,");
	/* 2  */ AppendToLogLine(ppanLogLine,pnMaxLen,"Tick,");
	/* 3  */ AppendToLogLine(ppanLogLine,pnMaxLen,"OriginX,OriginY,OriginZ,");
	/* 4  */ AppendToLogLine(ppanLogLine,pnMaxLen,"VelX,VelY,VelZ,");
	/* 5  */ AppendToLogLine(ppanLogLine,pnMaxLen,"NormVelX,NormVelY,NormVelZ,");
	/* 6  */ AppendToLogLine(ppanLogLine,pnMaxLen,"VelXyzScalar,");
	/* 7  */ AppendToLogLine(ppanLogLine,pnMaxLen,"VelXyScalar,");
	/* 8  */ AppendToLogLine(ppanLogLine,pnMaxLen,"EyePitch,EyeYaw,EyeRoll,");
	/* 9  */ AppendToLogLine(ppanLogLine,pnMaxLen,"EyePosX,EyePosY,EyePosZ,");
	/* 10 */ AppendToLogLine(ppanLogLine,pnMaxLen,"RotX,RotY,RotZ,");
	/* 11 */ AppendToLogLine(ppanLogLine,pnMaxLen,"Buttons,");
	/* 12 */ AppendToLogLine(ppanLogLine,pnMaxLen,"JumpPress,JumpHold,");
	/* 13 */ AppendToLogLine(ppanLogLine,pnMaxLen,"DuckPress,DuckHold,");
	/* 14 */ AppendToLogLine(ppanLogLine,pnMaxLen,"FwdPress,FwdHold,");
	/* 15 */ AppendToLogLine(ppanLogLine,pnMaxLen,"BackPress,BackHold,");
	/* 16 */ AppendToLogLine(ppanLogLine,pnMaxLen,"LeftPress,LeftHold,");
	/* 17 */ AppendToLogLine(ppanLogLine,pnMaxLen,"RightPress,RightHold,");
	/* 18 */ AppendToLogLine(ppanLogLine,pnMaxLen,"MoveLPress,MoveLHold,");
	/* 19 */ AppendToLogLine(ppanLogLine,pnMaxLen,"MoveRPress,MoveRHold,");
	/* 20 */ AppendToLogLine(ppanLogLine,pnMaxLen,"IsOnGround,IsDucking,EvJump");
	}
	else
	{
	/* 1  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,",anClient);
	/* 2  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,",gnTick);
	/* 3  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",gaarPlayerOrigin[anClient][0],gaarPlayerOrigin[anClient][1],gaarPlayerOrigin[anClient][2]);
	/* 4  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",gaarPlayerVelocity[anClient][0],gaarPlayerVelocity[anClient][1],gaarPlayerVelocity[anClient][2]);
	/* 5  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",gaarPlayerNormalizedVelocity[anClient][0],gaarPlayerNormalizedVelocity[anClient][1],gaarPlayerNormalizedVelocity[anClient][2]);
	/* 6  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,",garPlayerXyzVelScalar[anClient]);
	/* 7  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,",garPlayerXyVelScalar[anClient]);
	/* 8  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",gaarPlayerEyeAngles[anClient][0],gaarPlayerEyeAngles[anClient][1],gaarPlayerEyeAngles[anClient][2]);
	/* 9  */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",gaarPlayerEyePos[anClient][0],gaarPlayerEyePos[anClient][1],gaarPlayerEyePos[anClient][2]);
	/* 10 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%f,%f,%f,",garPlayerRotation[anClient][0],garPlayerRotation[anClient][1],garPlayerRotation[anClient][2]);
	/* 11 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,",ganPlayerButtons[anClient]);
	/* 12 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_JUMP)],gaaeButtonHolds[anClient][KeyToIndex(IN_JUMP)]);
	/* 13 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_DUCK)],gaaeButtonHolds[anClient][KeyToIndex(IN_DUCK)]);
	/* 14 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_FORWARD)],gaaeButtonHolds[anClient][KeyToIndex(IN_FORWARD)]);
	/* 15 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_BACK)],gaaeButtonHolds[anClient][KeyToIndex(IN_BACK)]);
	/* 16 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_LEFT)],gaaeButtonHolds[anClient][KeyToIndex(IN_LEFT)]);
	/* 17 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_RIGHT)],gaaeButtonHolds[anClient][KeyToIndex(IN_RIGHT)]);
	/* 18 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_MOVELEFT)],gaaeButtonHolds[anClient][KeyToIndex(IN_MOVELEFT)]);
	/* 19 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,",gaaeButtonPress[anClient][KeyToIndex(IN_MOVERIGHT)],gaaeButtonHolds[anClient][KeyToIndex(IN_MOVERIGHT)]);
	/* 20 */ AppendToLogLine(ppanLogLine,pnMaxLen,"%d,%d,%d",ganPlayerOnGround[anClient],ganPlayerDucking[anClient],gaePlayerInJump[anClient]);
	}
	
	LogToFileEx(gpanLogFile,"%s",ppanLogLine);
	
	gaePlayerInJump[anClient] = false;
}

AppendToLogLine(String:apanLogLine[], anMaxLen, const String:aapanFormat[], any:...)
{
	decl String:ppanBuffer[1024];
	
	VFormat(ppanBuffer, sizeof(ppanBuffer), aapanFormat, 4);

	StrCat(apanLogLine,anMaxLen,ppanBuffer);
}

UpdateClientOrigin(anClient)
{
	GetEntPropVector(anClient, Prop_Send, "m_vecOrigin", gaarPlayerOrigin[anClient]);
}

UpdateClientOrientation(anClient)
{
	GetEntPropVector(anClient, Prop_Send, "m_angRotation", garPlayerRotation[anClient]);

	GetClientEyeAngles(anClient,gaarPlayerEyeAngles[anClient]);
	
	GetClientEyePosition(anClient,gaarPlayerEyePos[anClient]);
}

UpdateClientVelocityInfo(anClient)
{
	decl Float:parZVel;
	
	GetEntPropVector(anClient, Prop_Data, "m_vecVelocity", gaarPlayerVelocity[anClient]);
	NormalizeVector(gaarPlayerVelocity[anClient],gaarPlayerNormalizedVelocity[anClient]);
	
	garPlayerXyzVelScalar[anClient] = GetVectorLength(gaarPlayerVelocity[anClient]);
	
	parZVel = gaarPlayerVelocity[anClient][2];
	gaarPlayerVelocity[anClient][2] = 0.0;
	garPlayerXyVelScalar[anClient] =  GetVectorLength(gaarPlayerVelocity[anClient]);
	gaarPlayerVelocity[anClient][2] = parZVel;
}

public Action:OnPlayerRunCmd(anClient, &apButtons, &apImpulse, Float:arVel[3], Float:arAngles[3], &apWeapon)
{
	if(IsPlayerAlive(anClient) && gaeEnable)
	{
		//LogDebug("apButtons = %d",apButtons);
		
		ganPlayerButtons[anClient] = apButtons;
		
		UpdateClientButton(anClient,apButtons,IN_JUMP);
		UpdateClientButton(anClient,apButtons,IN_DUCK);
		UpdateClientButton(anClient,apButtons,IN_FORWARD);
		UpdateClientButton(anClient,apButtons,IN_BACK);
		UpdateClientButton(anClient,apButtons,IN_LEFT);
		UpdateClientButton(anClient,apButtons,IN_RIGHT);
		UpdateClientButton(anClient,apButtons,IN_MOVELEFT);
		UpdateClientButton(anClient,apButtons,IN_MOVERIGHT);
	}

	return Plugin_Continue;
}

UpdateClientButton(anClient,anButtons,anKey)
{
	new lnKeyIndex = KeyToIndex(anKey);
	
	gaaeButtonPress[anClient][lnKeyIndex] = false;
	
	if(anButtons & anKey)
	{
		if(!gaaeButtonHolds[anClient][lnKeyIndex])
		{
			gaaeButtonPress[anClient][lnKeyIndex] = true;
		}
		
		gaaeButtonHolds[anClient][lnKeyIndex] = true;
	}
	else if(gaaeButtonHolds[anClient][lnKeyIndex]) 
	{
		gaaeButtonHolds[anClient][lnKeyIndex] = false;
	}
}

KeyToIndex(anKey)
{
	return RoundToFloor(Logarithm(float(anKey),2.0) + 0.5);
}

public evPlayerJump(Handle:ahEvent, const String:apanName[], bool:aeDontBroadcast)
{
	new lnClient = GetClientOfUserId(GetEventInt(ahEvent, "userid"));
	
	gaePlayerInJump[lnClient] = true;
}
