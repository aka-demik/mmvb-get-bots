module clipboard;

import std.string;
import core.stdc.string;

private extern(Windows) {
   bool OpenClipboard(void*);
   void* GetClipboardData(uint);
   void* SetClipboardData(uint, void*);
   bool EmptyClipboard();
   bool CloseClipboard();
   void* GlobalAlloc(uint, size_t);
   void* GlobalLock(void*);
   bool GlobalUnlock(void*);
}

string getTextClipBoard() {
   if (OpenClipboard(null)) {
	   scope( exit ) CloseClipboard();
       auto cstr = cast(char*)GetClipboardData( 1 /*CF_TEXT*/);
       if(cstr)
           return cstr[0..strlen(cstr)].idup;
	}
	return null;
}

string setTextClipboard( string mystr ) {
	if (OpenClipboard(null)) {
		scope( exit ) CloseClipboard();
		EmptyClipboard();
		void* handle = GlobalAlloc(2, mystr.length + 1);
		void* ptr = GlobalLock(handle);
		memcpy(ptr, toStringz(mystr), mystr.length + 1);
		GlobalUnlock(handle);

		SetClipboardData( 1 /*CF_TEXT*/, handle);
	}
	return mystr;
}
