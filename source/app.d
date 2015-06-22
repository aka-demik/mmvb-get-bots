import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.datetime;
import std.range;
import clipboard;


private enum sBuy = x"CA F3 EF EB FF"c;        //Купля
private enum sSell = x"CF F0 EE E4 E0 E6 E0"c; //Продажа
//Номер заявки 	Код бумаги 	Направление 	МинДата и время заключения сделки 	Кол-во ЦБ	Кол-во 	Номер сделки 	 Сумма сделки расчет
//13464857491	SBER		Купля		14.05.15 15:05				1		1	747,8

private struct MyKey {
	string instrument;
	string oper;
	string lot;
}

private struct MyOrder {
	string open;
	int n;
	string instrument;
	string lot;
	SysTime openTime;
}
alias MyOrders = MyOrder[];

/// Отчет ММВБ - Исх. Боты
private struct BotSource {
	string name;
	string strategy;
	SysTime openTime;
	string instrument;
	string lot;
}

private immutable static BotSource[] bots;

BotSource[] getBotsForOrder(in MyOrder o) {
	return bots.filter!(
		(a) =>
			o.instrument == a.instrument &&
			o.lot == a.lot &&
			abs(o.openTime - a.openTime).total!"seconds" < 5)
		.array().dup();
}

string toString(in BotSource[] b) {
	if (!b.length)
		return "0\t\t\t";
	return format("%s\t%s\t%s\t", b.length, b[0].name, b[0].strategy);
}

private string antiOper(in string oper) {
	switch (oper) {
		case sBuy:
			return sSell;
		case sSell:
			return sBuy;
		default:
			throw new Exception("Unknown oper " ~ oper);
	}
}

private SysTime excelStrToTime(in string s) {
	// 29.05.15 12:00
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
		0));
}

static this() {
	foreach (e; File("source-botes.txt", "rb").byLineCopy().drop(1)) {
		string[] cols = e.splitter("\t").array();
		const tmp = BotSource(
			cols[0],
			cols[12],
			excelStrToTime(cols[16]),
			cols[18],
			cols[15]);
		bots ~= tmp;
	}
}

void main() {
	int counter;
	string result;
	auto srcS = getTextClipBoard();
	string[] src = srcS.splitter("\r\n").filter!"a.length".array();

	MyOrders[MyKey] orders;
	foreach(e; src) {
		string[] cols = e.splitter("\t").array();
		auto keyo = MyKey(cols[1],         (cols[2]), cols[4]);
		auto keyc = MyKey(cols[1], antiOper(cols[2]), cols[4]);

		if (keyc in orders) { // Если есть что закрывать
			auto ordrs = orders[keyc];
			auto order = ordrs[0];
			ordrs = ordrs[1..$];
			if (ordrs.length)
				orders[keyc] = ordrs;
			else
				orders.remove(keyc);
			result ~= format("%s\t%s\topen\t", order.open, order.n);
			result ~= format("%s\t%s\tclose\t%s\r\n", e, order.n, toString(getBotsForOrder(order)));
		} else {
			const tmp = MyOrder(
				e,
				++counter,
				cols[1],
				cols[4],
				excelStrToTime(cols[3]));
			if (keyo in orders)
				orders[keyo] ~= tmp;
			else
				orders[keyo] = [tmp];
		}
	}
	foreach(v; orders.byValue())
		foreach(e; v)
			result ~= format("%s\t%s\topened\t\t\t\t\t\t\t\t\t\t%s\r\n", e.open, e.n, toString(getBotsForOrder(e)));

	setTextClipboard(result);
	writeln("Done");
	readln();
}
