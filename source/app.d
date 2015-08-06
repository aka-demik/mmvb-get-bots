import std.stdio;
import std.file;
import std.string;
import std.algorithm;
import std.conv;
import std.datetime;
import std.range;
import ae.sys.clipboard;

import botssrc;

void main() {
	writeln("Load clipboard...");

	string result;

	foreach(e; getClipboardText().splitter("\r\n").filter!"strip(a).length") {
		string[] cols = e.splitter("\t").array();
		if (cols.length <= 4)
			throw new Exception("Line too short: " ~ e);
		result ~= format("%s\t%s\r\n", e, toString(getBotsForOrder(
			excelStrToTime(cols[3]),  // Время
			cols[1],                  // Инструмент
			cols[4]                   // Лот
			)));
	}

	setClipboardText(result);
	//std.file.write("dest-orders.txt", result);
	writeln("Done");
	readln();
}

private:

const(BotSource[]) getBotsForOrder(in SysTime openTime, in string instrument, in string lot) {
	return bots.filter!(
		(a) =>
			instrument == a.instrument &&
			lot == a.lot &&
			abs(openTime - a.openTime).total!"seconds" < 5)
		.array();
}

string toString(in BotSource[] b) {
	if (!b.length)
		return "0\t\t";
	return format("%s\t%s\t%s", b.length, b[0].name, b[0].strategy);
}

SysTime excelStrToTime(in string s) {
	auto cols = s.replace(" ", ".")
		.replace(":", ".")
		.splitter(".")
		.array();
	int tmp = cols[2].to!int;
	return SysTime(DateTime(
		(tmp > 1000)?tmp:tmp + 2000,
		cols[1].to!int,
		cols[0].to!int,
		cols[3].to!int,
		cols[4].to!int,
		0), UTC());
}
