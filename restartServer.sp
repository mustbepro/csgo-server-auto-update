#include <cstrike>
#include <sourcemod>
#include <sdktools>

bool restart;

new Handle:DB = INVALID_HANDLE;

public OnPluginStart(){

	new String:Error[70];
	DB = SQL_Connect ("csgoUpdate", true, Error, sizeof(Error));

	RestartServer();
}

RestartServer(){
	
	CreateTimer(10.0, Restart, 0, TIMER_REPEAT);
}

stock GetRealClientCount(bool:inGameOnly = true){

	new clients = 0;

	for( new i = 1; i <= GetMaxClients(); i++ ){

		if(((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i)){
	
		clients++;
		}
	}

	return clients;
}

public Action:Restart(Handle:restartHandle){

	//Find game server IP.

	if(DB == INVALID_HANDLE)
	{

		return Plugin_Stop;
	}

	decl String:hostIP[32];
	new pieces[4];
	new longip = GetConVarInt(FindConVar("hostip"));

	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(hostIP, sizeof(hostIP), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);

	new port = GetConVarInt(FindConVar("hostport"));
	new hostname = GetConVarInt(FindConVar("hostname"));

	//Insert game server into database.

	new String:queryInsertHost[100];
	Format(queryInsertHost, sizeof(queryInsertHost), "SELECT host FROM servers WHERE host = '%s:%i'", hostIP, port);
	new Handle:hQueryInsertHost = SQL_Query(DB, queryInsertHost);

	if (hQueryInsertHost == INVALID_HANDLE)
	{
	
	new String:error[255]
	SQL_GetError(DB, error, sizeof(error))
	PrintToServer("Failed to query (error: %s)", error)
	
	}else{

	if(SQL_GetRowCount(hQueryInsertHost) != 0){

	CloseHandle(hQueryInsertHost);

	}else{

	new String:queryAddHost[100];
	Format(queryAddHost, sizeof(queryAddHost), "INSERT INTO servers (restart, host) VALUES('0', '%s:%i')", hostIP, port);
	new Handle:hQueryAddHost = SQL_Query(DB, queryAddHost);
	CloseHandle(hQueryInsertHost);

	}
	}

	new String:queryCheckForUpdate[100];
	Format(queryCheckForUpdate, sizeof(queryCheckForUpdate), "SELECT host, restart FROM servers WHERE host = '%s:%i' AND restart = '1'", hostIP, port);
	new Handle:hQueryCheckForUpdate = SQL_Query(DB, queryCheckForUpdate);

	if (hQueryCheckForUpdate == INVALID_HANDLE)
	{
	
	new String:error[255]
	SQL_GetError(DB, error, sizeof(error))
	PrintToServer("Failed to query (error: %s)", error)
	
	}else{

	if(SQL_GetRowCount(hQueryCheckForUpdate) != 0){

	restart = true;

	ServerCommand("sv_password UPDATIN");
	ServerCommand("hostname CS:GO Server Update Initiated - 8FRAG");
	CloseHandle(hQueryCheckForUpdate);
	
	}else{
	
	restart = false;

	}
	}

	if(GetRealClientCount() <= 1 && restart == true){

	new String:queryUpdateRestartValue[100];
	Format(queryUpdateRestartValue, sizeof(queryUpdateRestartValue), "UPDATE servers SET restart = '0' WHERE host = '%s:%i'", hostIP, port);
	new Handle:hQueryUpdateRestartValue = SQL_Query(DB, queryUpdateRestartValue);
	CloseHandle(hQueryUpdateRestartValue);

	restart = false;

	for( new i = 1; i <= GetMaxClients(); i++ ){
		
		if(i <= 1)
		{

			ServerCommand("_restart");
		}else{

			KickClient(i, "Server Restarting... CS:GO Update");
			ServerCommand("_restart");
		}
	}
	}else{

		//do nothing
	}

     return Plugin_Continue;
}

