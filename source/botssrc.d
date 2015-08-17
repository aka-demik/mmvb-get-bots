import std.conv : to;
import std.stdio;
import std.datetime;
import std.exception;
import std.string;

import etc.c.odbc.sql;
import etc.c.odbc.sqlext;

pragma( lib, "odbc32.lib" );


/// Отчет ММВБ - Исх. Боты
public:

struct BotSource {
	string name;
	string strategy;
	SysTime openTime;
	SysTime closeTime;
	string instrument;
	string lot;
	string type;

	int opCmp(BotSource b) pure nothrow @safe const { 
		int r = cmp(name, b.name);
		if (!r)
			r = cmp(strategy, b.strategy);
		if (!r)
			r = cmp(instrument, b.instrument);
		if (!r)
			r = cmp(lot, b.lot);
		if (!r)
			r = cmp(type, b.type);
//		if (!r)
//			r = openTime.opCmp(b.openTime);
//		if (!r)
//			r = closeTime.opCmp(b.closeTime);
		return r;
	}
}

immutable static BotSource[] bots;

private:

static immutable char[] q =
"SELECT oo.BotName, oo.TransID, oo.State, ot.Type, oo.TryNum, oo.StopLoss, oo.TakeProfit, oo.OpenTime, oo.CloseTime, oo.MainOrder, oo.OrderNum, oo.CurrentPrice, bt.Strategy, bt.Description, bt.Symbol, oo.Lot
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

		wchar[MAX_L] name, strat, inst, lot, tmo, tmc, type;
		SQLINTEGER nameLen, stratLen, instLen, lotLen, tmoLen, tmcLen, typeLen;


		SQLBindCol(hstmt, 01, SQL_C_WCHAR, name.ptr, MAX_L, &nameLen);
		SQLBindCol(hstmt, 13, SQL_C_WCHAR, strat.ptr, MAX_L, &stratLen);
		SQLBindCol(hstmt,  8, SQL_C_WCHAR, tmo.ptr, MAX_L, &tmoLen);
		SQLBindCol(hstmt,  9, SQL_C_WCHAR, tmc.ptr, MAX_L, &tmcLen);
		SQLBindCol(hstmt, 15, SQL_C_WCHAR, inst.ptr, MAX_L, &instLen);
		SQLBindCol(hstmt, 16, SQL_C_WCHAR, lot.ptr, MAX_L, &lotLen);
		SQLBindCol(hstmt,  4, SQL_C_WCHAR, type.ptr, MAX_L, &typeLen);
		while (SQL_SUCCEEDED(SQLFetch(hstmt))) {
			tmp.name = name[0..nameLen / 2].to!string();
			tmp.strategy = strat[0..stratLen / 2].to!string();
			tmp.openTime = SysTime(tmo[0..tmoLen / 2]
				.to!string()
				.to!int()
				.unixTimeToStdTime(),
				UTC()) + 3.hours();
			tmp.closeTime = SysTime(tmc[0..tmcLen / 2]
				.to!string()
				.to!int()
				.unixTimeToStdTime(),
				UTC()) + 3.hours();
			tmp.instrument = inst[0..instLen / 2].to!string();
			tmp.lot = lot[0..lotLen / 2].to!string();
			switch (type[0..typeLen / 2].to!string()) {
				case "Buy":
				case "BuyStop":
					tmp.type = "Купля";
				break;

				case "Sell":
				case "SellStop":
					tmp.type = "Продажа";
				break;

				default:
					throw new Exception("unknown type " ~ type[0..typeLen / 2].to!string());
			}
			bots ~= tmp;
		}
	}
}
