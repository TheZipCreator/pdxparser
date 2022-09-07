/*
  Paradox Script Parser
  Copyright (C) 2022 TheZipCreator

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module pdxparser;

import std.variant, std.conv, std.array;

/// Thrown whenever a function is called on a node when it's not appropriate
class PDXInvalidTypeException : Exception {
  this() {
    super("Invalid type for operation");
  }
}

/// Thrown whenever parsing fails
class PDXParsingException : Exception {
  this(string msg) {
    super(msg);
  }
}

/// Type of a node
enum NodeType {
  ASSIGNMENT, ///
  BLOCK, ///
  VALUE ///
}

/// Represents a single usable thing in the given script
interface Node {
  /// Gets all children of a block
  Node[] children();
  /// Returns a `NodeType` that corresponds to the type
  NodeType type(); 
  /// Should be equivalent to `node.children[i]`
  Node opIndex(size_t i);
  /// Returns the first assignment with key `s`
  Node opIndex(string s);
  /// equivalent to looping over node.children
  int opApply(int delegate(Node) dg);
  /// Gets the key of an assignment
  string key(); 
  Variant value_(); // for some reason (seriously why the f**k did they do this) template functions in interfaces are final by default. So I have to do this instead
  /// Gets the value of an assignment or the value of a value
  T value(T)() {
    return value_().get!T();
  }
  /// Equivalent to .value!Block
  final Block block() {
    return value!Block;
  }
  string toString();
}

/// Two values seperated by an equals. Usually an effect or condition
/// ex:
/// `culture = albanian`
class Assignment : Node {
  string _key;
  Variant _value;
  this(string k, Variant v) {
    this._key = k;
    this._value = v;
  }

  Node[] children() {
    throw new PDXInvalidTypeException;
  }
  NodeType type() {
    return NodeType.ASSIGNMENT;
  }
  Node opIndex(size_t i) {
    throw new PDXInvalidTypeException;
  }
  Node opIndex(string s) {
    throw new PDXInvalidTypeException;
  }
  int opApply(int delegate(Node) dg) {
    throw new PDXInvalidTypeException;
  }
  string key() {
    return _key;
  }
  Variant value_() {
    return _value;
  }
  override string toString() {
    return _key~" = "~_value.toString();
  }
}

/// Represents a series of ret surrounded by curly braces (typically the value of an assignment)
class Block : Node {
  Node[] _children;
  this(Node[] children) {
    _children = children;
  }

  Node[] children() {
    return _children;
  }
  NodeType type() {
    return NodeType.BLOCK;
  }
  Node opIndex(size_t i) {
    return _children[i];
  }
  Node opIndex(string s) {
    foreach(child; _children) {
      if(child.type == NodeType.ASSIGNMENT && child.key == s)
        return child;
    }
    import core.exception : RangeError;
    throw new RangeError("Cannot find key \""~s~"\"");
  }
  int opApply(int delegate(Node) dg) {
    // TODO: this is broken with returns
    foreach(ref Node child; _children) {
      if(dg(child))
        return 1;
    }
    return 0;
  }
  string key() {
    throw new PDXInvalidTypeException;
  }
  Variant value_() {
    throw new PDXInvalidTypeException;
  }
  override string toString() {
    auto ap = appender!string;
    ap.put("{\n");
    foreach(child; this) {
      ap.put(child.toString()~"\n");
    }
    ap.put("\n}");
    return ap[];
  }
}

/// Represents a single value with no = after it.
class Value : Node {
  Variant _value;
  this(Variant v) {
    _value = v;
  }

  Node[] children() {
    throw new PDXInvalidTypeException;
  }
  NodeType type() {
    return NodeType.VALUE;
  }
  Node opIndex(size_t i) {
    throw new PDXInvalidTypeException;
  }
  int opApply(int delegate(Node) dg) {
    throw new PDXInvalidTypeException;
  }
  Node opIndex(string s) {
    throw new PDXInvalidTypeException;
  }
  string key() {
    throw new PDXInvalidTypeException;
  }
  Variant value_() {
    return _value;
  }
  override string toString() {
    return _value.toString();
  }
}

/// Takes a paradox script and returns a Block representing all nodes within it
Node parse(string script) {
  int loc = 0;
  return parse(script~"\n}", &loc);
}

Block parse(string script, int* l) {
  Node[] ret;
  string value = ""; // stores value currently working on
  string buf = ""; // stores previous value when parsing assignment (buf != "" means it's currently in an assignment)
  bool seenSpace = false;
  Variant get() {
    // test whether it's a number
    bool number = true;
    bool dot = false;
    foreach(char c; value) {
      if(c == '.') {
        if(dot) {
          number = false;
          break;
        }
        else dot = true;
      } else if(c < '0' || c > '9') {
        number = false;
        break;
      }
    }
    // TODO: maybe add date as a type? (e.g. 1444.4.4 would return a custom struct Date or something)
    // TODO: "yes" and "no" still get converted to bools when surrounded by quotes, fix
    if(number && dot)
      return cast(Variant)(value.to!float);
    else if(number)
      return cast(Variant)(value.to!int);
    else if(value == "yes")
      return cast(Variant)true;
    else if(value == "no")
      return cast(Variant)false;
    else
      return cast(Variant)(value);
  }
  while(true) {
    char c = script[*l];
    *l += 1;
    if(*l > script.length)
      throw new PDXParsingException("Unbalanced braces");
    switch(c) {
      case ' ':
      case '\t':
      case '\n':
        if(value != "") {
          if(buf != "") {
            // finish assignment
            ret ~= new Assignment(buf, get);
            buf = "";
            value = "";
            break;
          }
          seenSpace = true;
        }
        break;
      case '{':
        if(buf != "") {
          *l += 1;
          Block b = parse(script, l);
          ret ~= new Assignment(buf, cast(Variant)b);
          buf = "";
          value = "";
          break;
        }
        ret ~= parse(script, l);
        break;
      case '}':
        if(seenSpace) {
          ret ~= new Value(get);
          value = c.to!string;
          seenSpace = false;
        }
        return new Block(ret);
      case '#':
        while(script[*l] != '\n')
          *l += 1;
        break;
      case '\r':
        break; // windows
      case '=':
        buf = value;
        value = "";
        seenSpace = false;
        break;
      case '"':
        while(script[*l] != '"') {
          value ~= script[*l];
          *l += 1;
        }
        *l += 1;
        break;
      default:
        if(seenSpace) {
          ret ~= new Value(get);
          value = c.to!string;
          seenSpace = false;
          break;
        }
        value ~= c;
        break;
    }
  }
}

/// Takes a filename, and parses a script from that file. Supported encodings are UTF-8 and ANSI
Node parseFromFile(string filename) {
  import std.file, std.encoding;
  import core.exception : UnicodeException;
  // Paradox script files are sometimes UTF-8 and sometimes ANSI, so I have to handle both here
  try {
    return parse(readText(filename));
  } catch(UnicodeException e) {
    string s;
    transcode(cast(Latin1String)read(filename), s);
    return parse(s);
  }
}

unittest {
  string albania = `government = monarchy
add_government_reform = autocracy_reform
government_rank = 1
primary_culture = albanian
religion = catholic
technology_group = eastern
capital = 4175 # Lezhe

# The League of Lezhe
1443.3.4 = {
	monarch = {
		name = "Gjergj Skanderbeg"
		dynasty = "Kastrioti"
		birth_date = 1405.1.1		
		adm = 6
		dip = 5
		mil = 6
		leader = {	name = "Skanderbeg"            	type = general	fire = 5	shock = 5	manuever = 5	siege = 0}
	}
	clear_scripted_personalities = yes
	add_ruler_personality = inspiring_leader_personality
	add_ruler_personality = silver_tongue_personality
}`; // excerpt of "history/countries/ALB - Albania.txt" from EU4
  auto res = parse(albania);
  assert(res[0].key == "government");
  assert(res[0].value!string == "monarchy");
  assert(res[2].value!int == 1);
  assert(res[7].key == "1443.3.4");
  assert(res[7].block[1].key == "clear_scripted_personalities");
  assert(res[7].block[0].block[1].value!string == "Kastrioti");
  assert(res[7].block[0].block[2].value!string != "aaa");
}

unittest {
  string valueTest = `values = { 1 1 1 }`;
  auto res = parse(valueTest);
  assert(res[0].block.children.length == 3);
  foreach(v; res[0].block) {
    assert(v.value!int == 1);
  }
}

unittest {
  string utf8file = `a = b`;
  import std.file, std.encoding;
  write("tmp.txt", utf8file);
  auto res = parseFromFile("tmp.txt");
  assert(res[0].key == "a");
  assert(res[0].value!string == "b");
  Latin1String ansifile;
  transcode(utf8file, ansifile);
  write("tmp.txt", ansifile);
  res = parseFromFile("tmp.txt");
  assert(res[0].key == "a");
  assert(res[0].value!string == "b");
  remove("tmp.txt");
}

unittest {
  string file = `# The Kingdom of God on Earth
country_event = {
	id = catholic_flavor.2
	title = catholic_flavor.2.t
	desc = catholic_flavor.2.d
	picture = POPE_PREACHING_eventPicture
	
	major = yes
	is_triggered_only = yes

	option = {
		name = catholic_flavor.2.a
		add_government_reform = kingdom_of_god_reform
		#set_government_rank = 3
	}

	option = {
		name = catholic_flavor.2.b
		add_prestige = 10
	}
}`; // From EU4: events/Catholic.txt
  auto tree = parse(file);
  assert(tree.children.length == 1);
  assert(tree[0].block["id"].value!string == "catholic_flavor.2");
}