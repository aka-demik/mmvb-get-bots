import std.conv : to;
import std.stdio;
import std.datetime;
import std.exception;

import etc.c.odbc.sql;
import etc.c.odbc.sqlext;

pragma( lib, "odbc32.lib" );


/// Отчет ММВБ - Исх. Боты
public:

struct BotSource {
	string name;
	string strategy;
	SysTime openTime;
	string instrument;
	string lot;
}

immutable static BotSource[] bots;

private:

static immutable char[] q =
"SELECT oo.BotName, oo.TransID, oo.State, ot.Type, oo.TryNum, oo.StopLoss, oo.TakeProfit, oo.OpenTime, oo.CloseTime, oo.MainOrder, oo.OrderNum, oo.CurrentPrice, bt.Strategy, bt.Description, bt.Symbol, bt.Lot
FROM botwar.bots bt, botwar.moex_statetable oo, botwar.order_type ot
WHERE oo.BotName = bt.BotName AND oo.Type = ot.Number
ORDER BY oo.BotName, oo.OrderNum
\0";

private static this() {
	writeln("Load bots...");

	SQLHENV henv;
	SQLHDBC hdbc;
	HSTMT   hstmt;

	enforce(SQL_SUCCEEDED(
		SQLAllocHandle(SQL_HANDLE_ENV, null, &henv)),
		"Can't open ODBC EnvHandle");
	scope(exit) SQLFreeHandle(SQL_HANDLE_ENV, henv);

	SQLSetEnvAttr(henv, SQL_ATTR_ODBC_VERSION, cast(void *)SQL_OV_ODBC3, 0);

	enforce(SQL_SUCCEEDED(
		SQLAllocHandle(SQL_HANDLE_DBC, henv, &hdbc)),
		"Can't open ODBC DBCHandle");
	scope(exit) {
		SQLDisconnect(hdbc);
		SQLFreeHandle(SQL_HANDLE_DBC, hdbc);
	}

	enforce(SQL_SUCCEEDED(
		SQLConnect(hdbc,
			cast(char *)"MySQL".ptr, SQL_NTS,
			cast(char *)"\0".ptr, SQL_NTS,
			cast(char *)"\0".ptr, SQL_NTS)),
		"Can't connect to DB");

	enforce(SQL_SUCCEEDED(
		SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt)),
		"Can't alloc stmt");
	scope(exit) SQLFreeHandle(SQL_HANDLE_STMT, hstmt);

	enforce(SQL_SUCCEEDED(
		SQLExecDirect(
			hstmt,
			cast(char *)q.ptr, SQL_NTS)),
		"Can't select data");

	{
		enum MAX_L = 255;
		BotSource tmp;

		wchar[MAX_L] name, strat, inst, lot, tm;
		SQLINTEGER nameLen, stratLen, instLen, lotLen, tmLen;


		SQLBindCol(hstmt, 01, SQL_C_WCHAR, name.ptr, MAX_L, &nameLen);
		SQLBindCol(hstmt, 13, SQL_C_WCHAR, strat.ptr, MAX_L, &stratLen);
		SQLBindCol(hstmt, 08, SQL_C_WCHAR, tm.ptr, MAX_L, &tmLen);
		SQLBindCol(hstmt, 15, SQL_C_WCHAR, inst.ptr, MAX_L, &instLen);
		SQLBindCol(hstmt, 16, SQL_C_WCHAR, lot.ptr, MAX_L, &lotLen);
		while (SQL_SUCCEEDED(SQLFetch(hstmt))) {
			tmp.name = name[0..nameLen / 2].to!string();
			tmp.strategy = strat[0..stratLen / 2].to!string();
			tmp.openTime = SysTime(tm[0..tmLen / 2]
				.to!string()
				.to!int
				.unixTimeToStdTime(),
				UTC()) + 3.hours();
			tmp.instrument = inst[0..instLen / 2].to!string();
			if (tmp.instrument == "SPFBRTS")
				tmp.instrument = "RIM5";
			tmp.lot = lot[0..lotLen / 2].to!string();
			bots ~= tmp;
			//writeln(tmp);
		}
	}
}
