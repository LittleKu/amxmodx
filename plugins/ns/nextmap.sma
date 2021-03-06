// vim: set ts=4 sw=4 tw=99 noet:
//
// AMX Mod X, based on AMX Mod by Aleksander Naszko ("OLO").
// Copyright (C) The AMX Mod X Development Team.
//
// This software is licensed under the GNU General Public License, version 3 or higher.
// Additional exceptions apply. For full license details, see LICENSE.txt or visit:
//     https://alliedmods.net/amxmodx-license

//
// Natural Selection NextMap Plugin
//

enum mapdata {
	NAME[32],
	MIN,
	MAX
}

#include <amxmodx>
#include <engine>

#define MAX_MAPS	128
#define INFO_READ_TIME	5.0

new g_mapCycle[MAX_MAPS][mapdata]
new g_numMaps, g_numPlayers, g_nextPos
new bool:g_mapChanging, bool:g_changeMapDelay

public plugin_init() {
	register_plugin("NextMap",AMXX_VERSION_STR,"AMXX Dev Team")
	register_cvar("amx_nextmap","",FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY)
	register_cvar("amx_mapnum_ignore", "0")
	register_event("TextMsg", "voteMap", "a", "1=3", "2&executed votemap")
	register_event("PlayHUDNot", "roundEnded", "bc", "1=0", "2=57")
	register_clcmd("say nextmap", "sayNextMap", 0, "- displays nextmap")

	readMapCycle()
	findNextMap()
}
stock bool:ValidMap(mapname[])
{
	if ( is_map_valid(mapname) )
	{
		return true;
	}
	// If the is_map_valid check failed, check the end of the string
	new len = strlen(mapname) - 4;
	
	// The mapname was too short to possibly house the .bsp extension
	if (len < 0)
	{
		return false;
	}
	if ( equali(mapname[len], ".bsp") )
	{
		// If the ending was .bsp, then cut it off.
		// the string is byref'ed, so this copies back to the loaded text.
		mapname[len] = '^0';
		
		// recheck
		if ( is_map_valid(mapname) )
		{
			return true;
		}
	}
	
	return false;
}

public server_changelevel() {
	if (g_mapChanging)
		return BLOCK_ONCE

	// Check if the cvar "amx_nextmap" has changed since the map loaded as it overrides the min/max settings.
	new szCvarNextMap[32]
	get_cvar_string("amx_nextmap", szCvarNextMap, charsmax(szCvarNextMap))
	if ( !equal(szCvarNextMap, g_mapCycle[g_nextPos][NAME]) ) {
		if (ValidMap(szCvarNextMap)) {
			if (g_changeMapDelay)
				set_task(INFO_READ_TIME, "changeMap", 0, szCvarNextMap, sizeof(szCvarNextMap))
			else
				changeMap(szCvarNextMap)
			return BLOCK_ONCE
		}
	}

	new szNextMap[32]
	getNextValidMap(szNextMap)
	if (ValidMap(szNextMap)) {
		if (g_changeMapDelay)
			set_task(INFO_READ_TIME, "changeMap", 0, szNextMap, sizeof(szNextMap))
		else
			changeMap(szNextMap)
	} else
		return BLOCK_NOT	// When NS trys to change map it disables gameplay, so we MUST change map.
					// This is a backup incase something unexpected happens to make sure we change map.

	g_mapChanging = true
	return BLOCK_ONCE
}

public getNextValidMap(szNextMap[]) {

/* Test min/max player settings.
   First test with number of players when the round ended, then with the current number of players,
   as this is how NS does it.
*/
	new startPos = g_nextPos

	if (!get_cvar_num("amx_mapnum_ignore")) {
		new curNumPlayers = get_playersnum()
		if (g_numPlayers == 0) g_numPlayers = curNumPlayers
		new looped
		while(looped < 2) {
			new minPlayers = g_mapCycle[g_nextPos][MIN]
			new maxPlayers = g_mapCycle[g_nextPos][MAX]
			if (maxPlayers == 0) maxPlayers = 32
			if (minPlayers <= g_numPlayers <= maxPlayers) break
			if (minPlayers <= curNumPlayers <= maxPlayers) {
				g_numPlayers = curNumPlayers
				break
			}
			if (++g_nextPos == g_numMaps) {
				g_nextPos = 0
				looped++
			}
		}
	}
	copy(szNextMap, 31, g_mapCycle[g_nextPos][NAME])

	if (startPos != g_nextPos) {	// Next Map wasn't valid due to min/max player settings
		client_print(0, print_chat, "Too %s players for %s. Next valid map: %s",
		(g_mapCycle[startPos][MIN] <= g_numPlayers) ? "many" : "few", g_mapCycle[startPos][NAME], g_mapCycle[g_nextPos][NAME])

		new szPos[8]
		num_to_str(g_nextPos, szPos, charsmax(szPos))
		set_localinfo("amx_nextmap_pos", szPos)
		set_cvar_string("amx_nextmap", g_mapCycle[g_nextPos][NAME])
		g_changeMapDelay = true
	}
}

public voteMap() {
	new szVoteMap[128]
	read_data(2, szVoteMap, charsmax(szVoteMap))		// "YO | Cheesy Peteza executed votemap 2 (co_angst 1/5)"

	new start, end, szData[64]
	for (new i; i<strlen(szVoteMap); ++i) {
		if ( szVoteMap[i] == '(' ) start = i
		if ( szVoteMap[i] == ')' ) end = i
	}
	new j
	for (new i=start+1; i<end; ++i) {
		szData[j++] = szVoteMap[i]	// "co_angst 1/5"
	}
	szData[j] = 0
	replace(szData, charsmax(szData), "/", " ")		// "co_angst 1 5"

	new szMapName[32], szVote1[3], szVote2[3], iVote1, iVote2
	parse(szData, szMapName, charsmax(szMapName), szVote1, charsmax(szVote1), szVote2, charsmax(szVote2))
	iVote1 = str_to_num(szVote1)
	iVote2 = str_to_num(szVote2)

	if (iVote1 != 0 && iVote1 == iVote2) {
		client_print(0, print_chat, "Voting successful, changing map to %s", szMapName)
		set_cvar_string("amx_nextmap", szMapName)
		g_changeMapDelay = true
	}
}

findNextMap() {
	new szPos[8]
	get_localinfo("amx_nextmap_pos", szPos, charsmax(szPos))
	new pos = str_to_num(szPos)

	new curmap[32]
	get_mapname(curmap, charsmax(curmap))
	if ( equal(g_mapCycle[pos][NAME], curmap) ) {
		g_nextPos = pos + 1
		if (g_nextPos == g_numMaps)
			g_nextPos = 0
	} else {							// Map was changed manually.
		g_nextPos = pos
		new looped
		while( equal(g_mapCycle[g_nextPos][NAME], curmap) && looped < 2 ) {	// Don't let the nextmap be the same as this one
			if (++g_nextPos == g_numMaps) {
				g_nextPos = 0
				looped++
			}
		}
	}
	set_cvar_string("amx_nextmap", g_mapCycle[g_nextPos][NAME])
	num_to_str(g_nextPos, szPos, charsmax(szPos))
	set_localinfo("amx_nextmap_pos", szPos)
}

readMapCycle() {
	new szMapCycleFile[32]
	get_cvar_string("mapcyclefile", szMapCycleFile, charsmax(szMapCycleFile))

	new length, line = 0
	new szBuffer[64], szMapName[32], szMapPlayerNum[32]
	if ( file_exists(szMapCycleFile) ) {
		while( read_file(szMapCycleFile, line++, szBuffer, charsmax(szBuffer), length) )  {	// ns_lost "\minplayers\16\maxplayers\32\"
			parse(szBuffer, szMapName, charsmax(szMapName), szMapPlayerNum, charsmax(szMapPlayerNum))
			if ( !isalpha(szMapName[0]) || !ValidMap(szMapName) ) continue

			copy(g_mapCycle[g_numMaps][NAME], charsmax(g_mapCycle[][NAME]), szMapName)

			for (new i; i<strlen(szMapPlayerNum); ++i) {			// " minplayers 16 maxplayers 32 "
				if (szMapPlayerNum[i] == '\')
					szMapPlayerNum[i] = ' '
			}
			new szKey1[11], szKey2[11], szValue1[3], szValue2[3]
			parse(szMapPlayerNum, szKey1, charsmax(szKey1), szValue1, charsmax(szValue1), szKey2, charsmax(szKey2), szValue2, charsmax(szValue2))
			if (equal(szKey1, "minplayers"))
				g_mapCycle[g_numMaps][MIN] = clamp(str_to_num(szValue1), 0, 32)
			if (equal(szKey2, "maxplayers"))
				g_mapCycle[g_numMaps][MAX] = clamp(str_to_num(szValue2), 0, 32)

			if (++g_numMaps == MAX_MAPS) break
		}
	}
}

public roundEnded() {
	g_numPlayers = get_playersnum()
	set_task(8.0, "sayNextMapTimeLeft")
}

public sayNextMap(){
	new szName[32]
	get_cvar_string("amx_nextmap", szName, charsmax(szName))
	client_print(0, print_chat, "Next Map:  %s", szName)
}

public sayNextMapTimeLeft(){
	new szName[32], szText[128]
	get_cvar_string("amx_nextmap", szName, charsmax(szName))
	format(szText, charsmax(szText), "Next Map:  %s", szName)

	if (get_cvar_float("mp_timelimit")) {
		new a = get_timeleft()
		format(szText, charsmax(szText), "%s  Time Left:  %d:%02d", szText, (a / 60) , (a % 60) )
	}
	client_print(0, print_chat, "%s", szText)
}

public changeMap(szMapName[])
	server_cmd("changelevel %s", szMapName)

