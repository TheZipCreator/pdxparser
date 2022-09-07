# Parser for the Paradox/Clausewitz Scripting language
This is a simple library for the D language that parses the scripting language found in clausewitz engine games. The `parse` function returns a `Node` object, which can then be iterated over. Here's an example usage:
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
      break;
  }
}
```