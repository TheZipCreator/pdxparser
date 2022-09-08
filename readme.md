# Parser for the Paradox/Clausewitz Scripting language
This is a simple library for the D language that parses the scripting language found in clausewitz engine games. The `parse` function returns a `Node` object, which can then be iterated over. 

*Note: I am not affilitated with Paradox Interactive.*

**IMPORTANT:** This library assumes that the given files are correctly formatted. A file that has errors in it may lead to strange results and even potential crashes (although if it does crash, please open an issue). At some point I'll update this library so that it can handle incorrectly formatted files (and throw an exception) but for now make sure your files are correctly formatted before parsing them.

Here's an example usage of reading a file:
```d
import pdxparser, std.stdio;

auto tree = parse(`owner = BRA
controller = BRA
add_core = BRA
culture = saxon
religion = catholic
hre = yes
base_tax = 4
base_production = 4
trade_goods = cloth
base_manpower = 4
fort_15th = yes
capital = "Berlin-Cölln"
is_city = yes
discovered_by = eastern
discovered_by = western
discovered_by = muslim
discovered_by = ottoman
extra_cost = 8
center_of_trade = 1


1539.1.1 = { religion = protestant }
1594.1.1 = { fort_15th = no fort_16th = yes } #Spandau
1648.1.1 = { fort_16th = no fort_17th = yes } 
1650.1.1 = { culture = prussian }`); // EU4: history/provinces/50 - Berlin.txt
int[3] dev;
foreach(child; tree) {
  switch(child.key) {
    case "owner":
      writeln("Owner: ", child.value!string);
      break;
    case "culture":
      writeln("Culture: ", child.value!string);
      break;
    case "base_tax":
      dev[0] = child.value!int;
      break;
    case "base_production":
      dev[1] = child.value!int;
      break;
    case "base_manpower":
      dev[2] = child.value!int;
      writefln("Dev: %d/%d/%d", dev[0], dev[1], dev[2]);
      break;
    case "1594.1.1":
      auto b = child.block; // equivalent to child.value!Block
      writeln(b[1].key, " = ", b[1].value!bool); // writes "fort_16th = true", yes/no are interpreted as bools
      writeln(b[1]); // Implicitly calls toString, writes "fort_16th = yes". Bools are automatically converted back to yes/no in toString
      break;
  }
}
```
You can also edit and create scripts too:
```d
string myScript = `
capital_scope = {
  set_province_flag = my_flag
}
`;
auto tree = parse(myScript);
tree[0][0] = Assignment("set_province_flag", "different_flag"); // Indexing an assignment automatically indexes the block value of the assignment.
tree[0].block.add(Assignment("add_base_tax", 5));
tree.add(Assignment("add_loan", Block([
  Assignment("interest_modifier", -0.5), // float
  Assignment("fixed_interest", true), // bool (true = yes, false = no)
  Assignment("duration", 60) // int
])));
saveNodeToFile("myScript.txt", tree);
```
And read scripts from a file. This is necessary because paradox sometimes formats their files in ANSI and not UTF-8:
```d
auto tree = parseFromFile("myScript.txt");
assert(tree[0][0].key == "set_province_flag");
assert(tree[0][0].value!string == "different_flag");
assert(tree[0][1].key == "add_base_tax");
assert(tree[0][1].value!int == 5);
assert(tree[1].key == "add_loan");
assert(tree[1][1].value!bool == true);
```